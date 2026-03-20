// Meeting Reminder/Services/CalendarService.swift
import EventKit
import SwiftUI
import Combine

@MainActor
final class CalendarService: ObservableObject {

    static let shared = CalendarService()

    // MARK: - Published State

    @Published var accessGranted = false
    @Published var calendars: [EKCalendar] = []
    @Published var nextEvent: MeetingEvent?
    @Published var pendingEvents: [MeetingEvent] = []

    // MARK: - Settings (UserDefaults-backed, mit onChange-Reaktivität)

    @AppStorage("enabledCalendarIDs") private var enabledCalendarIDsData: Data = Data()
    @AppStorage("soundEnabled") var soundEnabled: Bool = false
    @AppStorage("silentWhenScreenSharing") var silentWhenScreenSharing: Bool = true
    @AppStorage("hasLaunchedBefore") var hasLaunchedBefore: Bool = false

    // Diese Settings lösen reloadAndReschedule() aus wenn sie sich ändern
    @Published var leadTimeMinutes: Int = {
        let raw = UserDefaults.standard.integer(forKey: "leadTimeMinutes")
        return raw > 0 ? raw : 1
    }() {
        didSet {
            UserDefaults.standard.set(leadTimeMinutes, forKey: "leadTimeMinutes")
            reloadAndReschedule()
        }
    }

    @Published var onlyOnlineMeetings: Bool = UserDefaults.standard.bool(forKey: "onlyOnlineMeetings") {
        didSet {
            UserDefaults.standard.set(onlyOnlineMeetings, forKey: "onlyOnlineMeetings")
            reloadAndReschedule()
        }
    }

    // MARK: - Private

    private let eventStore = EKEventStore()
    private var alertTimer: Timer?
    private var fallbackTimer: Timer?
    private var debounceTask: Task<Void, Never>?
    private var dismissedEvents: Set<String> = []
    private var defaultObservers: [Any] = []
    private var workspaceObservers: [Any] = []

    // MARK: - Enabled Calendar IDs

    var enabledCalendarIDs: Set<String> {
        get {
            guard let ids = try? JSONDecoder().decode(Set<String>.self, from: enabledCalendarIDsData) else {
                return Set(calendars.map(\.calendarIdentifier))
            }
            return ids
        }
        set {
            enabledCalendarIDsData = (try? JSONEncoder().encode(newValue)) ?? Data()
            reloadAndReschedule()
        }
    }

    // MARK: - Lifecycle

    func start() async {
        // 1. Berechtigung anfragen
        do {
            accessGranted = try await eventStore.requestFullAccessToEvents()
        } catch {
            accessGranted = false
        }

        guard accessGranted else { return }

        // 2. Kalender laden
        calendars = eventStore.calendars(for: .event)

        // 3. Notifications abonnieren
        let storeObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: eventStore,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleStoreChanged()
            }
        }
        defaultObservers.append(storeObserver)

        let wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.reloadAndReschedule()
            }
        }
        workspaceObservers.append(wakeObserver)

        let sleepObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.alertTimer?.invalidate()
            }
        }
        workspaceObservers.append(sleepObserver)

        // 4. Fallback-Timer (alle 30 Min)
        fallbackTimer = Timer.scheduledTimer(withTimeInterval: 30 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.reloadAndReschedule()
            }
        }

        // 5. Erste Berechnung
        reloadAndReschedule()
    }

    deinit {
        alertTimer?.invalidate()
        fallbackTimer?.invalidate()
        for observer in defaultObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        for observer in workspaceObservers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }

    // MARK: - Event Loading

    func reloadAndReschedule() {
        guard accessGranted else { return }

        // Kalender aktualisieren
        calendars = eventStore.calendars(for: .event)

        // Dismissed-Set aufräumen
        cleanupDismissed()

        // Events laden (24h-Fenster)
        let now = Date()
        let events = loadRelevantEvents(from: now)

        // Pending Events bereinigen — gelöschte Events entfernen
        let validIDs = Set(events.map(\.id))
        pendingEvents.removeAll { !validIDs.contains($0.id) }

        // Nächstes Event für Status-Anzeige
        nextEvent = events.first

        // Prüfen ob ein Meeting JETZT läuft (nach Wake)
        let runningEvents = events.filter { $0.startDate <= now && !dismissedEvents.contains($0.id) }
        if !runningEvents.isEmpty {
            pendingEvents = runningEvents
            return
        }

        // Timer auf nächstes Event setzen
        scheduleTimer(for: events, from: now)
    }

    private func loadRelevantEvents(from now: Date) -> [MeetingEvent] {
        let startDate = now.addingTimeInterval(-5 * 60) // 5 Min zurück
        let endDate = Calendar.current.date(byAdding: .hour, value: 24, to: now)!

        let enabledIDs = enabledCalendarIDs
        let selectedCalendars = calendars.filter { enabledIDs.contains($0.calendarIdentifier) }

        guard !selectedCalendars.isEmpty else { return [] }

        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: selectedCalendars
        )

        return eventStore.events(matching: predicate)
            .compactMap { mapToMeetingEvent($0) }
            .filter { isRelevant($0, now: now) }
            .sorted { a, b in
                CalendarService.compareEvents(a, b)
            }
    }

    private func mapToMeetingEvent(_ event: EKEvent) -> MeetingEvent? {
        guard !event.isAllDay else { return nil }

        let teamsURL = TeamsLinkExtractor.extractURL(
            location: event.location,
            notes: event.notes,
            url: event.url
        )

        return MeetingEvent(
            eventIdentifier: event.eventIdentifier ?? UUID().uuidString,
            title: event.title ?? "Ohne Titel",
            startDate: event.startDate,
            endDate: event.endDate,
            location: event.location,
            calendarColor: Color(cgColor: event.calendar.cgColor),
            calendarTitle: event.calendar.title,
            teamsURL: teamsURL,
            isAllDay: event.isAllDay
        )
    }

    // MARK: - Event Evaluation (nonisolated static für Testbarkeit)

    /// Prüft ob ein Event relevant ist (nicht ganztägig, nicht dismissed, im Zeitfenster)
    nonisolated static func isEventRelevant(
        _ event: MeetingEvent,
        now: Date,
        onlyOnlineMeetings: Bool,
        dismissedEvents: Set<String>
    ) -> Bool {
        // Ganztägig ausschließen
        guard !event.isAllDay else { return false }

        // Nur Online-Meetings?
        if onlyOnlineMeetings && !event.hasTeamsLink { return false }

        // Bereits dismissed?
        if dismissedEvents.contains(event.id) { return false }

        // In der Zukunft oder max 5 Min nach Start
        let timeSinceStart = now.timeIntervalSince(event.startDate)
        if timeSinceStart > 5 * 60 { return false }

        return true
    }

    /// Vergleicht zwei Events für Sortierung: gleiche Startzeit → Teams-Link zuerst, dann Kalender
    nonisolated static func compareEvents(_ a: MeetingEvent, _ b: MeetingEvent) -> Bool {
        if a.startDate == b.startDate {
            if a.hasTeamsLink != b.hasTeamsLink { return a.hasTeamsLink }
            return a.calendarTitle < b.calendarTitle
        }
        return a.startDate < b.startDate
    }

    /// Erstellt den zusammengesetzten Dismiss-Key für ein Event
    nonisolated static func dismissKey(for event: MeetingEvent) -> String {
        event.id
    }

    /// Bereinigt Dismissed-Keys: entfernt Events die > 2h in der Vergangenheit liegen
    nonisolated static func cleanedDismissedSet(_ dismissed: Set<String>, now: Date) -> Set<String> {
        dismissed.filter { key in
            guard let timestampString = key.split(separator: "_").last,
                  let timestamp = Double(timestampString) else { return false }
            // Behalte für 2h nach Start (konservativ)
            return Date(timeIntervalSince1970: timestamp).addingTimeInterval(2 * 3600) > now
        }
    }

    /// Dekodiert enabledCalendarIDs aus gespeicherten Data
    nonisolated static func decodeEnabledCalendarIDs(from data: Data) -> Set<String>? {
        try? JSONDecoder().decode(Set<String>.self, from: data)
    }

    private func isRelevant(_ event: MeetingEvent, now: Date) -> Bool {
        CalendarService.isEventRelevant(
            event,
            now: now,
            onlyOnlineMeetings: onlyOnlineMeetings,
            dismissedEvents: dismissedEvents
        )
    }

    // MARK: - Timer

    private func scheduleTimer(for events: [MeetingEvent], from now: Date) {
        alertTimer?.invalidate()

        guard let nextEvent = events.first(where: { $0.startDate > now }) else { return }

        let leadTime = TimeInterval(leadTimeMinutes * 60)
        let fireDate = nextEvent.startDate.addingTimeInterval(-leadTime)

        guard fireDate > now else {
            // Event ist bereits im Vorlauf-Fenster
            pendingEvents = [nextEvent]
            return
        }

        alertTimer = Timer.scheduledTimer(
            withTimeInterval: fireDate.timeIntervalSince(now),
            repeats: false
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.reloadAndReschedule()
            }
        }
    }

    // MARK: - Dismiss/Snooze

    func dismissEvent(_ event: MeetingEvent) {
        dismissedEvents.insert(event.id)
        pendingEvents.removeAll { $0.id == event.id }

        if pendingEvents.isEmpty {
            reloadAndReschedule()
        }
    }

    func snoozeEvent(_ event: MeetingEvent) {
        pendingEvents.removeAll { $0.id == event.id }

        // Snooze-Timer: 1 Minute
        Timer.scheduledTimer(withTimeInterval: 60, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let now = Date()
                let timeSinceStart = now.timeIntervalSince(event.startDate)
                // Nur erneut anzeigen wenn < 5 Min seit Start
                if timeSinceStart < 5 * 60 && !self.dismissedEvents.contains(event.id) {
                    self.pendingEvents.append(event)
                }
            }
        }

        if pendingEvents.isEmpty {
            reloadAndReschedule()
        }
    }

    // MARK: - Helpers

    private func handleStoreChanged() {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            reloadAndReschedule()
        }
    }

    private func cleanupDismissed() {
        dismissedEvents = CalendarService.cleanedDismissedSet(dismissedEvents, now: Date())
    }
}

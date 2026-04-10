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

    /// Alle heutigen Events chronologisch (ohne ganztägige) — für die Tagesübersicht
    @Published var todayEvents: [MeetingEvent] = []

    /// Anzahl der relevanten Events in den nächsten 60 Minuten (für Menüleisten-Zähler)
    @Published var upcomingEventsCount: Int = 0

    // MARK: - Settings (UserDefaults-backed, mit onChange-Reaktivität)

    @AppStorage("enabledCalendarIDs") private var enabledCalendarIDsData: Data = Data()
    @AppStorage("knownCalendarIDs") private var knownCalendarIDsData: Data = Data()
    @AppStorage("soundEnabled") var soundEnabled: Bool = false
    @AppStorage("silentWhenScreenSharing") var silentWhenScreenSharing: Bool = true
    @AppStorage("globalShortcutEnabled") var globalShortcutEnabled: Bool = true

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
    private var silencedEvents: Set<String> = []
    private var snoozeUntil: [String: Date] = [:]
    private var defaultObservers: [Any] = []
    private var workspaceObservers: [Any] = []

    // MARK: - Enabled Calendar IDs

    var enabledCalendarIDs: Set<String> {
        get {
            let allCurrentIDs = Set(calendars.map(\.calendarIdentifier))
            guard let savedIDs = try? JSONDecoder().decode(Set<String>.self, from: enabledCalendarIDsData) else {
                return allCurrentIDs
            }
            let knownIDs = (try? JSONDecoder().decode(Set<String>.self, from: knownCalendarIDsData)) ?? Set()
            // Neue Kalender (noch nie gesehen) automatisch aktivieren
            let newIDs = allCurrentIDs.subtracting(knownIDs)
            return savedIDs.union(newIDs)
        }
        set {
            enabledCalendarIDsData = (try? JSONEncoder().encode(newValue)) ?? Data()
            // Alle aktuellen IDs als bekannt markieren
            let allCurrentIDs = Set(calendars.map(\.calendarIdentifier))
            knownCalendarIDsData = (try? JSONEncoder().encode(allCurrentIDs)) ?? Data()
            reloadAndReschedule()
        }
    }

    // MARK: - Lifecycle

    func start() async {
#if DEBUG
        print("[CalendarService] Start...")
#endif
        // 1. Berechtigung anfragen
        do {
            // Nur requestFullAccessToEvents() ermöglicht Lese-Zugriff.
            // Die App schreibt NIEMALS in den Kalender.
            accessGranted = try await eventStore.requestFullAccessToEvents()
#if DEBUG
            print("[CalendarService] Zugriff: \(accessGranted)")
#endif
        } catch {
#if DEBUG
            print("[CalendarService] Fehler bei Berechtigung: \(error)")
#endif
            accessGranted = false
        }

        guard accessGranted else {
#if DEBUG
            print("[CalendarService] Kein Zugriff, stoppe.")
#endif
            return
        }

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

        let now = Date()

        // Snooze-Dictionary aufräumen — abgelaufene Einträge entfernen
        snoozeUntil = snoozeUntil.filter { $0.value > now }

        // Dismissed-Set aufräumen
        cleanupDismissed()

        // Silenced-Set zurücksetzen — beim Reload wird ggf. neu gesilenced
        silencedEvents.removeAll()

        // Heutige Events laden (Mitternacht bis Mitternacht) — für Tagesübersicht
        todayEvents = loadTodayEvents(now: now)

        // Events laden (24h-Fenster)
        let events = loadRelevantEvents(from: now)

        // Pending Events bereinigen — gelöschte Events entfernen
        let validIDs = Set(events.map(\.id))
        pendingEvents.removeAll { !validIDs.contains($0.id) }

        // Nächstes Event für Status-Anzeige (aus todayEvents, nicht Reminder-gefilterter Liste)
        // todayEvents ist chronologisch sortiert → first { endDate > now } liefert laufendes oder nächstes Meeting
        nextEvent = todayEvents.first(where: { $0.endDate > now })

        // Anzahl der Events in den nächsten 60 Minuten (für Menüleisten-Zähler)
        let oneHourFromNow = now.addingTimeInterval(60 * 60)
        upcomingEventsCount = todayEvents.filter { $0.startDate > now && $0.startDate <= oneHourFromNow }.count

        // Prüfen ob ein Meeting JETZT läuft (nach Wake) — snoozeUntil und dismissed filtern
        let runningEvents = events.filter { event in
            event.startDate <= now &&
            !dismissedEvents.contains(event.id) &&
            !CalendarService.isSnoozeActive(eventID: event.id, snoozeUntil: snoozeUntil, now: now)
        }
        if !runningEvents.isEmpty {
            pendingEvents = CalendarService.mergePendingWithRunning(pending: pendingEvents, running: runningEvents)
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

        let meetingLink = MeetingLinkExtractor.extractMeetingLink(
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
            meetingLink: meetingLink,
            isAllDay: event.isAllDay
        )
    }

    /// Lädt alle heutigen Events (ohne ganztägige) für die Tagesübersicht
    private func loadTodayEvents(now: Date) -> [MeetingEvent] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: now)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return [] }

        let enabledIDs = enabledCalendarIDs
        let selectedCalendars = calendars.filter { enabledIDs.contains($0.calendarIdentifier) }
        guard !selectedCalendars.isEmpty else { return [] }

        let predicate = eventStore.predicateForEvents(
            withStart: startOfDay,
            end: endOfDay,
            calendars: selectedCalendars
        )

        return eventStore.events(matching: predicate)
            .compactMap { mapToMeetingEvent($0) }
            .sorted { $0.startDate < $1.startDate }
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
        if onlyOnlineMeetings && !event.hasMeetingLink { return false }

        // Bereits dismissed?
        if dismissedEvents.contains(event.id) { return false }

        // In der Zukunft oder max 5 Min nach Start
        let timeSinceStart = now.timeIntervalSince(event.startDate)
        if timeSinceStart > 5 * 60 { return false }

        return true
    }

    /// Vergleicht zwei Events für Sortierung: gleiche Startzeit → Meeting-Link zuerst, dann Kalender
    nonisolated static func compareEvents(_ a: MeetingEvent, _ b: MeetingEvent) -> Bool {
        if a.startDate == b.startDate {
            if a.hasMeetingLink != b.hasMeetingLink { return a.hasMeetingLink }
            return a.calendarTitle < b.calendarTitle
        }
        return a.startDate < b.startDate
    }

    /// Bereinigt Dismissed-Keys: entfernt Events die > 2h in der Vergangenheit liegen
    nonisolated static func cleanedDismissedSet(_ dismissed: Set<String>, now: Date) -> Set<String> {
        dismissed.filter { key in
            guard let timestampString = key.split(separator: "_").last,
                  let timestamp = Double(timestampString) else { return false }
            // Behalte für 2h nach Start (inklusiv: genau 2h alt → noch behalten)
            return Date(timeIntervalSince1970: timestamp).addingTimeInterval(2 * 3600) >= now
        }
    }

    /// Prüft ob ein Event aktuell gesnoozed ist (Snooze-Zeit liegt in der Zukunft)
    nonisolated static func isSnoozeActive(eventID: String, snoozeUntil: [String: Date], now: Date) -> Bool {
        guard let snoozeDate = snoozeUntil[eventID] else { return false }
        return snoozeDate > now
    }

    /// Merged pending und running Events, dedupliziert nach ID (running hat Priorität)
    nonisolated static func mergePendingWithRunning(pending: [MeetingEvent], running: [MeetingEvent]) -> [MeetingEvent] {
        let runningIDs = Set(running.map(\.id))
        // Pending Events behalten, die nicht in running sind
        let uniquePending = pending.filter { !runningIDs.contains($0.id) }
        let merged = running + uniquePending
        return merged.sorted { compareEvents($0, $1) }
    }

    private func isRelevant(_ event: MeetingEvent, now: Date) -> Bool {
        // Snoozed Events sind temporär ausgeblendet
        guard !CalendarService.isSnoozeActive(eventID: event.id, snoozeUntil: snoozeUntil, now: now) else { return false }

        // Gesilenced Events (z.B. während Screen-Sharing) temporär ausblenden
        guard !silencedEvents.contains(event.id) else { return false }

        return CalendarService.isEventRelevant(
            event,
            now: now,
            onlyOnlineMeetings: onlyOnlineMeetings,
            dismissedEvents: dismissedEvents
        )
    }

    // MARK: - Timer

    private func scheduleTimer(for events: [MeetingEvent], from now: Date) {
        alertTimer?.invalidate()

        let leadTime = TimeInterval(leadTimeMinutes * 60)
        let futureEvents = events.filter { $0.startDate > now }

        // Alle Events die bereits im Lead-Time-Fenster liegen sofort anzeigen
        let eventsInWindow = futureEvents.filter { $0.startDate.addingTimeInterval(-leadTime) <= now }
        if !eventsInWindow.isEmpty {
            for event in eventsInWindow where !pendingEvents.contains(where: { $0.id == event.id }) {
                pendingEvents.append(event)
            }
        }

        // Timer auf das erste Event setzen, das noch nicht im Lead-Time-Fenster ist
        guard let nextEvent = futureEvents.first(where: { $0.startDate.addingTimeInterval(-leadTime) > now }) else { return }
        let fireDate = nextEvent.startDate.addingTimeInterval(-leadTime)

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
        snoozeUntil.removeValue(forKey: event.id)
        pendingEvents.removeAll { $0.id == event.id }
        reloadAndReschedule()
    }

    func snoozeEvent(_ event: MeetingEvent) {
        snoozeUntil[event.id] = Date().addingTimeInterval(60)
        pendingEvents.removeAll { $0.id == event.id }
        reloadAndReschedule()
    }

    /// Temporäres Stummschalten eines Events (z.B. während Screen-Sharing).
    /// Im Gegensatz zu dismissEvent wird silencedEvents bei reloadAndReschedule() zurückgesetzt,
    /// sodass das Event beim nächsten Reload wieder erscheint — es sei denn, Screen-Sharing
    /// ist weiterhin aktiv und handlePendingEvents() silenced es erneut.
    func silenceEvent(_ event: MeetingEvent) {
        silencedEvents.insert(event.id)
        pendingEvents.removeAll { $0.id == event.id }
        reloadAndReschedule()
    }

    /// Entscheidet ob ein gesnooztes Event nach Ablauf der Snooze-Zeit erneut angezeigt werden soll.
    /// Testbar als statische Methode (nonisolated: keine MainActor-Dependency).
    nonisolated static func shouldReShowSnoozedEvent(
        _ event: MeetingEvent,
        now: Date,
        dismissedEvents: Set<String>,
        pendingEvents: [MeetingEvent]
    ) -> Bool {
        let timeSinceStart = now.timeIntervalSince(event.startDate)
        return timeSinceStart < 5 * 60 &&
               !dismissedEvents.contains(event.id) &&
               !pendingEvents.contains(where: { $0.id == event.id })
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

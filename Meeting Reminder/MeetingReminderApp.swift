// Meeting Reminder/MeetingReminderApp.swift — Nevr Late
import SwiftUI
import UserNotifications
import AppKit
import Combine

// MARK: - App

@main
struct MeetingReminderApp: App {

    @NSApplicationDelegateAdaptor(MeetingAppDelegate.self) private var appDelegate
    @ObservedObject private var calendarService: CalendarService
    @ObservedObject private var overlayController: OverlayController

    init() {
        let service = CalendarService.shared
        let overlay = OverlayController.shared
        _calendarService = ObservedObject(wrappedValue: service)
        _overlayController = ObservedObject(wrappedValue: overlay)
    }

    var body: some Scene {
        MenuBarExtra {
            SettingsView(calendarService: calendarService)
        } label: {
            menuBarLabel
                .help(menuBarTooltip)
        }
        .menuBarExtraStyle(.window)
    }

    // MARK: - Menu Bar Label

    /// HStack mit Icon und optionalem Zähler für anstehende Meetings
    @ViewBuilder
    private var menuBarLabel: some View {
        HStack(spacing: 3) {
            Image(systemName: menuBarIcon)

            // Zähler: nur anzeigen wenn > 0 Meetings in den nächsten 60 Min
            if calendarService.upcomingEventsCount > 0 {
                Text("\(calendarService.upcomingEventsCount)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
            }
        }
    }

    // MARK: - Menu Bar Icon

    /// Dynamisches Icon je nach Zeit bis zum nächsten Meeting und Zugriffsstand
    private var menuBarIcon: String {
        Self.menuBarIconName(
            accessGranted: calendarService.accessGranted,
            nextEvent: calendarService.nextEvent
        )
    }

    // MARK: - Tooltip

    /// Tooltip-Text beim Hover auf das Menüleisten-Icon
    private var menuBarTooltip: String {
        Self.menuBarTooltipText(
            accessGranted: calendarService.accessGranted,
            nextEvent: calendarService.nextEvent
        )
    }

    // MARK: - Testbare Static-Hilfsfunktionen (nonisolated — kein @MainActor nötig)

    /// Berechnet den Icon-Namen ohne Abhängigkeit von UI-Kontext.
    /// `now` injizierbar für deterministische Unit Tests.
    nonisolated static func menuBarIconName(
        accessGranted: Bool,
        nextEvent: MeetingEvent?,
        now: Date = Date()
    ) -> String {
        guard accessGranted else { return "bell.slash" }
        guard let next = nextEvent else { return "bell" }
        let minUntilStart = next.startDate.timeIntervalSince(now) / 60
        if minUntilStart < 5 { return "bell.badge.fill" }
        if minUntilStart < 15 { return "bell.badge" }
        return "bell"
    }

    /// Berechnet den Tooltip-Text ohne Abhängigkeit von UI-Kontext.
    /// `now` injizierbar für deterministische Unit Tests.
    nonisolated static func menuBarTooltipText(
        accessGranted: Bool,
        nextEvent: MeetingEvent?,
        now: Date = Date()
    ) -> String {
        guard accessGranted else { return "Kein Kalenderzugriff – Einstellungen öffnen" }
        guard let next = nextEvent else { return "Keine anstehenden Meetings" }
        let minutes = Int(next.startDate.timeIntervalSince(now) / 60)
        if minutes <= 0 { return "Meeting läuft: \(next.title)" }
        if minutes == 1 { return "Nächstes Meeting: \(next.title) in 1 Min" }
        return "Nächstes Meeting: \(next.title) in \(minutes) Min"
    }
}

// MARK: - AppDelegate

@MainActor
final class MeetingAppDelegate: NSObject, NSApplicationDelegate {

    private var cancellable: AnyCancellable?
    private var globalMonitor: Any?
    private var localMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("[NevLate] App gestartet")

#if DEBUG
        // Demo-Modus für Screenshots (Launch-Argument: --demo-overlay)
        let args = ProcessInfo.processInfo.arguments
        if args.contains("--demo-overlay") {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 800_000_000)
                MeetingAppDelegate.showDemoOverlay()
            }
            return
        }
#endif

        let calendarService = CalendarService.shared
        let overlayController = OverlayController.shared

        // pendingEvents beobachten → Alert-Flow
        cancellable = calendarService.$pendingEvents
            .receive(on: DispatchQueue.main)
            .sink { [weak self] events in
                self?.handlePendingEvents(
                    events,
                    calendarService: calendarService,
                    overlayController: overlayController
                )
            }

        // Globalen Keyboard Shortcut registrieren (Cmd+Shift+J)
        registerGlobalShortcut()

        // CalendarService starten + Notifications
        Task {
            await calendarService.start()

            // Notification-Berechtigung nur anfragen wenn Bundle-ID vorhanden
            if Bundle.main.bundleIdentifier != nil {
                _ = try? await UNUserNotificationCenter.current().requestAuthorization(
                    options: [.alert, .sound]
                )
            }
        }
    }

    // MARK: - Globaler Keyboard Shortcut (Cmd+Shift+J)

    /// Registriert globalen und lokalen Monitor für Cmd+Shift+J
    private func registerGlobalShortcut() {
        let handler: (NSEvent) -> NSEvent? = { [weak self] event in
            self?.handleShortcutEvent(event)
            return event
        }

        // Globaler Monitor — fängt Tastendruck wenn App nicht im Fokus
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleShortcutEvent(event)
        }

        // Lokaler Monitor — fängt Tastendruck wenn App im Fokus
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: handler)
    }

    /// Prüft ob das Event Cmd+Shift+J ist und öffnet ggf. das nächste Meeting
    private func handleShortcutEvent(_ event: NSEvent) {
        let calendarService = CalendarService.shared

        // Shortcut deaktiviert?
        guard calendarService.globalShortcutEnabled else { return }

        // Cmd+Shift+J prüfen (keyCode 38 = J)
        guard event.modifierFlags.contains([.command, .shift]),
              event.keyCode == 38 else { return }

        // Nächstes Event mit Meeting-Link suchen
        guard let nextEvent = calendarService.nextEvent,
              let meetingLink = nextEvent.meetingLink else { return }

        // Meeting direkt öffnen
        Self.openMeetingDirectly(meetingLink)
    }

    // MARK: - Alert Flow

    /// isScreenSharing als injizierbarer Default-Closure für Unit-Test-Isolation
    func handlePendingEvents(
        _ events: [MeetingEvent],
        calendarService: CalendarService,
        overlayController: OverlayController,
        isScreenSharing: () -> Bool = { OverlayController.isScreenSharing() }
    ) {
        guard let event = events.first else {
            overlayController.dismiss()
            return
        }

        // Screen-Sharing aktiv + Setting an → System-Notification statt Overlay
        if calendarService.silentWhenScreenSharing && isScreenSharing() {
            sendSystemNotification(for: event, soundEnabled: calendarService.soundEnabled)
            calendarService.dismissEvent(event)
            return
        }

        // Sound abspielen
        if calendarService.soundEnabled {
            NSSound(named: .init("Funk"))?.play()
        }

        // Overlay anzeigen
        let overlayView = AlertOverlayView(
            event: event,
            onJoin: {
                if let meetingLink = event.meetingLink {
                    Self.openMeetingDirectly(meetingLink)
                }
                overlayController.dismiss()
                calendarService.dismissEvent(event)
            },
            onDismiss: {
                overlayController.dismiss()
                calendarService.dismissEvent(event)
            },
            onSnooze: {
                overlayController.dismiss()
                calendarService.snoozeEvent(event)
            }
        )

        overlayController.show(content: overlayView)

        // Accessibility: Overlay erscheint
        if let panel = overlayController.panel {
            NSAccessibility.post(element: panel, notification: .layoutChanged)
        }
    }

    // MARK: - Meeting direkt öffnen

    private static func openMeetingDirectly(_ meetingLink: MeetingLink) {
        MeetingLinkExtractor.open(meetingLink)
    }

#if DEBUG
    // MARK: - Demo Modus (nur für Screenshots, via Launch-Argument)

    private static func makeDemoEvent(provider: MeetingProvider, minutesFromNow: Double) -> MeetingEvent {
        let start = Date(timeIntervalSinceNow: minutesFromNow * 60)
        let end = Date(timeIntervalSinceNow: (minutesFromNow + 60) * 60)
        let url = URL(string: "https://zoom.us/j/123456789")!
        return MeetingEvent(
            eventIdentifier: "demo-event",
            title: "Weekly Team Sync",
            startDate: start,
            endDate: end,
            location: "https://zoom.us/j/123456789",
            calendarColor: .blue,
            calendarTitle: "Arbeit",
            meetingLink: MeetingLink(url: url, provider: provider),
            isAllDay: false
        )
    }

    private static func showDemoOverlay() {
        let event = makeDemoEvent(provider: .zoom, minutesFromNow: 2.5)
        let overlayController = OverlayController.shared
        let overlayView = AlertOverlayView(
            event: event,
            onJoin: { overlayController.dismiss() },
            onDismiss: { overlayController.dismiss() },
            onSnooze: { overlayController.dismiss() }
        )
        overlayController.show(content: overlayView)
    }
#endif

    // MARK: - System Notification (Screen-Sharing Fallback)

    private func sendSystemNotification(for event: MeetingEvent, soundEnabled: Bool) {
        guard Bundle.main.bundleIdentifier != nil else { return }
        let content = UNMutableNotificationContent()
        content.title = event.title

        if let provider = event.meetingProvider {
            content.body = "Meeting beginnt gleich — Klicke zum Beitreten via \(provider.shortName)"
        } else {
            content.body = "Meeting beginnt gleich"
        }

        content.sound = soundEnabled ? .default : nil
        content.categoryIdentifier = "MEETING_ALERT"

        let request = UNNotificationRequest(
            identifier: event.id,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}

// Meeting Reminder/MeetingReminderApp.swift — Nevr Late
import SwiftUI
import UserNotifications
import AppKit
import Combine

enum MenuBarIconState: Equatable {
    case noAccess
    case idle
    case soon
    case urgent
}

// MARK: - App

@main
struct MeetingReminderApp: App {

    @NSApplicationDelegateAdaptor(MeetingAppDelegate.self) private var appDelegate
    @ObservedObject private var calendarService: CalendarService

    init() {
        _calendarService = ObservedObject(wrappedValue: CalendarService.shared)
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
            MenuBarIconView(state: menuBarIconState)

            // Zähler: nur anzeigen wenn > 0 Meetings in den nächsten 60 Min
            if calendarService.upcomingEventsCount > 0 {
                Text("\(calendarService.upcomingEventsCount)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
            }
        }
    }

    // MARK: - Menu Bar Icon

    /// Dynamischer Icon-Zustand je nach Zeit bis zum nächsten Meeting und Zugriffsstand
    private var menuBarIconState: MenuBarIconState {
        Self.menuBarIconState(
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

    /// Berechnet den Icon-Zustand ohne Abhängigkeit von UI-Kontext.
    /// `now` injizierbar für deterministische Unit Tests.
    nonisolated static func menuBarIconState(
        accessGranted: Bool,
        nextEvent: MeetingEvent?,
        now: Date = Date()
    ) -> MenuBarIconState {
        guard accessGranted else { return .noAccess }
        guard let next = nextEvent else { return .idle }
        let minUntilStart = next.startDate.timeIntervalSince(now) / 60
        if minUntilStart < 5 { return .urgent }
        if minUntilStart < 15 { return .soon }
        return .idle
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

// MARK: - Menu Bar Icon

private struct MenuBarIconView: View {
    let state: MenuBarIconState

    private var lineWidth: CGFloat {
        state == .urgent ? 1.9 : 1.7
    }

    var body: some View {
        ZStack {
            HeadsetClockMark(lineWidth: lineWidth)

            switch state {
            case .noAccess:
                SlashOverlay(lineWidth: lineWidth)
            case .soon:
                StatusBadge(size: 3.8)
            case .urgent:
                StatusBadge(size: 5.2)
                StatusBadgeRing(size: 7.0)
            case .idle:
                EmptyView()
            }
        }
        .frame(width: 18, height: 14)
        .foregroundStyle(.primary)
        .accessibilityHidden(true)
    }
}

private struct HeadsetClockMark: View {
    let lineWidth: CGFloat

    var body: some View {
        Canvas { ctx, _ in
            let style = StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)

            // Kopfbügel-Bogen
            var arc = Path()
            arc.addArc(
                center: CGPoint(x: 9, y: 7),
                radius: 5.45,
                startAngle: .degrees(205),
                endAngle: .degrees(-25),
                clockwise: false
            )
            ctx.stroke(arc, with: .foreground, style: style)

            // Linkes Ohrpolster — Mittelpunkt in Canvas-Koordinaten: (9-5.2, 7+1.6) = (3.8, 8.6)
            ctx.fill(
                Capsule().path(in: CGRect(x: 2.75, y: 6.35, width: 2.1, height: 4.5)),
                with: .foreground
            )

            // Rechtes Ohrpolster — Mittelpunkt: (9+5.2, 7+1.6) = (14.2, 8.6)
            ctx.fill(
                Capsule().path(in: CGRect(x: 13.15, y: 6.35, width: 2.1, height: 4.5)),
                with: .foreground
            )

            // Uhrzeiger 12-Uhr (senkrecht)
            var hand12 = Path()
            hand12.move(to: CGPoint(x: 9, y: 7))
            hand12.addLine(to: CGPoint(x: 9, y: 3.8))
            ctx.stroke(hand12, with: .foreground, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

            // Uhrzeiger 4-Uhr (schräg)
            var hand4 = Path()
            hand4.move(to: CGPoint(x: 9, y: 7))
            hand4.addLine(to: CGPoint(x: 12.7, y: 9.5))
            ctx.stroke(hand4, with: .foreground, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

            // Mittelpunkt
            ctx.fill(
                Path(ellipseIn: CGRect(x: 7.825, y: 5.825, width: 2.35, height: 2.35)),
                with: .foreground
            )
        }
    }
}

private struct StatusBadge: View {
    let size: CGFloat

    var body: some View {
        Circle()
            .frame(width: size, height: size)
            .offset(x: 6.1, y: -4.25)
    }
}

private struct StatusBadgeRing: View {
    let size: CGFloat

    var body: some View {
        Circle()
            .stroke(style: StrokeStyle(lineWidth: 1, lineCap: .round))
            .frame(width: size, height: size)
            .offset(x: 6.1, y: -4.25)
    }
}

private struct SlashOverlay: View {
    let lineWidth: CGFloat

    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 4, y: 11.1))
            path.addLine(to: CGPoint(x: 13.9, y: 1.9))
        }
        .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
    }
}

// MARK: - AppDelegate

@MainActor
final class MeetingAppDelegate: NSObject, NSApplicationDelegate {

    private var cancellable: AnyCancellable?
    private var globalMonitor: Any?
    private var localMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
#if DEBUG
        print("[NevLate] App gestartet")
#endif

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
        MeetingLinkExtractor.open(meetingLink)
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
            calendarService.silenceEvent(event)
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
                    MeetingLinkExtractor.open(meetingLink)
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
        let request = UNNotificationRequest(
            identifier: event.id,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}

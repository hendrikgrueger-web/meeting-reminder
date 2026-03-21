// Meeting Reminder/MeetingReminderApp.swift
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
        guard calendarService.accessGranted else {
            return "bell.slash"
        }
        guard let next = calendarService.nextEvent else {
            return "bell"
        }
        let minUntilStart = next.startDate.timeIntervalSinceNow / 60
        if minUntilStart < 5 {
            // Meeting beginnt gleich (< 5 Min): gefülltes Badge — höchste Dringlichkeit
            return "bell.badge.fill"
        } else if minUntilStart < 15 {
            // Meeting kommt bald (< 15 Min): normales Badge
            return "bell.badge"
        } else {
            return "bell"
        }
    }

    // MARK: - Tooltip

    /// Tooltip-Text beim Hover auf das Menüleisten-Icon
    private var menuBarTooltip: String {
        guard calendarService.accessGranted else {
            return "Kein Kalenderzugriff – Einstellungen öffnen"
        }
        guard let next = calendarService.nextEvent else {
            return "Keine anstehenden Meetings"
        }
        let minutes = Int(next.startDate.timeIntervalSinceNow / 60)
        if minutes <= 0 {
            return "Meeting läuft: \(next.title)"
        } else if minutes == 1 {
            return "Nächstes Meeting: \(next.title) in 1 Min"
        } else {
            return "Nächstes Meeting: \(next.title) in \(minutes) Min"
        }
    }
}

// MARK: - AppDelegate

@MainActor
final class MeetingAppDelegate: NSObject, NSApplicationDelegate {

    private var cancellable: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("[MeetingReminder] App gestartet")
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

        // CalendarService starten + Notifications
        Task {
            await calendarService.start()

            if !calendarService.hasLaunchedBefore {
                calendarService.hasLaunchedBefore = true
            }

            // Notification-Berechtigung nur anfragen wenn Bundle-ID vorhanden
            if Bundle.main.bundleIdentifier != nil {
                _ = try? await UNUserNotificationCenter.current().requestAuthorization(
                    options: [.alert, .sound]
                )
            }
        }
    }

    // MARK: - Alert Flow

    private func handlePendingEvents(
        _ events: [MeetingEvent],
        calendarService: CalendarService,
        overlayController: OverlayController
    ) {
        guard let event = events.first else {
            overlayController.dismiss()
            return
        }

        // Screen-Sharing aktiv + Setting an → System-Notification statt Overlay
        if calendarService.silentWhenScreenSharing && OverlayController.isScreenSharing() {
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

    // MARK: - Meeting direkt öffnen (Deep-Link mit Fallback)

    private static func openMeetingDirectly(_ meetingLink: MeetingLink) {
        let deepURL = MeetingLinkExtractor.deepLinkURL(for: meetingLink)

        // Deep-Link versuchen (prüfen ob App installiert ist)
        if deepURL != meetingLink.url,
           NSWorkspace.shared.urlForApplication(toOpen: deepURL) != nil {
            NSWorkspace.shared.open(deepURL)
        } else {
            // Fallback: normalen HTTPS-Link im Browser öffnen
            NSWorkspace.shared.open(meetingLink.url)
        }
    }

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

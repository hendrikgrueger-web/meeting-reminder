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
        // NSApplicationDelegateAdaptor ist zu diesem Zeitpunkt noch nicht verfügbar,
        // daher nutzen wir shared Instances
        let service = CalendarService.shared
        let overlay = OverlayController.shared
        _calendarService = ObservedObject(wrappedValue: service)
        _overlayController = ObservedObject(wrappedValue: overlay)
    }

    var body: some Scene {
        MenuBarExtra {
            SettingsView(calendarService: calendarService)
        } label: {
            Image(systemName: menuBarIcon)
        }
        .menuBarExtraStyle(.window)
    }

    // MARK: - Menu Bar Icon

    private var menuBarIcon: String {
        if !calendarService.accessGranted {
            return "bell.slash"
        } else if let next = calendarService.nextEvent,
                  next.startDate.timeIntervalSinceNow < 15 * 60 {
            return "bell.badge"
        } else {
            return "bell"
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
                if let url = event.teamsURL {
                    Self.openTeamsDirectly(url)
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

    // MARK: - Teams direkt öffnen (ohne Browser-Umweg)

    private static func openTeamsDirectly(_ url: URL) {
        // msteams:// URL-Scheme: öffnet Teams direkt ohne Browser
        let urlString = url.absoluteString
        let teamsDeepLink: String

        if urlString.contains("teams.microsoft.com/l/meetup-join/") {
            // https://teams.microsoft.com/l/meetup-join/... → msteams://l/meetup-join/...
            teamsDeepLink = urlString.replacingOccurrences(
                of: "https://teams.microsoft.com",
                with: "msteams:"
            )
        } else if urlString.contains("teams.microsoft.com/meet/") {
            // Neues /meet/ Format — hier funktioniert der Deep Link nicht, Browser-Fallback
            teamsDeepLink = urlString
        } else {
            teamsDeepLink = urlString
        }

        if let deepURL = URL(string: teamsDeepLink),
           NSWorkspace.shared.urlForApplication(toOpen: deepURL) != nil {
            NSWorkspace.shared.open(deepURL)
        } else {
            // Fallback: normalen HTTPS-Link öffnen
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - System Notification (Screen-Sharing Fallback)

    private func sendSystemNotification(for event: MeetingEvent, soundEnabled: Bool) {
        guard Bundle.main.bundleIdentifier != nil else { return }
        let content = UNMutableNotificationContent()
        content.title = event.title
        content.body = event.hasTeamsLink
            ? "Meeting beginnt gleich — Klicke zum Beitreten"
            : "Meeting beginnt gleich"
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

// Meeting Reminder/AppIntents.swift
// Siri / Shortcuts / Spotlight Integration via App Intents (macOS 26+)

import AppIntents
import SwiftUI

// MARK: - App Shortcuts Provider

struct NevLateShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: JoinNextMeetingIntent(),
            phrases: [
                "Nächstes Meeting beitreten mit \(.applicationName)",
                "Join next meeting with \(.applicationName)"
            ],
            shortTitle: "Meeting beitreten",
            systemImageName: "video.fill"
        )
        AppShortcut(
            intent: NextMeetingIntent(),
            phrases: [
                "Nächstes Meeting mit \(.applicationName)",
                "Next meeting with \(.applicationName)"
            ],
            shortTitle: "Nächstes Meeting",
            systemImageName: "calendar"
        )
    }
}

// MARK: - Intent: Nächstes Meeting abfragen

struct NextMeetingIntent: AppIntent {
    static var title: LocalizedStringResource = "Nächstes Meeting"
    static var description = IntentDescription("Zeigt das nächste anstehende Meeting.")

    @MainActor
    func perform() async throws -> some ProvidesDialog {
        guard let event = CalendarService.shared.nextEvent else {
            return .result(dialog: "Kein Meeting geplant.")
        }
        let now = Date()
        let minutes = Int(event.startDate.timeIntervalSince(now) / 60)
        let time = event.startDate.formatted(.dateTime.hour().minute())

        if event.startDate <= now {
            return .result(dialog: "\(event.title) läuft seit \(time) Uhr.")
        } else if minutes < 60 {
            return .result(dialog: "\(event.title) in \(minutes) Minuten um \(time) Uhr.")
        } else {
            return .result(dialog: "\(event.title) um \(time) Uhr.")
        }
    }
}

// MARK: - Intent: Meeting beitreten

struct JoinNextMeetingIntent: AppIntent {
    static var title: LocalizedStringResource = "Meeting beitreten"
    static var description = IntentDescription("Öffnet den Einwahllink des nächsten Meetings.")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some ProvidesDialog {
        let events = CalendarService.shared.todayEvents
        let now = Date()

        // Laufendes oder nächstes zukünftiges Meeting mit Link suchen
        let candidate = events.first { event in
            event.meetingLink != nil && event.endDate > now
        }

        guard let event = candidate, let link = event.meetingLink else {
            return .result(dialog: "Kein Meeting mit Einwahllink gefunden.")
        }

        MeetingLinkExtractor.open(link)
        return .result(dialog: "\(event.title) wird geöffnet.")
    }
}

// MARK: - Intent: Heutige Meetings auflisten

struct ListTodayMeetingsIntent: AppIntent {
    static var title: LocalizedStringResource = "Heutige Meetings"
    static var description = IntentDescription("Listet alle Meetings von heute auf.")

    @MainActor
    func perform() async throws -> some ProvidesDialog {
        let events = CalendarService.shared.todayEvents

        guard !events.isEmpty else {
            return .result(dialog: "Heute sind keine Meetings geplant.")
        }

        let lines = events.map { event in
            let time = event.startDate.formatted(.dateTime.hour().minute())
            let provider = event.meetingProvider.map { " (\($0.shortName))" } ?? ""
            return "\(time) Uhr: \(event.title)\(provider)"
        }

        return .result(dialog: "\(events.count) Meetings heute:\n\(lines.joined(separator: "\n"))")
    }
}

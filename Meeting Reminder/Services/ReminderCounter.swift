// Meeting Reminder/Services/ReminderCounter.swift
import Foundation

/// Verfolgt, wie viele einzigartige Meeting-Erinnerungen angezeigt wurden.
/// Jedes unique Meeting (eventIdentifier + startDate) zählt einmal — Snooze-Wiederholungen nicht.
/// Lifetime-Counter: wird nicht zurückgesetzt wenn ein Abo endet.
@MainActor
final class ReminderCounter {

    static let shared = ReminderCounter()

    private let userDefaultsKey = "shownMeetingEventIDs"
    private var shownIDs: Set<String>

    private init() {
        if let data = UserDefaults.standard.data(forKey: "shownMeetingEventIDs"),
           let decoded = try? JSONDecoder().decode(Set<String>.self, from: data) {
            shownIDs = decoded
        } else {
            shownIDs = []
        }
    }

    /// Anzahl der bisher einzigartigen Meeting-Erinnerungen
    var count: Int { shownIDs.count }

    /// Gibt an, ob für dieses Event ein Reminder angezeigt werden darf.
    /// Regeln:
    ///  - Bereits gezählte Events dürfen immer wieder angezeigt werden (z.B. nach Snooze)
    ///  - Noch nicht gezählte Events: nur wenn Limit nicht erreicht oder Abo aktiv
    func canShow(event: MeetingEvent) -> Bool {
        // Bereits bekanntes Event → immer anzeigen (Snooze, Wake, etc.)
        if shownIDs.contains(event.id) { return true }
        // Abo aktiv → immer anzeigen
        if StoreKitService.shared.hasActiveSubscription { return true }
        // Free Tier: max. 50 unique Events
        return shownIDs.count < 50
    }

    /// Zählt das Event, falls es neu ist.
    func record(event: MeetingEvent) {
        guard !shownIDs.contains(event.id) else { return }
        shownIDs.insert(event.id)
        persist()
    }

    // MARK: - Private

    private func persist() {
        let data = (try? JSONEncoder().encode(shownIDs)) ?? Data()
        UserDefaults.standard.set(data, forKey: userDefaultsKey)
    }
}

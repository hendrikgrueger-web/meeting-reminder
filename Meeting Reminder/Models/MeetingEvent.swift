import SwiftUI

struct MeetingEvent: Identifiable, Sendable, Equatable {
    let eventIdentifier: String
    let title: String
    let startDate: Date
    let endDate: Date
    let location: String?
    let calendarColor: Color
    let calendarTitle: String
    let teamsURL: URL?
    let isAllDay: Bool

    var id: String {
        "\(eventIdentifier)_\(startDate.timeIntervalSince1970)"
    }

    var hasTeamsLink: Bool {
        teamsURL != nil
    }
}

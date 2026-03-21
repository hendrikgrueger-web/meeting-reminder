import SwiftUI

struct MeetingEvent: Identifiable, Sendable, Equatable {
    let eventIdentifier: String
    let title: String
    let startDate: Date
    let endDate: Date
    let location: String?
    let calendarColor: Color
    let calendarTitle: String
    let meetingLink: MeetingLink?
    let isAllDay: Bool

    var id: String {
        "\(eventIdentifier)_\(startDate.timeIntervalSince1970)"
    }

    var hasMeetingLink: Bool {
        meetingLink != nil
    }

    var meetingProvider: MeetingProvider? {
        meetingLink?.provider
    }

    var meetingURL: URL? {
        meetingLink?.url
    }
}

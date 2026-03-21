import XCTest
import SwiftUI
@testable import QuickJoin

final class MeetingEventTests: XCTestCase {

    // MARK: - Test Fixtures

    func createTestEvent(
        eventIdentifier: String = "event-123",
        title: String = "Team Meeting",
        startDate: Date = Date(timeIntervalSince1970: 1000000),
        endDate: Date = Date(timeIntervalSince1970: 1003600),
        location: String? = "Conference Room A",
        calendarColor: Color = .blue,
        calendarTitle: String = "Work",
        meetingLink: MeetingLink? = MeetingLink(url: URL(string: "https://teams.microsoft.com/")!, provider: .teams),
        isAllDay: Bool = false
    ) -> MeetingEvent {
        MeetingEvent(
            eventIdentifier: eventIdentifier,
            title: title,
            startDate: startDate,
            endDate: endDate,
            location: location,
            calendarColor: calendarColor,
            calendarTitle: calendarTitle,
            meetingLink: meetingLink,
            isAllDay: isAllDay
        )
    }

    // MARK: - Tests: Composite ID Key (eventIdentifier + startDate)

    func testIdContainsEventIdentifierAndStartDate() {
        let eventId = "meeting-001"
        let startDate = Date(timeIntervalSince1970: 1234567890)
        let event = createTestEvent(
            eventIdentifier: eventId,
            startDate: startDate
        )

        let expectedId = "\(eventId)_\(startDate.timeIntervalSince1970)"
        XCTAssertEqual(event.id, expectedId)
    }

    func testRecurringEventsWithDifferentStartDatesHaveDifferentKeys() {
        let eventId = "recurring-meeting-001"
        let firstDate = Date(timeIntervalSince1970: 1000000)
        let secondDate = Date(timeIntervalSince1970: 2000000)

        let event1 = createTestEvent(
            eventIdentifier: eventId,
            startDate: firstDate
        )
        let event2 = createTestEvent(
            eventIdentifier: eventId,
            startDate: secondDate
        )

        XCTAssertNotEqual(event1.id, event2.id)
        XCTAssertEqual(event1.id, "\(eventId)_\(firstDate.timeIntervalSince1970)")
        XCTAssertEqual(event2.id, "\(eventId)_\(secondDate.timeIntervalSince1970)")
    }

    func testEventsWithSameIdAndStartDateHaveSameKey() {
        let eventId = "meeting-001"
        let startDate = Date(timeIntervalSince1970: 1500000)

        let event1 = createTestEvent(
            eventIdentifier: eventId,
            title: "Original Title",
            startDate: startDate
        )
        let event2 = createTestEvent(
            eventIdentifier: eventId,
            title: "Different Title",
            startDate: startDate
        )

        XCTAssertEqual(event1.id, event2.id)
    }

    // MARK: - Tests: Teams URL

    func testHasMeetingLinkTrue() {
        let link = MeetingLink(url: URL(string: "https://teams.microsoft.com/l/meetup-join/12345")!, provider: .teams)
        let event = createTestEvent(meetingLink: link)

        XCTAssertTrue(event.hasMeetingLink)
        XCTAssertEqual(event.meetingProvider, .teams)
    }

    func testHasMeetingLinkFalse() {
        let event = createTestEvent(meetingLink: nil)

        XCTAssertFalse(event.hasMeetingLink)
        XCTAssertNil(event.meetingProvider)
    }

    func testMeetingURLProperty() {
        let url = URL(string: "https://zoom.us/j/123456789")!
        let link = MeetingLink(url: url, provider: .zoom)
        let event = createTestEvent(meetingLink: link)

        XCTAssertEqual(event.meetingURL, url)
        XCTAssertEqual(event.meetingProvider, .zoom)
    }

    // MARK: - Tests: Property Storage

    func testIsAllDayPropertyStorage() {
        let allDayEvent = createTestEvent(isAllDay: true)
        let timedEvent = createTestEvent(isAllDay: false)

        XCTAssertTrue(allDayEvent.isAllDay)
        XCTAssertFalse(timedEvent.isAllDay)
    }

    func testLocationCanBeNil() {
        let eventWithLocation = createTestEvent(location: "Room 123")
        let eventWithoutLocation = createTestEvent(location: nil)

        XCTAssertEqual(eventWithLocation.location, "Room 123")
        XCTAssertNil(eventWithoutLocation.location)
    }

    func testAllPropertiesStoredCorrectly() {
        let eventId = "event-12345"
        let title = "Q4 Planning"
        let startDate = Date(timeIntervalSince1970: 1700000000)
        let endDate = Date(timeIntervalSince1970: 1700003600)
        let location = "Building 5, Floor 3"
        let calendarColor = Color.green
        let calendarTitle = "Personal"
        let teamsURL = URL(string: "https://teams.microsoft.com/l/meetup-join/xyz")!
        let isAllDay = false

        let event = createTestEvent(
            eventIdentifier: eventId,
            title: title,
            startDate: startDate,
            endDate: endDate,
            location: location,
            calendarColor: calendarColor,
            calendarTitle: calendarTitle,
            meetingLink: MeetingLink(url: teamsURL, provider: .teams),
            isAllDay: isAllDay
        )

        XCTAssertEqual(event.eventIdentifier, eventId)
        XCTAssertEqual(event.title, title)
        XCTAssertEqual(event.startDate, startDate)
        XCTAssertEqual(event.endDate, endDate)
        XCTAssertEqual(event.location, location)
        XCTAssertEqual(event.calendarTitle, calendarTitle)
        XCTAssertEqual(event.meetingURL, teamsURL)
        XCTAssertEqual(event.isAllDay, isAllDay)
    }

    // MARK: - Tests: ID Stability

    func testIdStability() {
        let event = createTestEvent()

        let firstId = event.id
        let secondId = event.id
        let thirdId = event.id

        XCTAssertEqual(firstId, secondId)
        XCTAssertEqual(secondId, thirdId)
    }

    // MARK: - Tests: Edge Cases

    func testEventWithEmptyEventIdentifier() {
        let event = createTestEvent(eventIdentifier: "")

        let expectedId = "_\(event.startDate.timeIntervalSince1970)"
        XCTAssertEqual(event.id, expectedId)
        XCTAssertFalse(event.id.isEmpty)
    }

    func testEventWithLargeTitle() {
        let largeTitle = String(repeating: "A", count: 1000)
        let event = createTestEvent(title: largeTitle)

        XCTAssertEqual(event.title, largeTitle)
        XCTAssertEqual(event.title.count, 1000)
    }

    func testEventWithSpecialCharactersInLocation() {
        let location = "Büro München, Straße 123 (4. OG) - Raum Ü-42"
        let event = createTestEvent(location: location)

        XCTAssertEqual(event.location, location)
    }

    func testIdentifiable() {
        let date1 = Date(timeIntervalSince1970: 1000000)
        let date2 = Date(timeIntervalSince1970: 1000001)

        let event1 = createTestEvent(startDate: date1)
        let event2 = createTestEvent(startDate: date2)

        XCTAssertNotEqual(event1.id, event2.id)
    }

    func testEventWithDifferentCalendarColors() {
        let redEvent = createTestEvent(calendarColor: .red)
        let blueEvent = createTestEvent(calendarColor: .blue)
        let greenEvent = createTestEvent(calendarColor: .green)

        XCTAssertEqual(redEvent.calendarColor, .red)
        XCTAssertEqual(blueEvent.calendarColor, .blue)
        XCTAssertEqual(greenEvent.calendarColor, .green)
    }

    func testEventWithDifferentCalendarTitles() {
        let workEvent = createTestEvent(calendarTitle: "Work")
        let personalEvent = createTestEvent(calendarTitle: "Personal")
        let teamEvent = createTestEvent(calendarTitle: "Team A")

        XCTAssertEqual(workEvent.calendarTitle, "Work")
        XCTAssertEqual(personalEvent.calendarTitle, "Personal")
        XCTAssertEqual(teamEvent.calendarTitle, "Team A")
    }

    func testEventWithEndDateBeforeStartDate() {
        let startDate = Date(timeIntervalSince1970: 2000000)
        let endDate = Date(timeIntervalSince1970: 1000000)

        let event = createTestEvent(
            startDate: startDate,
            endDate: endDate
        )

        XCTAssertGreaterThan(event.startDate, event.endDate)
    }

    // MARK: - Edge Case Tests: Meeting-Link mit verschiedenen Providern

    func testHasMeetingLinkWithZoom() {
        let zoomURL = URL(string: "https://zoom.us/j/123456789")!
        let event = createTestEvent(meetingLink: MeetingLink(url: zoomURL, provider: .zoom))

        XCTAssertTrue(event.hasMeetingLink)
        XCTAssertEqual(event.meetingProvider, .zoom)
        XCTAssertEqual(event.meetingURL, zoomURL)
    }

    func testHasMeetingLinkWithGoogleMeet() {
        let meetURL = URL(string: "https://meet.google.com/abc-defg-hij")!
        let event = createTestEvent(meetingLink: MeetingLink(url: meetURL, provider: .googleMeet))

        XCTAssertTrue(event.hasMeetingLink)
        XCTAssertEqual(event.meetingProvider, .googleMeet)
        XCTAssertEqual(event.meetingURL, meetURL)
    }

    func testHasMeetingLinkWithWebEx() {
        let webexURL = URL(string: "https://company.webex.com/meet/john.doe")!
        let event = createTestEvent(meetingLink: MeetingLink(url: webexURL, provider: .webex))

        XCTAssertTrue(event.hasMeetingLink)
        XCTAssertEqual(event.meetingProvider, .webex)
        XCTAssertEqual(event.meetingURL, webexURL)
    }

    // MARK: - Edge Case Tests: meetingProvider und meetingURL bei nil

    func testMeetingProviderNilWhenNoLink() {
        let event = createTestEvent(meetingLink: nil)

        XCTAssertNil(event.meetingProvider)
        XCTAssertNil(event.meetingURL)
        XCTAssertFalse(event.hasMeetingLink)
    }

    // MARK: - Edge Case Tests: Equatable

    func testEquatableEventsWithSameMeetingLink() {
        let url = URL(string: "https://zoom.us/j/111222333")!
        let link = MeetingLink(url: url, provider: .zoom)
        let event1 = createTestEvent(
            eventIdentifier: "eq-1",
            startDate: Date(timeIntervalSince1970: 1_500_000),
            meetingLink: link
        )
        let event2 = createTestEvent(
            eventIdentifier: "eq-1",
            startDate: Date(timeIntervalSince1970: 1_500_000),
            meetingLink: link
        )

        XCTAssertEqual(event1, event2)
    }

    func testEquatableEventsWithDifferentMeetingLink() {
        let link1 = MeetingLink(url: URL(string: "https://zoom.us/j/111")!, provider: .zoom)
        let link2 = MeetingLink(url: URL(string: "https://zoom.us/j/222")!, provider: .zoom)
        let event1 = createTestEvent(
            eventIdentifier: "eq-diff",
            startDate: Date(timeIntervalSince1970: 1_500_000),
            meetingLink: link1
        )
        let event2 = createTestEvent(
            eventIdentifier: "eq-diff",
            startDate: Date(timeIntervalSince1970: 1_500_000),
            meetingLink: link2
        )

        XCTAssertNotEqual(event1, event2)
    }

    // MARK: - Edge Case Tests: ID-Stabilität

    func testIdStabilityAcrossMultipleAccesses() {
        let event = createTestEvent(
            eventIdentifier: "stable-id",
            startDate: Date(timeIntervalSince1970: 1_234_567)
        )

        let ids = (0..<100).map { _ in event.id }
        let allSame = ids.allSatisfy { $0 == ids.first }
        XCTAssertTrue(allSame)
    }

    // MARK: - Edge Case Tests: Zusammengesetzter Key mit negativem Timestamp

    func testCompositeKeyWithNegativeTimestamp() {
        // Theoretisch: Datum vor 1970
        let ancientDate = Date(timeIntervalSince1970: -1_000_000)
        let event = createTestEvent(
            eventIdentifier: "ancient",
            startDate: ancientDate
        )

        let expectedId = "ancient_\(ancientDate.timeIntervalSince1970)"
        XCTAssertEqual(event.id, expectedId)
        XCTAssertTrue(event.id.contains("-"))
        XCTAssertFalse(event.id.isEmpty)
    }

    // MARK: - Edge Case Tests: Leerer eventIdentifier

    func testEmptyEventIdentifierStillProducesValidId() {
        let event = createTestEvent(eventIdentifier: "")

        XCTAssertFalse(event.id.isEmpty)
        XCTAssertTrue(event.id.hasPrefix("_"))
    }

    // MARK: - Edge Case Tests: Sehr langer Titel + Location

    func testEventWithVeryLongTitleAndLocation() {
        let longTitle = String(repeating: "Ä", count: 5000)
        let longLocation = String(repeating: "ü", count: 5000)
        let event = createTestEvent(title: longTitle, location: longLocation)

        XCTAssertEqual(event.title.count, 5000)
        XCTAssertEqual(event.location?.count, 5000)
        // ID wird nicht vom Titel beeinflusst
        XCTAssertTrue(event.id.contains("event-123"))
    }
}

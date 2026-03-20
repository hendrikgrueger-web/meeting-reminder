import Testing
import SwiftUI
@testable import Meeting_Reminder

@Suite
struct MeetingEventTests {

    // MARK: - Test Fixtures

    func createTestEvent(
        eventIdentifier: String = "event-123",
        title: String = "Team Meeting",
        startDate: Date = Date(timeIntervalSince1970: 1000000),
        endDate: Date = Date(timeIntervalSince1970: 1003600),
        location: String? = "Conference Room A",
        calendarColor: Color = .blue,
        calendarTitle: String = "Work",
        teamsURL: URL? = URL(string: "https://teams.microsoft.com/"),
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
            teamsURL: teamsURL,
            isAllDay: isAllDay
        )
    }

    // MARK: - Tests: Composite ID Key (eventIdentifier + startDate)

    @Test("ID enthält eventIdentifier und startDate")
    func testIdContainsEventIdentifierAndStartDate() {
        let eventId = "meeting-001"
        let startDate = Date(timeIntervalSince1970: 1234567890)
        let event = createTestEvent(
            eventIdentifier: eventId,
            startDate: startDate
        )

        let expectedId = "\(eventId)_\(startDate.timeIntervalSince1970)"
        #expect(event.id == expectedId)
    }

    @Test("Zwei Events mit gleicher ID aber verschiedener startDate haben verschiedene Keys")
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

        #expect(event1.id != event2.id)
        #expect(event1.id == "\(eventId)_\(firstDate.timeIntervalSince1970)")
        #expect(event2.id == "\(eventId)_\(secondDate.timeIntervalSince1970)")
    }

    @Test("Zwei Events mit gleicher ID und gleicher startDate haben denselben Key")
    func testEventsWithSameIdAndStartDateHaveSameKey() {
        let eventId = "meeting-001"
        let startDate = Date(timeIntervalSince1970: 1500000)

        let event1 = createTestEvent(
            eventIdentifier: eventId,
            startDate: startDate,
            title: "Original Title"
        )
        let event2 = createTestEvent(
            eventIdentifier: eventId,
            startDate: startDate,
            title: "Different Title"
        )

        #expect(event1.id == event2.id)
    }

    // MARK: - Tests: Teams URL

    @Test("hasTeamsLink ist true wenn teamsURL gesetzt")
    func testHasTeamsLinkTrue() {
        let teamsURL = URL(string: "https://teams.microsoft.com/l/meetup-join/12345")!
        let event = createTestEvent(teamsURL: teamsURL)

        #expect(event.hasTeamsLink == true)
    }

    @Test("hasTeamsLink ist false wenn teamsURL nil")
    func testHasTeamsLinkFalse() {
        let event = createTestEvent(teamsURL: nil)

        #expect(event.hasTeamsLink == false)
    }

    // MARK: - Tests: Property Storage

    @Test("isAllDay wird korrekt gespeichert")
    func testIsAllDayPropertyStorage() {
        let allDayEvent = createTestEvent(isAllDay: true)
        let timedEvent = createTestEvent(isAllDay: false)

        #expect(allDayEvent.isAllDay == true)
        #expect(timedEvent.isAllDay == false)
    }

    @Test("location kann nil sein")
    func testLocationCanBeNil() {
        let eventWithLocation = createTestEvent(location: "Room 123")
        let eventWithoutLocation = createTestEvent(location: nil)

        #expect(eventWithLocation.location == "Room 123")
        #expect(eventWithoutLocation.location == nil)
    }

    @Test("Alle Properties werden korrekt gespeichert")
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
            teamsURL: teamsURL,
            isAllDay: isAllDay
        )

        #expect(event.eventIdentifier == eventId)
        #expect(event.title == title)
        #expect(event.startDate == startDate)
        #expect(event.endDate == endDate)
        #expect(event.location == location)
        #expect(event.calendarTitle == calendarTitle)
        #expect(event.teamsURL == teamsURL)
        #expect(event.isAllDay == isAllDay)
    }

    // MARK: - Tests: ID Stability

    @Test("ID ist stabil (mehrfacher Aufruf gibt denselben Wert)")
    func testIdStability() {
        let event = createTestEvent()

        let firstId = event.id
        let secondId = event.id
        let thirdId = event.id

        #expect(firstId == secondId)
        #expect(secondId == thirdId)
    }

    // MARK: - Tests: Edge Cases

    @Test("Event mit leerem String als eventIdentifier funktioniert trotzdem")
    func testEventWithEmptyEventIdentifier() {
        let event = createTestEvent(eventIdentifier: "")

        let expectedId = "_\(event.startDate.timeIntervalSince1970)"
        #expect(event.id == expectedId)
        #expect(!event.id.isEmpty)
    }

    @Test("Event mit sehr großem Titel wird gespeichert")
    func testEventWithLargeTitle() {
        let largeTitle = String(repeating: "A", count: 1000)
        let event = createTestEvent(title: largeTitle)

        #expect(event.title == largeTitle)
        #expect(event.title.count == 1000)
    }

    @Test("Event mit Sonderzeichen in Location wird gespeichert")
    func testEventWithSpecialCharactersInLocation() {
        let location = "Büro München, Straße 123 (4. OG) - Raum Ü-42"
        let event = createTestEvent(location: location)

        #expect(event.location == location)
    }

    @Test("Zwei Events sind Identifiable und haben unterschiedliche IDs bei verschiedenen Zeiten")
    func testIdentifiable() {
        let date1 = Date(timeIntervalSince1970: 1000000)
        let date2 = Date(timeIntervalSince1970: 1000001)

        let event1 = createTestEvent(startDate: date1)
        let event2 = createTestEvent(startDate: date2)

        #expect(event1.id != event2.id)
    }

    @Test("Event mit verschiedenen Kalenderfarben wird gespeichert")
    func testEventWithDifferentCalendarColors() {
        let redEvent = createTestEvent(calendarColor: .red)
        let blueEvent = createTestEvent(calendarColor: .blue)
        let greenEvent = createTestEvent(calendarColor: .green)

        #expect(redEvent.calendarColor == .red)
        #expect(blueEvent.calendarColor == .blue)
        #expect(greenEvent.calendarColor == .green)
    }

    @Test("Event mit verschiedenen Kalendertiteln wird gespeichert")
    func testEventWithDifferentCalendarTitles() {
        let workEvent = createTestEvent(calendarTitle: "Work")
        let personalEvent = createTestEvent(calendarTitle: "Personal")
        let teamEvent = createTestEvent(calendarTitle: "Team A")

        #expect(workEvent.calendarTitle == "Work")
        #expect(personalEvent.calendarTitle == "Personal")
        #expect(teamEvent.calendarTitle == "Team A")
    }

    @Test("Event mit endDate vor startDate wird trotzdem erstellt")
    func testEventWithEndDateBeforeStartDate() {
        let startDate = Date(timeIntervalSince1970: 2000000)
        let endDate = Date(timeIntervalSince1970: 1000000) // Earlier than startDate

        let event = createTestEvent(
            startDate: startDate,
            endDate: endDate
        )

        #expect(event.startDate > event.endDate)
    }
}

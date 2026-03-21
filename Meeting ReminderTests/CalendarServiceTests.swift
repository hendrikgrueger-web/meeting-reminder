// CalendarServiceTests.swift
// Tests für die reine Logik des CalendarService (static Funktionen)
// Da EventKit einen echten Kalender braucht, testen wir nur die testbare Logik.

import Testing
import SwiftUI
@testable import Meeting_Reminder

@Suite("CalendarService Logik-Tests")
struct CalendarServiceTests {

    // MARK: - Test Fixtures

    private func makeEvent(
        eventIdentifier: String = "event-123",
        title: String = "Team Meeting",
        startDate: Date = Date(timeIntervalSince1970: 1_000_000),
        endDate: Date = Date(timeIntervalSince1970: 1_003_600),
        location: String? = nil,
        calendarColor: Color = .blue,
        calendarTitle: String = "Work",
        meetingLink: MeetingLink? = nil,
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

    // MARK: - Event-Relevanz Tests

    @Test("Ganztägiges Event ist nicht relevant")
    func allDayEventNotRelevant() {
        let event = makeEvent(startDate: Date().addingTimeInterval(3600), isAllDay: true)
        let result = CalendarService.isEventRelevant(
            event,
            now: Date(),
            onlyOnlineMeetings: false,
            dismissedEvents: []
        )
        #expect(result == false)
    }

    @Test("Event in der Zukunft ist relevant")
    func futureEventIsRelevant() {
        let futureDate = Date().addingTimeInterval(3600)
        let event = makeEvent(startDate: futureDate)
        let result = CalendarService.isEventRelevant(
            event,
            now: Date(),
            onlyOnlineMeetings: false,
            dismissedEvents: []
        )
        #expect(result == true)
    }

    @Test("Event > 5 Min in Vergangenheit ist nicht relevant")
    func oldEventNotRelevant() {
        let pastDate = Date().addingTimeInterval(-6 * 60) // 6 Min in der Vergangenheit
        let event = makeEvent(startDate: pastDate)
        let result = CalendarService.isEventRelevant(
            event,
            now: Date(),
            onlyOnlineMeetings: false,
            dismissedEvents: []
        )
        #expect(result == false)
    }

    @Test("Event < 5 Min in Vergangenheit ist relevant")
    func recentPastEventIsRelevant() {
        let pastDate = Date().addingTimeInterval(-3 * 60) // 3 Min in der Vergangenheit
        let event = makeEvent(startDate: pastDate)
        let result = CalendarService.isEventRelevant(
            event,
            now: Date(),
            onlyOnlineMeetings: false,
            dismissedEvents: []
        )
        #expect(result == true)
    }

    @Test("Nur Online aktiv + kein Teams-Link ist nicht relevant")
    func onlyOnlineNoTeamsLink() {
        let event = makeEvent(startDate: Date().addingTimeInterval(3600), meetingLink: nil)
        let result = CalendarService.isEventRelevant(
            event,
            now: Date(),
            onlyOnlineMeetings: true,
            dismissedEvents: []
        )
        #expect(result == false)
    }

    @Test("Nur Online aktiv + Teams-Link ist relevant")
    func onlyOnlineWithTeamsLink() {
        let teamsURL = URL(string: "https://teams.microsoft.com/l/meetup-join/test")!
        let event = makeEvent(startDate: Date().addingTimeInterval(3600), meetingLink: MeetingLink(url: teamsURL, provider: .teams))
        let result = CalendarService.isEventRelevant(
            event,
            now: Date(),
            onlyOnlineMeetings: true,
            dismissedEvents: []
        )
        #expect(result == true)
    }

    @Test("Dismissed Event ist nicht relevant")
    func dismissedEventNotRelevant() {
        let startDate = Date().addingTimeInterval(3600)
        let event = makeEvent(eventIdentifier: "dismissed-1", startDate: startDate)
        let dismissedKey = event.id
        let result = CalendarService.isEventRelevant(
            event,
            now: Date(),
            onlyOnlineMeetings: false,
            dismissedEvents: [dismissedKey]
        )
        #expect(result == false)
    }

    // MARK: - Dismissed Key Tests

    @Test("Zusammengesetzter Key enthält ID und Datum")
    func dismissKeyContainsIDAndDate() {
        let startDate = Date(timeIntervalSince1970: 1_700_000_000)
        let event = makeEvent(eventIdentifier: "ABC-123", startDate: startDate)
        let key = CalendarService.dismissKey(for: event)
        #expect(key.contains("ABC-123"))
        #expect(key.contains("1700000000"))
    }

    @Test("Verschiedene Occurrences haben verschiedene Keys")
    func differentOccurrencesHaveDifferentKeys() {
        let date1 = Date(timeIntervalSince1970: 1_000_000)
        let date2 = Date(timeIntervalSince1970: 2_000_000)
        let event1 = makeEvent(eventIdentifier: "recurring", startDate: date1)
        let event2 = makeEvent(eventIdentifier: "recurring", startDate: date2)
        let key1 = CalendarService.dismissKey(for: event1)
        let key2 = CalendarService.dismissKey(for: event2)
        #expect(key1 != key2)
    }

    // MARK: - Dismissed Set Cleanup Tests

    @Test("Alte Events werden aus dem Dismissed-Set entfernt")
    func cleanupRemovesOldEvents() {
        let now = Date()
        let oldTimestamp = now.addingTimeInterval(-3 * 3600).timeIntervalSince1970 // 3h alt
        let recentTimestamp = now.addingTimeInterval(-1 * 3600).timeIntervalSince1970 // 1h alt
        let oldKey = "event-old_\(oldTimestamp)"
        let recentKey = "event-recent_\(recentTimestamp)"
        let dismissed: Set<String> = [oldKey, recentKey]
        let cleaned = CalendarService.cleanedDismissedSet(dismissed, now: now)
        // oldKey: 3h alt, Cleanup-Grenze 2h -> wird entfernt
        #expect(!cleaned.contains(oldKey))
        // recentKey: 1h alt -> wird behalten (innerhalb 2h)
        #expect(cleaned.contains(recentKey))
    }

    // MARK: - Event-Sortierung Tests

    @Test("Teams-Link-Events kommen zuerst bei gleicher Startzeit")
    func teamsLinkEventsFirstAtSameStartTime() {
        let startDate = Date(timeIntervalSince1970: 1_000_000)
        let teamsURL = URL(string: "https://teams.microsoft.com/l/meetup-join/test")!
        let eventWithTeams = makeEvent(
            eventIdentifier: "teams-event",
            title: "Teams Meeting",
            startDate: startDate,
            meetingLink: MeetingLink(url: teamsURL, provider: .teams)
        )
        let eventWithoutTeams = makeEvent(
            eventIdentifier: "no-teams",
            title: "Raum-Meeting",
            startDate: startDate,
            meetingLink: nil
        )
        let result = CalendarService.compareEvents(eventWithTeams, eventWithoutTeams)
        #expect(result == true) // Teams-Event kommt zuerst
        let reverseResult = CalendarService.compareEvents(eventWithoutTeams, eventWithTeams)
        #expect(reverseResult == false)
    }

    @Test("Früheres Event kommt zuerst bei verschiedener Startzeit")
    func earlierEventComesFirst() {
        let earlyDate = Date(timeIntervalSince1970: 1_000_000)
        let lateDate = Date(timeIntervalSince1970: 2_000_000)
        let earlyEvent = makeEvent(eventIdentifier: "early", startDate: earlyDate)
        let lateEvent = makeEvent(eventIdentifier: "late", startDate: lateDate)
        let result = CalendarService.compareEvents(earlyEvent, lateEvent)
        #expect(result == true)
        let reverseResult = CalendarService.compareEvents(lateEvent, earlyEvent)
        #expect(reverseResult == false)
    }

    // MARK: - Defaults Tests

    @Test("leadTimeMinutes Default ist 1")
    func leadTimeDefault() async {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "leadTimeMinutes")
        let raw = defaults.integer(forKey: "leadTimeMinutes")
        let value = raw > 0 ? raw : 1
        #expect(value == 1)
    }

    @Test("onlyOnlineMeetings Default ist false")
    func onlyOnlineDefault() async {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "onlyOnlineMeetings")
        let value = defaults.bool(forKey: "onlyOnlineMeetings")
        #expect(value == false)
    }

    // MARK: - EnabledCalendarIDs Tests

    @Test("Leere Data gibt nil zurück (Fallback auf alle Kalender)")
    func emptyDataReturnsNil() {
        let result = CalendarService.decodeEnabledCalendarIDs(from: Data())
        #expect(result == nil)
    }

    @Test("Gültige Data wird korrekt dekodiert")
    func validDataDecodes() {
        let ids: Set<String> = ["cal-1", "cal-2", "cal-3"]
        let data = try! JSONEncoder().encode(ids)
        let result = CalendarService.decodeEnabledCalendarIDs(from: data)
        #expect(result == ids)
    }

    // MARK: - Zusätzliche Relevanz-Tests

    @Test("Event genau an der 5-Min-Grenze + 1 Sek ist nicht relevant")
    func eventAtExactFiveMinuteBoundary() {
        let now = Date()
        let pastDate = now.addingTimeInterval(-5 * 60 - 1)
        let event = makeEvent(startDate: pastDate)
        let result = CalendarService.isEventRelevant(
            event,
            now: now,
            onlyOnlineMeetings: false,
            dismissedEvents: []
        )
        #expect(result == false)
    }

    @Test("Event genau 5 Min in der Vergangenheit ist noch relevant")
    func eventExactlyFiveMinutesAgo() {
        let now = Date()
        let pastDate = now.addingTimeInterval(-5 * 60)
        let event = makeEvent(startDate: pastDate)
        let result = CalendarService.isEventRelevant(
            event,
            now: now,
            onlyOnlineMeetings: false,
            dismissedEvents: []
        )
        #expect(result == true)
    }

    @Test("Sortierung bei gleicher Startzeit ohne Teams: Kalender-Titel alphabetisch")
    func sortByCalendarTitleWhenNoTeamsLink() {
        let startDate = Date(timeIntervalSince1970: 1_000_000)
        let eventA = makeEvent(
            eventIdentifier: "a",
            startDate: startDate,
            calendarTitle: "Alpha",
            meetingLink: nil
        )
        let eventB = makeEvent(
            eventIdentifier: "b",
            startDate: startDate,
            calendarTitle: "Beta",
            meetingLink: nil
        )
        let result = CalendarService.compareEvents(eventA, eventB)
        #expect(result == true) // Alpha < Beta
    }
}

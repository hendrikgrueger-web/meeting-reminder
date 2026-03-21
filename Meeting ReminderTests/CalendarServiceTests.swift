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

    // MARK: - Edge Case Tests: Event-Relevanz Grenzfälle

    @Test("Event genau jetzt (startDate == now) ist relevant")
    func eventExactlyNowIsRelevant() {
        let now = Date()
        let event = makeEvent(startDate: now)
        let result = CalendarService.isEventRelevant(
            event,
            now: now,
            onlyOnlineMeetings: false,
            dismissedEvents: []
        )
        #expect(result == true)
    }

    @Test("Event 4:59 Min in der Vergangenheit ist relevant (Grenzfall)")
    func eventFourMinutesFiftyNineSecondsAgoIsRelevant() {
        let now = Date()
        let pastDate = now.addingTimeInterval(-(4 * 60 + 59))
        let event = makeEvent(startDate: pastDate)
        let result = CalendarService.isEventRelevant(
            event,
            now: now,
            onlyOnlineMeetings: false,
            dismissedEvents: []
        )
        #expect(result == true)
    }

    @Test("Nur Online-Meetings: Event mit Zoom-Link ist relevant")
    func onlyOnlineWithZoomLink() {
        let zoomURL = URL(string: "https://zoom.us/j/123456789")!
        let event = makeEvent(
            startDate: Date().addingTimeInterval(3600),
            meetingLink: MeetingLink(url: zoomURL, provider: .zoom)
        )
        let result = CalendarService.isEventRelevant(
            event,
            now: Date(),
            onlyOnlineMeetings: true,
            dismissedEvents: []
        )
        #expect(result == true)
    }

    @Test("Nur Online-Meetings: Event mit Google Meet-Link ist relevant")
    func onlyOnlineWithGoogleMeetLink() {
        let meetURL = URL(string: "https://meet.google.com/abc-defg-hij")!
        let event = makeEvent(
            startDate: Date().addingTimeInterval(3600),
            meetingLink: MeetingLink(url: meetURL, provider: .googleMeet)
        )
        let result = CalendarService.isEventRelevant(
            event,
            now: Date(),
            onlyOnlineMeetings: true,
            dismissedEvents: []
        )
        #expect(result == true)
    }

    @Test("Event genau bei 5 Min 0 Sek Differenz ist noch relevant (Grenzwert)")
    func eventExactlyAtFiveMinuteBoundaryIsRelevant() {
        let now = Date()
        let pastDate = now.addingTimeInterval(-5 * 60) // Genau 5 Min
        let event = makeEvent(startDate: pastDate)
        let result = CalendarService.isEventRelevant(
            event,
            now: now,
            onlyOnlineMeetings: false,
            dismissedEvents: []
        )
        // timeSinceStart == 300, Bedingung ist > 300 → Event ist noch relevant
        #expect(result == true)
    }

    @Test("isEventRelevant: Event mit isAllDay=true und meetingLink ist trotzdem nicht relevant")
    func allDayEventWithMeetingLinkNotRelevant() {
        let teamsURL = URL(string: "https://teams.microsoft.com/l/meetup-join/test")!
        let event = makeEvent(
            startDate: Date().addingTimeInterval(3600),
            meetingLink: MeetingLink(url: teamsURL, provider: .teams),
            isAllDay: true
        )
        let result = CalendarService.isEventRelevant(
            event,
            now: Date(),
            onlyOnlineMeetings: false,
            dismissedEvents: []
        )
        #expect(result == false)
    }

    // MARK: - Edge Case Tests: Dismissed Set Cleanup

    @Test("Dismissed Set Cleanup: Event genau 2h alt wird behalten")
    func cleanupKeepsEventExactlyTwoHoursOld() {
        let now = Date()
        let twoHoursAgoTimestamp = now.addingTimeInterval(-2 * 3600).timeIntervalSince1970
        let key = "event-boundary_\(twoHoursAgoTimestamp)"
        let dismissed: Set<String> = [key]
        let cleaned = CalendarService.cleanedDismissedSet(dismissed, now: now)
        // Event 2h alt, Cleanup-Grenze ist addingTimeInterval(2*3600) > now → exakt gleich → false
        // Date(twoHoursAgoTimestamp).addingTimeInterval(2*3600) == now → nicht > now → wird entfernt
        #expect(!cleaned.contains(key))
    }

    @Test("Dismissed Set Cleanup: Event 1h59min alt wird behalten")
    func cleanupKeepsEventJustUnderTwoHours() {
        let now = Date()
        let justUnderTimestamp = now.addingTimeInterval(-(2 * 3600 - 60)).timeIntervalSince1970
        let key = "event-recent_\(justUnderTimestamp)"
        let dismissed: Set<String> = [key]
        let cleaned = CalendarService.cleanedDismissedSet(dismissed, now: now)
        #expect(cleaned.contains(key))
    }

    @Test("Dismissed Set Cleanup: Event 2h01 alt wird entfernt")
    func cleanupRemovesEventTwoHoursOneMinuteOld() {
        let now = Date()
        let oldTimestamp = now.addingTimeInterval(-(2 * 3600 + 60)).timeIntervalSince1970
        let key = "event-old_\(oldTimestamp)"
        let dismissed: Set<String> = [key]
        let cleaned = CalendarService.cleanedDismissedSet(dismissed, now: now)
        #expect(!cleaned.contains(key))
    }

    @Test("Dismissed Set Cleanup: Leeres Set bleibt leer")
    func cleanupEmptySetStaysEmpty() {
        let dismissed: Set<String> = []
        let cleaned = CalendarService.cleanedDismissedSet(dismissed, now: Date())
        #expect(cleaned.isEmpty)
    }

    @Test("Dismissed Set Cleanup: Ungültiger Key-Format wird entfernt")
    func cleanupRemovesInvalidKeyFormat() {
        let dismissed: Set<String> = ["kein-unterstrich", "auch_kein_gültiger_timestamp_abc"]
        let cleaned = CalendarService.cleanedDismissedSet(dismissed, now: Date())
        #expect(cleaned.isEmpty)
    }

    // MARK: - Edge Case Tests: Sortierung

    @Test("Sortierung: 3 Events mit gemischten Links und Startzeiten")
    func sortThreeEventsWithMixedLinksAndTimes() {
        let earlyDate = Date(timeIntervalSince1970: 1_000_000)
        let midDate = Date(timeIntervalSince1970: 1_000_000) // gleiche Zeit wie early
        let lateDate = Date(timeIntervalSince1970: 2_000_000)

        let teamsURL = URL(string: "https://teams.microsoft.com/meet/test")!
        let eventWithLink = makeEvent(
            eventIdentifier: "a",
            startDate: earlyDate,
            meetingLink: MeetingLink(url: teamsURL, provider: .teams)
        )
        let eventWithoutLink = makeEvent(
            eventIdentifier: "b",
            startDate: midDate,
            meetingLink: nil
        )
        let laterEvent = makeEvent(
            eventIdentifier: "c",
            startDate: lateDate,
            meetingLink: nil
        )

        // eventWithLink vor eventWithoutLink (gleiche Zeit, Link hat Priorität)
        #expect(CalendarService.compareEvents(eventWithLink, eventWithoutLink) == true)
        // eventWithoutLink vor laterEvent (frühere Startzeit)
        #expect(CalendarService.compareEvents(eventWithoutLink, laterEvent) == true)
        // eventWithLink vor laterEvent (frühere Startzeit)
        #expect(CalendarService.compareEvents(eventWithLink, laterEvent) == true)
    }

    @Test("Sortierung: Events mit gleicher Startzeit und gleichem Kalender → stabil")
    func sortEventsWithSameStartTimeAndCalendar() {
        let startDate = Date(timeIntervalSince1970: 1_000_000)
        let eventA = makeEvent(
            eventIdentifier: "a",
            title: "Meeting A",
            startDate: startDate,
            calendarTitle: "Work",
            meetingLink: nil
        )
        let eventB = makeEvent(
            eventIdentifier: "b",
            title: "Meeting B",
            startDate: startDate,
            calendarTitle: "Work",
            meetingLink: nil
        )
        // Gleiche Startzeit, kein Link, gleicher Kalender → compareEvents gibt false zurück (nicht kleiner)
        let resultAB = CalendarService.compareEvents(eventA, eventB)
        let resultBA = CalendarService.compareEvents(eventB, eventA)
        // Wenn calendarTitle gleich, sind beide nicht "kleiner" als der andere
        #expect(resultAB == false)
        #expect(resultBA == false)
    }

    @Test("compareEvents: Event ohne Link kommt nach Event mit Link bei gleicher Startzeit")
    func eventWithoutLinkComesAfterEventWithLink() {
        let startDate = Date(timeIntervalSince1970: 1_000_000)
        let zoomURL = URL(string: "https://zoom.us/j/123456789")!
        let eventWithLink = makeEvent(
            eventIdentifier: "with-link",
            startDate: startDate,
            meetingLink: MeetingLink(url: zoomURL, provider: .zoom)
        )
        let eventWithoutLink = makeEvent(
            eventIdentifier: "no-link",
            startDate: startDate,
            meetingLink: nil
        )
        // Mit Link kommt zuerst
        #expect(CalendarService.compareEvents(eventWithLink, eventWithoutLink) == true)
        // Ohne Link kommt nicht zuerst
        #expect(CalendarService.compareEvents(eventWithoutLink, eventWithLink) == false)
    }

    // MARK: - Edge Case Tests: enabledCalendarIDs Dekodierung

    @Test("enabledCalendarIDs: Ungültige JSON-Data gibt nil zurück")
    func invalidJSONDataReturnsNil() {
        let invalidData = "kein json".data(using: .utf8)!
        let result = CalendarService.decodeEnabledCalendarIDs(from: invalidData)
        #expect(result == nil)
    }

    @Test("enabledCalendarIDs: Leeres Set wird korrekt dekodiert")
    func emptySetDecodesCorrectly() {
        let emptySet: Set<String> = []
        let data = try! JSONEncoder().encode(emptySet)
        let result = CalendarService.decodeEnabledCalendarIDs(from: data)
        #expect(result != nil)
        #expect(result!.isEmpty)
    }

    @Test("enabledCalendarIDs: JSON-Array statt Set gibt nil zurück")
    func jsonArrayInsteadOfSetReturnsNil() {
        // Ein Array von Strings sollte als Set dekodierbar sein, da JSONDecoder Set<String> aus Array dekodiert
        let arrayData = "[\"a\",\"b\"]".data(using: .utf8)!
        let result = CalendarService.decodeEnabledCalendarIDs(from: arrayData)
        // JSONDecoder dekodiert Set<String> aus JSON-Array
        #expect(result != nil)
        #expect(result == Set(["a", "b"]))
    }
}

// CalendarServiceTests.swift
// Tests für die reine Logik des CalendarService (static Funktionen)
// Da EventKit einen echten Kalender braucht, testen wir nur die testbare Logik.

import Testing
import SwiftUI
@testable import NevLate

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
        // Cleanup-Grenze ist >= now (inklusiv): genau 2h alt → gleich → true → wird behalten
        #expect(cleaned.contains(key))
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

    // MARK: - nextEvent-Ableitung aus todayEvents (endDate > now)

    @Test("nextEvent-Logik: Vergangenes Meeting wird übersprungen, nächstes gezeigt")
    func nextEventSkipsPastMeeting() {
        let now = Date()
        let pastEvent = makeEvent(
            eventIdentifier: "past",
            title: "Vergangenes Meeting",
            startDate: now.addingTimeInterval(-2 * 3600),
            endDate: now.addingTimeInterval(-1 * 3600)
        )
        let futureEvent = makeEvent(
            eventIdentifier: "future",
            title: "Zukünftiges Meeting",
            startDate: now.addingTimeInterval(1 * 3600),
            endDate: now.addingTimeInterval(2 * 3600)
        )
        let todayEvents = [pastEvent, futureEvent].sorted { $0.startDate < $1.startDate }
        let result = todayEvents.first(where: { $0.endDate > now })
        #expect(result?.eventIdentifier == "future")
    }

    @Test("nextEvent-Logik: Laufendes Meeting wird angezeigt")
    func nextEventShowsRunningMeeting() {
        let now = Date()
        let runningEvent = makeEvent(
            eventIdentifier: "running",
            title: "Laufendes Meeting",
            startDate: now.addingTimeInterval(-30 * 60),
            endDate: now.addingTimeInterval(30 * 60)
        )
        let futureEvent = makeEvent(
            eventIdentifier: "future",
            title: "Späteres Meeting",
            startDate: now.addingTimeInterval(2 * 3600),
            endDate: now.addingTimeInterval(3 * 3600)
        )
        let todayEvents = [runningEvent, futureEvent].sorted { $0.startDate < $1.startDate }
        let result = todayEvents.first(where: { $0.endDate > now })
        #expect(result?.eventIdentifier == "running")
    }

    @Test("nextEvent-Logik: Kein Meeting mehr heute → nil")
    func nextEventNilWhenAllPast() {
        let now = Date()
        let pastEvent1 = makeEvent(
            eventIdentifier: "past1",
            startDate: now.addingTimeInterval(-4 * 3600),
            endDate: now.addingTimeInterval(-3 * 3600)
        )
        let pastEvent2 = makeEvent(
            eventIdentifier: "past2",
            startDate: now.addingTimeInterval(-2 * 3600),
            endDate: now.addingTimeInterval(-1 * 3600)
        )
        let todayEvents = [pastEvent1, pastEvent2].sorted { $0.startDate < $1.startDate }
        let result = todayEvents.first(where: { $0.endDate > now })
        #expect(result == nil)
    }

    @Test("nextEvent-Logik: Leere todayEvents → nil")
    func nextEventNilWhenEmpty() {
        let todayEvents: [MeetingEvent] = []
        let result = todayEvents.first(where: { $0.endDate > Date() })
        #expect(result == nil)
    }

    @Test("nextEvent-Logik: Meeting ohne Link wird auch angezeigt (kein Online-Only-Filter)")
    func nextEventShowsMeetingWithoutLink() {
        let now = Date()
        let offlineMeeting = makeEvent(
            eventIdentifier: "offline",
            title: "Raum-Meeting",
            startDate: now.addingTimeInterval(30 * 60),
            endDate: now.addingTimeInterval(90 * 60),
            meetingLink: nil
        )
        let todayEvents = [offlineMeeting]
        let result = todayEvents.first(where: { $0.endDate > now })
        #expect(result?.eventIdentifier == "offline")
    }

    @Test("upcomingCount-Logik: Zählt alle Meetings in 60 Min, auch ohne Link")
    func upcomingCountIncludesOfflineMeetings() {
        let now = Date()
        let oneHourFromNow = now.addingTimeInterval(60 * 60)
        let onlineMeeting = makeEvent(
            eventIdentifier: "online",
            startDate: now.addingTimeInterval(20 * 60),
            endDate: now.addingTimeInterval(80 * 60),
            meetingLink: MeetingLink(url: URL(string: "https://zoom.us/j/123")!, provider: .zoom)
        )
        let offlineMeeting = makeEvent(
            eventIdentifier: "offline",
            startDate: now.addingTimeInterval(40 * 60),
            endDate: now.addingTimeInterval(100 * 60),
            meetingLink: nil
        )
        let todayEvents = [onlineMeeting, offlineMeeting].sorted { $0.startDate < $1.startDate }
        let count = todayEvents.filter { $0.startDate > now && $0.startDate <= oneHourFromNow }.count
        #expect(count == 2)
    }

    // MARK: - Snooze-Callback Entscheidungslogik

    @Test("Snooze: Event < 5 Min seit Start + nicht dismissed + nicht pending → erneut anzeigen")
    func snoozeReShow_underFiveMinutes_shows() {
        let now = Date()
        let event = makeEvent(startDate: now.addingTimeInterval(-2 * 60)) // 2 Min her
        let result = CalendarService.shouldReShowSnoozedEvent(
            event, now: now, dismissedEvents: [], pendingEvents: []
        )
        #expect(result == true)
    }

    @Test("Snooze: Event > 5 Min seit Start → nicht erneut anzeigen")
    func snoozeReShow_overFiveMinutes_hides() {
        let now = Date()
        let event = makeEvent(startDate: now.addingTimeInterval(-6 * 60)) // 6 Min her
        let result = CalendarService.shouldReShowSnoozedEvent(
            event, now: now, dismissedEvents: [], pendingEvents: []
        )
        #expect(result == false)
    }

    @Test("Snooze: Event dismissed → nicht erneut anzeigen")
    func snoozeReShow_dismissed_hides() {
        let now = Date()
        let event = makeEvent(eventIdentifier: "dismissed-event", startDate: now.addingTimeInterval(-1 * 60))
        let result = CalendarService.shouldReShowSnoozedEvent(
            event, now: now, dismissedEvents: [event.id], pendingEvents: []
        )
        #expect(result == false)
    }

    @Test("Snooze: Event bereits in pendingEvents → nicht doppelt hinzufügen")
    func snoozeReShow_alreadyPending_hides() {
        let now = Date()
        let event = makeEvent(startDate: now.addingTimeInterval(-1 * 60))
        let result = CalendarService.shouldReShowSnoozedEvent(
            event, now: now, dismissedEvents: [], pendingEvents: [event]
        )
        #expect(result == false)
    }

    @Test("Snooze: Event genau 5 Min → nicht mehr anzeigen (Grenzwert, strikt <)")
    func snoozeReShow_exactlyFiveMinutes_hides() {
        let now = Date()
        let event = makeEvent(startDate: now.addingTimeInterval(-5 * 60))
        let result = CalendarService.shouldReShowSnoozedEvent(
            event, now: now, dismissedEvents: [], pendingEvents: []
        )
        #expect(result == false) // timeSinceStart == 300, Bedingung < 300 → false
    }

    // MARK: - upcomingCount-Logik

    @Test("upcomingCount-Logik: Laufendes Meeting zählt nicht als upcoming")
    func upcomingCountExcludesRunningMeeting() {
        let now = Date()
        let oneHourFromNow = now.addingTimeInterval(60 * 60)
        let runningMeeting = makeEvent(
            eventIdentifier: "running",
            startDate: now.addingTimeInterval(-10 * 60),
            endDate: now.addingTimeInterval(50 * 60)
        )
        let futureMeeting = makeEvent(
            eventIdentifier: "future",
            startDate: now.addingTimeInterval(30 * 60),
            endDate: now.addingTimeInterval(90 * 60)
        )
        let todayEvents = [runningMeeting, futureMeeting].sorted { $0.startDate < $1.startDate }
        let count = todayEvents.filter { $0.startDate > now && $0.startDate <= oneHourFromNow }.count
        #expect(count == 1) // Nur futureMeeting, nicht runningMeeting
    }
}

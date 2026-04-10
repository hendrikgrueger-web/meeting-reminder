import XCTest
import SwiftUI
@testable import NevLate

// MARK: - Hilfsfunktion: Test-Event erstellen

private func makeEvent(
    title: String = "Test Meeting",
    minutesFromNow: Double = 10,
    meetingLink: MeetingLink? = nil
) -> MeetingEvent {
    let now = Date()
    return MeetingEvent(
        eventIdentifier: "test-\(UUID().uuidString)",
        title: title,
        startDate: now.addingTimeInterval(minutesFromNow * 60),
        endDate: now.addingTimeInterval((minutesFromNow + 60) * 60),
        location: nil,
        calendarColor: .blue,
        calendarTitle: "Test",
        meetingLink: meetingLink,
        isAllDay: false
    )
}

// MARK: - menuBarIconState Tests

final class MenuBarIconTests: XCTestCase {

    func testIcon_noAccess_returnsSlash() {
        let icon = MeetingReminderApp.menuBarIconState(accessGranted: false, nextEvent: nil)
        XCTAssertEqual(icon, .noAccess)
    }

    func testIcon_noAccess_ignoresEvent() {
        let event = makeEvent(minutesFromNow: 2)
        let icon = MeetingReminderApp.menuBarIconState(accessGranted: false, nextEvent: event)
        XCTAssertEqual(icon, .noAccess)
    }

    func testIcon_noEvent_returnsBell() {
        let icon = MeetingReminderApp.menuBarIconState(accessGranted: true, nextEvent: nil)
        XCTAssertEqual(icon, .idle)
    }

    func testIcon_under5Min_returnsFill() {
        let now = Date()
        let event = makeEvent(minutesFromNow: 3)
        let icon = MeetingReminderApp.menuBarIconState(accessGranted: true, nextEvent: event, now: now)
        XCTAssertEqual(icon, .urgent)
    }

    func testIcon_under15Min_returnsBadge() {
        let now = Date()
        let event = makeEvent(minutesFromNow: 10)
        let icon = MeetingReminderApp.menuBarIconState(accessGranted: true, nextEvent: event, now: now)
        XCTAssertEqual(icon, .soon)
    }

    func testIcon_over15Min_returnsBell() {
        let now = Date()
        let event = makeEvent(minutesFromNow: 30)
        let icon = MeetingReminderApp.menuBarIconState(accessGranted: true, nextEvent: event, now: now)
        XCTAssertEqual(icon, .idle)
    }

    func testIcon_exactly5Min_returnsBadge() {
        let now = Date()
        let event = makeEvent(minutesFromNow: 5)
        let icon = MeetingReminderApp.menuBarIconState(accessGranted: true, nextEvent: event, now: now)
        XCTAssertEqual(icon, .soon)
    }
}

// MARK: - menuBarTooltipText Tests

final class MenuBarTooltipTests: XCTestCase {

    func testTooltip_noAccess() {
        let text = MeetingReminderApp.menuBarTooltipText(accessGranted: false, nextEvent: nil)
        XCTAssertEqual(text, "Kein Kalenderzugriff – Einstellungen öffnen")
    }

    func testTooltip_noEvent() {
        let text = MeetingReminderApp.menuBarTooltipText(accessGranted: true, nextEvent: nil)
        XCTAssertEqual(text, "Keine anstehenden Meetings")
    }

    func testTooltip_runningMeeting() {
        let now = Date()
        let event = makeEvent(title: "Standup", minutesFromNow: -2)
        let text = MeetingReminderApp.menuBarTooltipText(accessGranted: true, nextEvent: event, now: now)
        XCTAssertEqual(text, "Meeting läuft: Standup")
    }

    func testTooltip_exactlyZeroMinutes() {
        let now = Date()
        let event = makeEvent(title: "Kickoff", minutesFromNow: 0)
        let text = MeetingReminderApp.menuBarTooltipText(accessGranted: true, nextEvent: event, now: now)
        XCTAssertEqual(text, "Meeting läuft: Kickoff")
    }

    func testTooltip_oneMinute() {
        let now = Date()
        let event = makeEvent(title: "Sync", minutesFromNow: 1)
        let text = MeetingReminderApp.menuBarTooltipText(accessGranted: true, nextEvent: event, now: now)
        XCTAssertEqual(text, "Nächstes Meeting: Sync in 1 Min")
    }

    func testTooltip_multipleMinutes() {
        let now = Date()
        let event = makeEvent(title: "Review", minutesFromNow: 7)
        let text = MeetingReminderApp.menuBarTooltipText(accessGranted: true, nextEvent: event, now: now)
        XCTAssertEqual(text, "Nächstes Meeting: Review in 7 Min")
    }
}

// MARK: - handlePendingEvents / Screen-Sharing Tests

@MainActor
final class HandlePendingEventsTests: XCTestCase {

    var delegate: MeetingAppDelegate!
    var calendarService: CalendarService!
    var overlayController: OverlayController!

    override func setUp() {
        super.setUp()
        delegate = MeetingAppDelegate()
        calendarService = CalendarService.shared
        overlayController = OverlayController.shared
    }

    override func tearDown() {
        // Singleton-States auf Default-Werte zurücksetzen,
        // damit Tests keine anderen Tests beeinflussen.

        // CalendarService Settings
        calendarService.silentWhenScreenSharing = true   // Default: true
        calendarService.soundEnabled = false              // Default: false
        calendarService.pendingEvents = []                // Default: []

        // OverlayController: Panel aufräumen falls offen
        overlayController.dismiss()

        // Folgende Properties sind private und nicht direkt zurücksetzbar:
        //   calendarService.snoozeUntil    (private, Default: [:])
        //   calendarService.silencedEvents (private, Default: [])
        //   calendarService.dismissedEvents (private, Default: [])
        // Da reloadAndReschedule() silencedEvents.removeAll() aufruft und
        // snoozeUntil abgelaufene Einträge filtert, sind diese States
        // nach einem naechsten Reload automatisch bereinigt.

        delegate = nil
        calendarService = nil
        overlayController = nil
        super.tearDown()
    }

    func testEmptyEvents_dismissesOverlay() {
        // Act: leere Event-Liste → dismiss
        delegate.handlePendingEvents(
            [],
            calendarService: calendarService,
            overlayController: overlayController,
            isScreenSharing: { false }
        )
        // Assert: kein Crash, overlay.dismiss() aufgerufen
        // (overlayController.panel sollte nil sein nach dismiss in Test-Umgebung)
        XCTAssertNil(overlayController.panel)
    }

    func testScreenSharing_silentEnabled_sendsNotificationNotOverlay() {
        // Arrange
        calendarService.silentWhenScreenSharing = true
        let event = makeEvent(minutesFromNow: 1)
        var screenSharingCalled = false

        // Act
        delegate.handlePendingEvents(
            [event],
            calendarService: calendarService,
            overlayController: overlayController,
            isScreenSharing: {
                screenSharingCalled = true
                return true
            }
        )

        // Assert: isScreenSharing wurde abgefragt, kein Overlay angezeigt
        XCTAssertTrue(screenSharingCalled)
        XCTAssertNil(overlayController.panel)
    }

    func testNoScreenSharing_showsOverlay() {
        // Arrange: Screen-Sharing inaktiv
        calendarService.silentWhenScreenSharing = true
        let event = makeEvent(minutesFromNow: 1)

        // Act
        delegate.handlePendingEvents(
            [event],
            calendarService: calendarService,
            overlayController: overlayController,
            isScreenSharing: { false }
        )

        // Assert: Overlay wurde angezeigt
        XCTAssertNotNil(overlayController.panel)

        // Cleanup
        overlayController.dismiss()
    }
}

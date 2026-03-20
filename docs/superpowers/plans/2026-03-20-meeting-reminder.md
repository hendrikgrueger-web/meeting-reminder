# Meeting Reminder — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Schlanke macOS-Menüleisten-App die an Kalender-Events erinnert und MS Teams Meetings per Klick beitreten lässt.

**Architecture:** MenuBarExtra App mit EventKit für Kalender-Zugriff, einem gezielten Timer pro nächstem Event, und einem NSPanel-basierten Vollbild-Overlay. CalendarService ist `@MainActor`-isoliert. Kein Polling — Event-basiertes Scheduling mit `EKEventStoreChangedNotification` und `didWakeNotification`.

**Tech Stack:** Swift 6, SwiftUI, EventKit, AppKit (NSPanel), macOS 26+

**Spec:** `docs/superpowers/specs/2026-03-20-meeting-reminder-design.md`

---

## File Structure

```
Meeting Reminder/
├── Meeting Reminder.xcodeproj
├── Meeting Reminder/
│   ├── MeetingReminderApp.swift          # @main, MenuBarExtra, App-Lifecycle
│   ├── Models/
│   │   └── MeetingEvent.swift            # Leichtgewichtiges Event-Model mit Teams-URL
│   ├── Services/
│   │   ├── CalendarService.swift         # EventKit, Timer, Event-Evaluation (@MainActor)
│   │   └── TeamsLinkExtractor.swift      # Regex-Patterns, HTML-Decode, URL-Extraktion
│   ├── Views/
│   │   ├── AlertOverlayView.swift        # SwiftUI Vollbild-Overlay Content
│   │   ├── OverlayPanel.swift            # NSPanel-Wrapper (AppKit)
│   │   ├── OverlayController.swift       # Zeigt/versteckt Panel, Keyboard-Events
│   │   └── SettingsView.swift            # Menüleisten-Popover (Status + Settings)
│   ├── Info.plist
│   └── Meeting_Reminder.entitlements
├── Meeting ReminderTests/
│   ├── TeamsLinkExtractorTests.swift
│   ├── MeetingEventTests.swift
│   └── CalendarServiceTests.swift
```

**Verantwortlichkeiten:**
- `MeetingEvent.swift` — Datenmodel, zusammengesetzter Key, kein EventKit-Import
- `TeamsLinkExtractor.swift` — Pure Function, alle Regex-Patterns, HTML-Decode, testbar ohne EventKit
- `CalendarService.swift` — EventKit-Zugriff, Timer-Management, Sleep/Wake, Debounce
- `OverlayPanel.swift` — NSPanel mit korrekten Flags (AppKit), kein SwiftUI
- `OverlayController.swift` — Brücke: zeigt/versteckt Panel, Keyboard-Handling, Screen-Sharing-Check
- `AlertOverlayView.swift` — Reines SwiftUI-Layout, nimmt MeetingEvent als Input
- `SettingsView.swift` — Popover-Content, Kalender-Toggles, nächstes Meeting

---

## Task 1: Xcode-Projekt erstellen

**Files:**
- Create: `Meeting Reminder.xcodeproj` (via Xcode CLI)
- Create: `Meeting Reminder/MeetingReminderApp.swift`
- Create: `Meeting Reminder/Info.plist`
- Create: `Meeting Reminder/Meeting_Reminder.entitlements`

- [ ] **Step 1: Xcode-Projekt anlegen**

```bash
cd "/Users/hendrik.grueger/Coding/1_privat/Apple Apps/Meeting Reminder"
# Manuell: Xcode > New Project > macOS > App
# Product Name: Meeting Reminder
# Team: Hendrik Grüger
# Bundle Identifier: de.hendrikgrueger.meeting-reminder
# Interface: SwiftUI
# Language: Swift
# Minimum Deployment: macOS 26.0
```

Alternativ mit `swift package init` + Xcode-Projekt generieren, aber für eine macOS App mit Entitlements ist ein reguläres Xcode-Projekt einfacher.

- [ ] **Step 2: Info.plist konfigurieren**

Folgende Keys setzen (in Xcode Target > Info):
```xml
<key>LSUIElement</key>
<true/>
<key>NSCalendarsUsageDescription</key>
<string>Meeting Reminder liest deine Kalender-Events um dich rechtzeitig an Meetings zu erinnern.</string>
```

- [ ] **Step 3: Entitlements konfigurieren**

`Meeting_Reminder.entitlements`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.personal-information.calendars</key>
    <true/>
</dict>
</plist>
```

- [ ] **Step 4: MeetingReminderApp.swift Grundgerüst**

```swift
import SwiftUI

@main
struct MeetingReminderApp: App {
    var body: some Scene {
        MenuBarExtra("Meeting Reminder", systemImage: "bell") {
            Text("Meeting Reminder läuft")
                .padding()
        }
        .menuBarExtraStyle(.window)
    }
}
```

- [ ] **Step 5: Build & Run**

Run: `Cmd+R` in Xcode
Expected: App startet, Menüleisten-Icon `bell` erscheint, Klick zeigt "Meeting Reminder läuft".

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: Xcode-Projekt mit MenuBarExtra Grundgerüst"
```

---

## Task 2: MeetingEvent Model

**Files:**
- Create: `Meeting Reminder/Models/MeetingEvent.swift`
- Create: `Meeting ReminderTests/MeetingEventTests.swift`

- [ ] **Step 1: Test schreiben**

```swift
// Meeting ReminderTests/MeetingEventTests.swift
import Testing
@testable import Meeting_Reminder

@Suite("MeetingEvent Tests")
struct MeetingEventTests {

    @Test("Zusammengesetzter Key enthält ID und Startzeit")
    func dismissKey() {
        let event = MeetingEvent(
            eventIdentifier: "ABC-123",
            title: "Standup",
            startDate: Date(timeIntervalSince1970: 1000),
            endDate: Date(timeIntervalSince1970: 2000),
            location: "Room A",
            calendarColor: .blue,
            calendarTitle: "Work",
            teamsURL: nil,
            isAllDay: false
        )
        #expect(event.id == "ABC-123_1000.0")
    }

    @Test("Ganztägige Events sind nicht meeting-relevant")
    func allDayNotRelevant() {
        let event = MeetingEvent(
            eventIdentifier: "DEF-456",
            title: "Geburtstag",
            startDate: .now,
            endDate: .now.addingTimeInterval(86400),
            location: nil,
            calendarColor: .green,
            calendarTitle: "Personal",
            teamsURL: nil,
            isAllDay: true
        )
        #expect(event.isAllDay == true)
    }

    @Test("hasTeamsLink ist true wenn teamsURL gesetzt")
    func hasTeamsLink() {
        let event = MeetingEvent(
            eventIdentifier: "GHI-789",
            title: "Sprint Review",
            startDate: .now,
            endDate: .now.addingTimeInterval(3600),
            location: nil,
            calendarColor: .blue,
            calendarTitle: "Work",
            teamsURL: URL(string: "https://teams.microsoft.com/l/meetup-join/123"),
            isAllDay: false
        )
        #expect(event.hasTeamsLink == true)
    }
}
```

- [ ] **Step 2: Test ausführen — muss fehlschlagen**

Run: `Cmd+U` in Xcode (oder `swift test`)
Expected: FAIL — `MeetingEvent` existiert nicht

- [ ] **Step 3: MeetingEvent implementieren**

```swift
// Meeting Reminder/Models/MeetingEvent.swift
import SwiftUI

struct MeetingEvent: Identifiable, Sendable {
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
```

- [ ] **Step 4: Tests ausführen — müssen bestehen**

Run: `Cmd+U`
Expected: Alle 3 Tests PASS

- [ ] **Step 5: Commit**

```bash
git add Meeting\ Reminder/Models/MeetingEvent.swift Meeting\ ReminderTests/MeetingEventTests.swift
git commit -m "feat: MeetingEvent Model mit zusammengesetztem Key für Recurring Events"
```

---

## Task 3: TeamsLinkExtractor

**Files:**
- Create: `Meeting Reminder/Services/TeamsLinkExtractor.swift`
- Create: `Meeting ReminderTests/TeamsLinkExtractorTests.swift`

- [ ] **Step 1: Tests schreiben**

```swift
// Meeting ReminderTests/TeamsLinkExtractorTests.swift
import Testing
@testable import Meeting_Reminder

@Suite("TeamsLinkExtractor Tests")
struct TeamsLinkExtractorTests {

    // MARK: - Klassisches Format

    @Test("Erkennt klassischen meetup-join Link")
    func classicLink() {
        let url = "https://teams.microsoft.com/l/meetup-join/19%3ameeting_abc123"
        let result = TeamsLinkExtractor.extractURL(
            location: url, notes: nil, url: nil
        )
        #expect(result?.absoluteString == url)
    }

    // MARK: - Neues Format

    @Test("Erkennt neues /meet/ Format")
    func newMeetFormat() {
        let url = "https://teams.microsoft.com/meet/user123?p=abc"
        let result = TeamsLinkExtractor.extractURL(
            location: url, notes: nil, url: nil
        )
        #expect(result?.absoluteString == url)
    }

    // MARK: - Government

    @Test("Erkennt GCC/Government Link")
    func governmentLink() {
        let url = "https://teams.microsoft.us/l/meetup-join/19%3ameeting_gov"
        let result = TeamsLinkExtractor.extractURL(
            location: url, notes: nil, url: nil
        )
        #expect(result?.absoluteString == url)
    }

    // MARK: - Priorität

    @Test("Location hat Priorität vor Notes")
    func locationPriority() {
        let locationURL = "https://teams.microsoft.com/meet/fromLocation"
        let notesURL = "https://teams.microsoft.com/meet/fromNotes"
        let result = TeamsLinkExtractor.extractURL(
            location: locationURL,
            notes: "Join: \(notesURL)",
            url: nil
        )
        #expect(result?.absoluteString == locationURL)
    }

    // MARK: - HTML Decode

    @Test("Dekodiert HTML Entities in Notes")
    func htmlDecode() {
        let html = """
        <a href="https://teams.microsoft.com/l/meetup-join/19%3ameeting_abc&amp;param=1">Join</a>
        """
        let result = TeamsLinkExtractor.extractURL(
            location: nil, notes: html, url: nil
        )
        #expect(result != nil)
        #expect(result?.absoluteString.contains("&param=1") == true)
    }

    // MARK: - Kein Link

    @Test("Gibt nil zurück wenn kein Teams-Link vorhanden")
    func noLink() {
        let result = TeamsLinkExtractor.extractURL(
            location: "Room 42", notes: "Agenda: Budget Review", url: nil
        )
        #expect(result == nil)
    }

    // MARK: - URL-Feld

    @Test("Erkennt Teams-URL im url-Feld als Fallback")
    func urlFieldFallback() {
        let url = URL(string: "https://teams.microsoft.com/l/meetup-join/test123")!
        let result = TeamsLinkExtractor.extractURL(
            location: nil, notes: nil, url: url
        )
        #expect(result == url)
    }

    // MARK: - Consumer

    @Test("Erkennt teams.live.com Link")
    func consumerLink() {
        let url = "https://teams.live.com/meet/abc123"
        let result = TeamsLinkExtractor.extractURL(
            location: url, notes: nil, url: nil
        )
        #expect(result?.absoluteString == url)
    }
}
```

- [ ] **Step 2: Test ausführen — muss fehlschlagen**

Run: `Cmd+U`
Expected: FAIL — `TeamsLinkExtractor` existiert nicht

- [ ] **Step 3: TeamsLinkExtractor implementieren**

```swift
// Meeting Reminder/Services/TeamsLinkExtractor.swift
import Foundation

enum TeamsLinkExtractor {

    // MARK: - Patterns

    private static let patterns: [NSRegularExpression] = {
        let raw = [
            #"https://teams\.microsoft\.com/l/meetup-join/[^\s"<>]+"#,
            #"https://teams\.microsoft\.com/meet/[^\s"<>]+"#,
            #"https://teams\.microsoft\.us/l/meetup-join/[^\s"<>]+"#,
            #"https://dod\.teams\.microsoft\.us/l/meetup-join/[^\s"<>]+"#,
            #"https://teams\.live\.com/meet/[^\s"<>]+"#,
        ]
        return raw.compactMap { try? NSRegularExpression(pattern: $0, options: [.caseInsensitive]) }
    }()

    private static let teamsHosts: Set<String> = [
        "teams.microsoft.com",
        "teams.microsoft.us",
        "dod.teams.microsoft.us",
        "teams.live.com",
    ]

    // MARK: - Public API

    /// Extrahiert den Teams-Link aus Event-Feldern.
    /// Priorität: location → notes → url
    static func extractURL(location: String?, notes: String?, url: URL?) -> URL? {
        // 1. Location (häufigster Ort für Teams-Link bei Outlook/Exchange)
        if let location, let found = matchTeamsURL(in: location) {
            return found
        }

        // 2. Notes (HTML-Body, Decode nötig)
        if let notes {
            let decoded = decodeHTMLEntities(notes)
            if let found = matchTeamsURL(in: decoded) {
                return found
            }
        }

        // 3. URL-Feld (bereits URL, direkter Host-Check)
        if let url, let host = url.host?.lowercased(), teamsHosts.contains(host) {
            return url
        }

        return nil
    }

    // MARK: - Private

    private static func matchTeamsURL(in text: String) -> URL? {
        let range = NSRange(text.startIndex..., in: text)
        for pattern in patterns {
            if let match = pattern.firstMatch(in: text, range: range) {
                let matchRange = Range(match.range, in: text)!
                let urlString = String(text[matchRange])
                return URL(string: urlString)
            }
        }
        return nil
    }

    private static func decodeHTMLEntities(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
    }
}
```

- [ ] **Step 4: Tests ausführen — müssen bestehen**

Run: `Cmd+U`
Expected: Alle 8 Tests PASS

- [ ] **Step 5: Commit**

```bash
git add Meeting\ Reminder/Services/TeamsLinkExtractor.swift Meeting\ ReminderTests/TeamsLinkExtractorTests.swift
git commit -m "feat: TeamsLinkExtractor mit 5 URL-Patterns und HTML-Decode"
```

---

## Task 4: OverlayPanel (NSPanel-Wrapper)

**Files:**
- Create: `Meeting Reminder/Views/OverlayPanel.swift`

- [ ] **Step 1: NSPanel-Wrapper implementieren**

```swift
// Meeting Reminder/Views/OverlayPanel.swift
import AppKit
import SwiftUI

final class OverlayPanel: NSPanel {

    init(contentView: NSView, screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.level = .screenSaver
        self.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
        ]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.ignoresMouseEvents = false
        self.hidesOnDeactivate = false
        self.isFloatingPanel = true

        self.contentView = contentView
    }

    // Key-Events für Shortcuts empfangen
    override var canBecomeKey: Bool { true }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 53:  // Escape
            NotificationCenter.default.post(name: .overlayDismiss, object: nil)
        case 36:  // Return/Enter
            NotificationCenter.default.post(name: .overlayJoin, object: nil)
        case 49:  // Space
            NotificationCenter.default.post(name: .overlaySnooze, object: nil)
        default:
            super.keyDown(with: event)
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let overlayDismiss = Notification.Name("overlayDismiss")
    static let overlayJoin = Notification.Name("overlayJoin")
    static let overlaySnooze = Notification.Name("overlaySnooze")
}
```

- [ ] **Step 2: Build prüfen**

Run: `Cmd+B`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add Meeting\ Reminder/Views/OverlayPanel.swift
git commit -m "feat: OverlayPanel NSPanel-Wrapper mit Keyboard Shortcuts"
```

---

## Task 5: OverlayController

**Files:**
- Create: `Meeting Reminder/Views/OverlayController.swift`

- [ ] **Step 1: Controller implementieren**

```swift
// Meeting Reminder/Views/OverlayController.swift
import AppKit
import SwiftUI

@MainActor
final class OverlayController: ObservableObject {

    private var panel: OverlayPanel?
    @Published var isVisible = false

    func show(content: some View) {
        guard let screen = NSScreen.main else { return }

        let hostingView = NSHostingView(rootView: content)
        hostingView.frame = screen.frame

        let newPanel = OverlayPanel(contentView: hostingView, screen: screen)
        newPanel.makeKeyAndOrderFront(nil)

        self.panel = newPanel
        self.isVisible = true
    }

    func dismiss() {
        panel?.close()
        panel = nil
        isVisible = false
    }

    /// Prüft ob Screen Sharing aktiv ist (bekannte Capture-Prozesse)
    static func isScreenSharing() -> Bool {
        let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
        // Prozessnamen (kCGWindowOwnerName liefert Prozessnamen, keine Bundle-IDs)
        let captureProcesses: Set<String> = [
            "CaptureAgent", "screensharingd", "Screen Sharing",
            "Bildschirmfreigabe",
        ]
        return windowList.contains { info in
            guard let name = info[kCGWindowOwnerName as String] as? String else { return false }
            return captureProcesses.contains(name)
        }
    }
}
```

- [ ] **Step 2: Build prüfen**

Run: `Cmd+B`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add Meeting\ Reminder/Views/OverlayController.swift
git commit -m "feat: OverlayController mit Screen-Sharing-Erkennung"
```

---

## Task 6: AlertOverlayView (SwiftUI)

**Files:**
- Create: `Meeting Reminder/Views/AlertOverlayView.swift`

- [ ] **Step 1: Overlay-View implementieren**

```swift
// Meeting Reminder/Views/AlertOverlayView.swift
import SwiftUI

struct AlertOverlayView: View {
    let event: MeetingEvent
    let onJoin: () -> Void
    let onDismiss: () -> Void
    let onSnooze: () -> Void

    @State private var now = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // Dimmed Background
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            // Content Card mit Liquid Glass (macOS 26)
            VStack(spacing: 20) {
                // Uhrzeit oben rechts
                HStack {
                    Spacer()
                    Text(now, style: .time)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Kalenderfarbe + Titel
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(event.calendarColor)
                        .frame(width: 4, height: 28)
                    Text(event.title)
                        .font(.system(size: 28, weight: .bold))
                        .accessibilityAddTraits(.isHeader)
                }

                // Zeitraum
                Text("\(event.startDate.formatted(date: .omitted, time: .shortened)) – \(event.endDate.formatted(date: .omitted, time: .shortened))")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                // Countdown
                countdownText
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .accessibilityAddTraits(.updatesFrequently)

                // Ort
                if let location = event.location, !location.isEmpty,
                   !location.contains("teams.microsoft") {
                    Text(location)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }

                Spacer()

                // Buttons
                VStack(spacing: 10) {
                    if event.hasTeamsLink {
                        Button(action: onJoin) {
                            Label("Beitreten", systemImage: "video")
                                .frame(width: 220)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.indigo)
                        .controlSize(.large)
                        .accessibilityLabel("Beitreten via Microsoft Teams")
                        .accessibilityHint("Öffnet den Teams-Link")
                    } else {
                        Label("Kein Einwahllink vorhanden", systemImage: "exclamationmark.triangle")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                    }

                    Button(action: onDismiss) {
                        Text("Schließen")
                            .frame(width: 220)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .accessibilityLabel("Erinnerung schließen")
                }

                // Snooze
                VStack(spacing: 6) {
                    Text("Später erinnern")
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    Button(action: onSnooze) {
                        Text("1 Minute")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .accessibilityLabel("In einer Minute erneut erinnern")
                }
                .padding(.top, 8)

                Spacer()
            }
            .padding(40)
            .frame(maxWidth: 500)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
            .shadow(color: .black.opacity(0.15), radius: 20, y: 8)
        }
        .onReceive(timer) { self.now = $0 }
    }

    private var countdownText: Text {
        let interval = event.startDate.timeIntervalSince(now)
        if interval > 60 {
            let minutes = Int(interval / 60)
            return Text("Das Ereignis beginnt in \(minutes) Min.")
        } else if interval > 0 {
            let seconds = Int(interval)
            return Text("Das Ereignis beginnt in \(seconds) Sek.")
        } else {
            let minutesAgo = Int(-interval / 60)
            return Text("Meeting läuft seit \(max(1, minutesAgo)) Min.")
        }
    }
}
```

- [ ] **Step 2: Build prüfen**

Run: `Cmd+B`
Expected: Build succeeds

- [ ] **Step 3: Preview testen**

Xcode Preview mit Mock-Daten prüfen. In der Datei einen `#Preview` Block ergänzen:

```swift
#Preview {
    AlertOverlayView(
        event: MeetingEvent(
            eventIdentifier: "preview",
            title: "Sprint Planning",
            startDate: Date().addingTimeInterval(50),
            endDate: Date().addingTimeInterval(3650),
            location: "Conference Room A",
            calendarColor: .blue,
            calendarTitle: "Work",
            teamsURL: URL(string: "https://teams.microsoft.com/l/meetup-join/test"),
            isAllDay: false
        ),
        onJoin: {},
        onDismiss: {},
        onSnooze: {}
    )
}
```

- [ ] **Step 4: Commit**

```bash
git add Meeting\ Reminder/Views/AlertOverlayView.swift
git commit -m "feat: AlertOverlayView mit Countdown, Buttons und Accessibility"
```

---

## Task 7: CalendarService

**Files:**
- Create: `Meeting Reminder/Services/CalendarService.swift`

- [ ] **Step 1: CalendarService implementieren**

```swift
// Meeting Reminder/Services/CalendarService.swift
import EventKit
import SwiftUI
import Combine

@MainActor
final class CalendarService: ObservableObject {

    // MARK: - Published State

    @Published var accessGranted = false
    @Published var calendars: [EKCalendar] = []
    @Published var nextEvent: MeetingEvent?
    @Published var pendingEvents: [MeetingEvent] = []

    // MARK: - Settings (UserDefaults backed, mit onChange-Reaktivität)

    @AppStorage("enabledCalendarIDs") private var enabledCalendarIDsData: Data = Data()
    @AppStorage("soundEnabled") var soundEnabled: Bool = false
    @AppStorage("silentWhenScreenSharing") var silentWhenScreenSharing: Bool = true
    @AppStorage("hasLaunchedBefore") var hasLaunchedBefore: Bool = false

    // Diese Settings lösen reloadAndReschedule() aus wenn sie sich ändern
    @Published var leadTimeMinutes: Int = UserDefaults.standard.integer(forKey: "leadTimeMinutes").clamped(or: 1) {
        didSet {
            UserDefaults.standard.set(leadTimeMinutes, forKey: "leadTimeMinutes")
            reloadAndReschedule()
        }
    }
    @Published var onlyOnlineMeetings: Bool = UserDefaults.standard.bool(forKey: "onlyOnlineMeetings") {
        didSet {
            UserDefaults.standard.set(onlyOnlineMeetings, forKey: "onlyOnlineMeetings")
            reloadAndReschedule()
        }
    }

    // MARK: - Private

    private let eventStore = EKEventStore()
    private var alertTimer: Timer?
    private var fallbackTimer: Timer?
    private var debounceTask: Task<Void, Never>?
    private var dismissedEvents: Set<String> = []
    private var defaultObservers: [Any] = []
    private var workspaceObservers: [Any] = []

    // MARK: - Enabled Calendar IDs

    var enabledCalendarIDs: Set<String> {
        get {
            guard let ids = try? JSONDecoder().decode(Set<String>.self, from: enabledCalendarIDsData) else {
                return Set(calendars.map(\.calendarIdentifier))
            }
            return ids
        }
        set {
            enabledCalendarIDsData = (try? JSONEncoder().encode(newValue)) ?? Data()
            reloadAndReschedule()
        }
    }

    // MARK: - Lifecycle

    func start() async {
        // 1. Berechtigung anfragen
        do {
            accessGranted = try await eventStore.requestFullAccessToEvents()
        } catch {
            accessGranted = false
        }

        guard accessGranted else { return }

        // 2. Kalender laden
        calendars = eventStore.calendars(for: .event)

        // 3. Notifications abonnieren
        let storeObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: eventStore,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleStoreChanged()
            }
        }
        defaultObservers.append(storeObserver)

        let wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.reloadAndReschedule()
            }
        }
        workspaceObservers.append(wakeObserver)

        let sleepObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.alertTimer?.invalidate()
            }
        }
        workspaceObservers.append(sleepObserver)

        // 4. Fallback-Timer (alle 30 Min)
        fallbackTimer = Timer.scheduledTimer(withTimeInterval: 30 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.reloadAndReschedule()
            }
        }

        // 5. Erste Berechnung
        reloadAndReschedule()
    }

    deinit {
        alertTimer?.invalidate()
        fallbackTimer?.invalidate()
        for observer in defaultObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        for observer in workspaceObservers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }

    // MARK: - Event Loading

    func reloadAndReschedule() {
        guard accessGranted else { return }

        // Kalender aktualisieren
        calendars = eventStore.calendars(for: .event)

        // Dismissed-Set aufräumen
        cleanupDismissed()

        // Events laden (24h-Fenster)
        let now = Date()
        let events = loadRelevantEvents(from: now)

        // Nächstes Event für Status-Anzeige
        nextEvent = events.first

        // Prüfen ob ein Meeting JETZT läuft (nach Wake)
        let runningEvents = events.filter { $0.startDate <= now && !dismissedEvents.contains($0.id) }
        if !runningEvents.isEmpty {
            pendingEvents = runningEvents
            return
        }

        // Timer auf nächstes Event setzen
        scheduleTimer(for: events, from: now)
    }

    private func loadRelevantEvents(from now: Date) -> [MeetingEvent] {
        let startDate = now.addingTimeInterval(-5 * 60) // 5 Min zurück
        let endDate = Calendar.current.date(byAdding: .hour, value: 24, to: now)!

        let enabledIDs = enabledCalendarIDs
        let selectedCalendars = calendars.filter { enabledIDs.contains($0.calendarIdentifier) }

        guard !selectedCalendars.isEmpty else { return [] }

        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: selectedCalendars
        )

        return eventStore.events(matching: predicate)
            .compactMap { mapToMeetingEvent($0) }
            .filter { isRelevant($0, now: now) }
            .sorted { a, b in
                // Gleiche Startzeit: Teams-Link-Events zuerst
                if a.startDate == b.startDate {
                    if a.hasTeamsLink != b.hasTeamsLink { return a.hasTeamsLink }
                    return a.calendarTitle < b.calendarTitle
                }
                return a.startDate < b.startDate
            }
    }

    private func mapToMeetingEvent(_ event: EKEvent) -> MeetingEvent? {
        guard !event.isAllDay else { return nil }

        let teamsURL = TeamsLinkExtractor.extractURL(
            location: event.location,
            notes: event.notes,
            url: event.url
        )

        return MeetingEvent(
            eventIdentifier: event.eventIdentifier ?? UUID().uuidString,
            title: event.title ?? "Ohne Titel",
            startDate: event.startDate,
            endDate: event.endDate,
            location: event.location,
            calendarColor: Color(cgColor: event.calendar.cgColor),
            calendarTitle: event.calendar.title,
            teamsURL: teamsURL,
            isAllDay: event.isAllDay
        )
    }

    private func isRelevant(_ event: MeetingEvent, now: Date) -> Bool {
        // Ganztägig ausschließen
        guard !event.isAllDay else { return false }

        // Nur Online-Meetings?
        if onlyOnlineMeetings && !event.hasTeamsLink { return false }

        // Bereits dismissed?
        if dismissedEvents.contains(event.id) { return false }

        // In der Zukunft oder max 5 Min nach Start
        let timeSinceStart = now.timeIntervalSince(event.startDate)
        if timeSinceStart > 5 * 60 { return false }

        return true
    }

    // MARK: - Timer

    private func scheduleTimer(for events: [MeetingEvent], from now: Date) {
        alertTimer?.invalidate()

        guard let nextEvent = events.first(where: { $0.startDate > now }) else { return }

        let leadTime = TimeInterval(leadTimeMinutes * 60)
        let fireDate = nextEvent.startDate.addingTimeInterval(-leadTime)

        guard fireDate > now else {
            // Event ist bereits im Vorlauf-Fenster
            pendingEvents = [nextEvent]
            return
        }

        alertTimer = Timer.scheduledTimer(
            withTimeInterval: fireDate.timeIntervalSince(now),
            repeats: false
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.reloadAndReschedule()
            }
        }
    }

    // MARK: - Dismiss/Snooze

    func dismissEvent(_ event: MeetingEvent) {
        dismissedEvents.insert(event.id)
        pendingEvents.removeAll { $0.id == event.id }

        if pendingEvents.isEmpty {
            reloadAndReschedule()
        }
    }

    func snoozeEvent(_ event: MeetingEvent) {
        pendingEvents.removeAll { $0.id == event.id }

        // Snooze-Timer: 1 Minute
        Timer.scheduledTimer(withTimeInterval: 60, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let now = Date()
                let timeSinceStart = now.timeIntervalSince(event.startDate)
                // Nur erneut anzeigen wenn < 5 Min seit Start
                if timeSinceStart < 5 * 60 && !self.dismissedEvents.contains(event.id) {
                    self.pendingEvents.append(event)
                }
            }
        }

        if pendingEvents.isEmpty {
            reloadAndReschedule()
        }
    }

    // MARK: - Helpers

    private func handleStoreChanged() {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            reloadAndReschedule()
        }
    }

    private func cleanupDismissed() {
        let now = Date()
        dismissedEvents = dismissedEvents.filter { key in
            guard let timestampString = key.split(separator: "_").last,
                  let timestamp = Double(timestampString) else { return false }
            // Behalte für 2h nach Start (konservativ)
            return Date(timeIntervalSince1970: timestamp).addingTimeInterval(2 * 3600) > now
        }
    }
}
```

- [ ] **Step 2: Build prüfen**

Run: `Cmd+B`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add Meeting\ Reminder/Services/CalendarService.swift
git commit -m "feat: CalendarService mit EventKit, Debounce, Sleep/Wake, Fallback-Timer"
```

---

## Task 8: SettingsView

**Files:**
- Create: `Meeting Reminder/Views/SettingsView.swift`

- [ ] **Step 1: SettingsView implementieren**

```swift
// Meeting Reminder/Views/SettingsView.swift
import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var calendarService: CalendarService

    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Status: Nächstes Meeting
            statusSection

            Divider().padding(.vertical, 8)

            // Settings
            settingsSection

            Divider().padding(.vertical, 8)

            // App-Info
            HStack {
                Text("Meeting Reminder")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
                Button("Beenden") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .foregroundStyle(.red)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .frame(width: 320)
    }

    // MARK: - Status

    @ViewBuilder
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !calendarService.accessGranted {
                Label("Kalender-Zugriff benötigt", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .font(.subheadline)
                Button("Systemeinstellungen öffnen") {
                    NSWorkspace.shared.open(
                        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!
                    )
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else if calendarService.calendars.isEmpty {
                Label("Keine Kalender gefunden", systemImage: "calendar.badge.exclamationmark")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            } else if let next = calendarService.nextEvent {
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(next.calendarColor)
                        .frame(width: 3, height: 18)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(next.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        Text(next.startDate.formatted(date: .omitted, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("Keine anstehenden Meetings")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Settings

    @ViewBuilder
    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Kalender-Auswahl
            if !calendarService.calendars.isEmpty {
                Text("Kalender")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)

                ForEach(calendarService.calendars, id: \.calendarIdentifier) { calendar in
                    let isEnabled = calendarService.enabledCalendarIDs.contains(calendar.calendarIdentifier)
                    Toggle(isOn: Binding(
                        get: { isEnabled },
                        set: { enabled in
                            var ids = calendarService.enabledCalendarIDs
                            if enabled { ids.insert(calendar.calendarIdentifier) }
                            else { ids.remove(calendar.calendarIdentifier) }
                            calendarService.enabledCalendarIDs = ids
                        }
                    )) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color(cgColor: calendar.cgColor))
                                .frame(width: 8, height: 8)
                            Text(calendar.title)
                                .font(.subheadline)
                        }
                    }
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .padding(.horizontal, 16)
                }
            }

            Divider().padding(.vertical, 4)

            // Vorlaufzeit
            Picker("Vorlaufzeit", selection: $calendarService.leadTimeMinutes) {
                Text("1 Min").tag(1)
                Text("2 Min").tag(2)
                Text("3 Min").tag(3)
                Text("5 Min").tag(5)
            }
            .pickerStyle(.menu)
            .font(.subheadline)
            .padding(.horizontal, 16)

            // Toggles
            Toggle("Nur Online-Meetings", isOn: $calendarService.onlyOnlineMeetings)
                .font(.subheadline)
                .toggleStyle(.switch)
                .controlSize(.small)
                .padding(.horizontal, 16)

            Toggle("Bei Bildschirmfreigabe: nur Notification", isOn: $calendarService.silentWhenScreenSharing)
                .font(.subheadline)
                .toggleStyle(.switch)
                .controlSize(.small)
                .padding(.horizontal, 16)

            Toggle("Sound", isOn: $calendarService.soundEnabled)
                .font(.subheadline)
                .toggleStyle(.switch)
                .controlSize(.small)
                .padding(.horizontal, 16)

            Toggle("Bei Anmeldung starten", isOn: $launchAtLogin)
                .font(.subheadline)
                .toggleStyle(.switch)
                .controlSize(.small)
                .padding(.horizontal, 16)
                .onChange(of: launchAtLogin) { _, newValue in
                    do {
                        if newValue {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch {
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }
                }

            if SMAppService.mainApp.status == .requiresApproval {
                Label("Login Item in Systemeinstellungen aktivieren", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 16)
                Button("Systemeinstellungen öffnen") {
                    NSWorkspace.shared.open(
                        URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension")!
                    )
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .padding(.horizontal, 16)
            }
        }
    }
}
```

- [ ] **Step 2: Build prüfen**

Run: `Cmd+B`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add Meeting\ Reminder/Views/SettingsView.swift
git commit -m "feat: SettingsView mit Status-Anzeige, Kalender-Toggles und Login Item"
```

---

## Task 9+10 (zusammengelegt): App zusammenbauen — vollständiger Alert-Flow: Integration — Alert-Flow verdrahten

**Files:**
- Modify: `Meeting Reminder/MeetingReminderApp.swift`

- [ ] **Step 1: App mit vollständigem Alert-Flow**

```swift
// Meeting Reminder/MeetingReminderApp.swift
import SwiftUI
import UserNotifications
import AppKit

@main
struct MeetingReminderApp: App {

    @StateObject private var calendarService = CalendarService()
    @StateObject private var overlayController = OverlayController()

    var body: some Scene {
        MenuBarExtra {
            SettingsView(calendarService: calendarService)
        } label: {
            Image(systemName: menuBarIcon)
        }
        .menuBarExtraStyle(.window)
        .onChange(of: calendarService.pendingEvents) { _, events in
            handlePendingEvents(events)
        }
        .task {
            await calendarService.start()
            // Erster Start: Popover öffnet sich automatisch via MenuBarExtra
            if !calendarService.hasLaunchedBefore {
                calendarService.hasLaunchedBefore = true
            }
            // Notification-Berechtigung für Screen-Sharing-Fallback
            try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
            // Keyboard-Shortcut Notifications
            setupKeyboardNotifications()
        }
    }

    // MARK: - Alert Flow

    private func handlePendingEvents(_ events: [MeetingEvent]) {
        guard let event = events.first else {
            overlayController.dismiss()
            return
        }

        // Screen-Sharing aktiv + Setting an → System-Notification statt Overlay
        if calendarService.silentWhenScreenSharing && OverlayController.isScreenSharing() {
            sendSystemNotification(for: event)
            calendarService.dismissEvent(event)
            return
        }

        // Sound abspielen
        if calendarService.soundEnabled {
            NSSound(named: .init("Funk"))?.play()
        }

        // Overlay anzeigen
        let overlayView = AlertOverlayView(
            event: event,
            onJoin: { [weak calendarService, weak overlayController] in
                if let url = event.teamsURL {
                    NSWorkspace.shared.open(url)
                }
                overlayController?.dismiss()
                calendarService?.dismissEvent(event)
            },
            onDismiss: { [weak calendarService, weak overlayController] in
                overlayController?.dismiss()
                calendarService?.dismissEvent(event)
            },
            onSnooze: { [weak calendarService, weak overlayController] in
                overlayController?.dismiss()
                calendarService?.snoozeEvent(event)
            }
        )

        overlayController.show(content: overlayView)

        // Accessibility: Overlay erscheint
        if let panel = overlayController.panel {
            NSAccessibility.post(element: panel, notification: .layoutChanged)
        }
    }

    // MARK: - Keyboard Shortcuts

    private func setupKeyboardNotifications() {
        NotificationCenter.default.addObserver(
            forName: .overlayDismiss, object: nil, queue: .main
        ) { _ in
            guard let event = calendarService.pendingEvents.first else { return }
            overlayController.dismiss()
            calendarService.dismissEvent(event)
        }

        NotificationCenter.default.addObserver(
            forName: .overlayJoin, object: nil, queue: .main
        ) { _ in
            guard let event = calendarService.pendingEvents.first else { return }
            if let url = event.teamsURL {
                NSWorkspace.shared.open(url)
            }
            overlayController.dismiss()
            calendarService.dismissEvent(event)
        }

        NotificationCenter.default.addObserver(
            forName: .overlaySnooze, object: nil, queue: .main
        ) { _ in
            guard let event = calendarService.pendingEvents.first else { return }
            overlayController.dismiss()
            calendarService.snoozeEvent(event)
        }
    }

    // MARK: - System Notification (Screen-Sharing Fallback)

    private func sendSystemNotification(for event: MeetingEvent) {
        let content = UNMutableNotificationContent()
        content.title = event.title
        content.body = event.hasTeamsLink
            ? "Meeting beginnt gleich — Klicke zum Beitreten"
            : "Meeting beginnt gleich"
        content.sound = calendarService.soundEnabled ? .default : nil
        content.categoryIdentifier = "MEETING_ALERT"

        let request = UNNotificationRequest(
            identifier: event.id,
            content: content,
            trigger: nil // Sofort
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Menu Bar Icon

    private var menuBarIcon: String {
        if !calendarService.accessGranted {
            return "bell.slash"
        } else if let next = calendarService.nextEvent,
                  next.startDate.timeIntervalSinceNow < 15 * 60 {
            return "bell.badge"
        } else {
            return "bell"
        }
    }
}
```

- [ ] **Step 2: OverlayController — panel als public property**

In `OverlayController.swift` das `panel` Property auf `private(set)` ändern:
```swift
private(set) var panel: OverlayPanel?
```

- [ ] **Step 3: CalendarService — Event-Löschung erkennen**

In `CalendarService.reloadAndReschedule()` nach dem Event-Laden prüfen ob pending Events noch existieren:
```swift
// In reloadAndReschedule(), nach loadRelevantEvents():
// Pending Events bereinigen — gelöschte Events entfernen
let validIDs = Set(events.map(\.id))
pendingEvents.removeAll { !validIDs.contains($0.id) }
```

- [ ] **Step 4: Manuell testen**

1. App starten
2. In Apple Kalender ein Test-Event in 2 Minuten erstellen mit Teams-Link als Ort
3. Warten → Overlay sollte 1 Min vorher erscheinen
4. "Beitreten" klicken → Teams öffnet sich
5. Escape drücken → Overlay schließt
6. Space drücken → Snooze, Overlay kommt nach 1 Min wieder
7. Event löschen während Overlay angezeigt wird → Overlay schließt automatisch

- [ ] **Step 5: Commit**

```bash
git add Meeting\ Reminder/MeetingReminderApp.swift Meeting\ Reminder/Views/OverlayController.swift Meeting\ Reminder/Services/CalendarService.swift
git commit -m "feat: Alert-Flow mit Overlay, Keyboard, Sound, Screen-Sharing-Fallback, Event-Löschung"
```

---

## Task 11: Abschluss und CLAUDE.md

**Files:**
- Create: `CLAUDE.md`

- [ ] **Step 1: CLAUDE.md erstellen**

Projekt-CLAUDE.md mit Tech-Details, Build-Anweisungen, Architektur-Übersicht.

- [ ] **Step 2: Finaler Build & Test**

Run: `Cmd+B` (Build) + `Cmd+U` (Tests) + `Cmd+R` (Run)
Expected: Alles grün, App läuft korrekt.

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: CLAUDE.md für Meeting Reminder Projekt"
```

---

## Hilfscode

`Int.clamped(or:)` wird in CalendarService benötigt. In `MeetingEvent.swift` ergänzen:

```swift
extension Int {
    static func clamped(or defaultValue: Int) -> (Int) -> Int {
        { value in value > 0 ? value : defaultValue }
    }
}

// Nutzung: UserDefaults.standard.integer(forKey: "leadTimeMinutes").clamped(or: 1)
// Vereinfachte Variante direkt im CalendarService:
// let raw = UserDefaults.standard.integer(forKey: "leadTimeMinutes")
// leadTimeMinutes = raw > 0 ? raw : 1
```

---

## Task-Abhängigkeiten

```
Task 1 (Xcode-Projekt) ─┐
                         ├→ Task 2 (MeetingEvent) ─┐
                         ├→ Task 3 (TeamsLink)      ├→ Task 7 (CalendarService) ─┐
                         ├→ Task 4 (OverlayPanel)   │                            │
                         ├→ Task 5 (OverlayCtrl)    │                            │
                         └→ Task 6 (AlertOverlay)   │                            │
                                                    └→ Task 8 (SettingsView) ────┤
                                                                                 ├→ Task 9+10 (App + Integration)
                                                                                 └→ Task 11 (CLAUDE.md)
```

**Parallelisierbar:** Tasks 2, 3, 4, 5, 6 können parallel entwickelt werden (nach Task 1).

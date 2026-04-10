# AGENTS.md — Nevr Late (Meeting Reminder)

> Zuletzt aktualisiert: 2026-04-10

## Projektübersicht

**Nevr Late** — Schlanke macOS-Menüleisten-App (Bundle ID: `de.hendrikgrueger.nevrlate`), die an bevorstehende Kalender-Events erinnert und das Beitreten zu Online-Meetings per Klick ermöglicht. Unterstützt 8 Meeting-Provider (Teams, Zoom, Google Meet, WebEx, GoTo, Slack, Whereby, Jitsi). Vollbild-Overlay mit konfigurierbarer Vorlaufzeit, Screen-Sharing-Schutz, Sleep/Wake-Handling und globalem Keyboard-Shortcut. Komplett kostenlos.

**Dokumentation:**
- `docs/superpowers/specs/2026-03-20-meeting-reminder-design.md` (Design Spec)
- `docs/superpowers/specs/2026-03-22-app-store-launch-design.md` (App Store Launch Spec)
- `docs/app-store-listing.md` (App Store Texte EN + DE)

## Tech Stack

| Bereich | Technologie |
|---------|-------------|
| Sprache | Swift 6 |
| UI | SwiftUI |
| Kalender-API | EventKit (EKEventStore) |
| Overlay | NSPanel (AppKit-Bridge) |
| Persistenz | UserDefaults |
| Testing | Swift Testing + XCTest (153 Tests) |
| Sound | NSSound (Systemtöne) |
| Autostart | SMAppService (macOS Login Item API) |
| Minimum | macOS 26+ (Tahoe) |
| Concurrency | @MainActor auf CalendarService |
| App Intents | AppIntents Framework (Siri / Shortcuts / Spotlight) |

## Architektur

**11 Swift-Dateien | 4 Test-Dateien | 153 Tests**

### Quellcode-Struktur

```
Meeting Reminder/
├── MeetingReminderApp.swift           # @main, MenuBarExtra, App-Lifecycle, Globaler Shortcut, HeadsetClockMark Icon
├── AppIntents.swift                   # Siri / Shortcuts / Spotlight Integration (JoinNextMeetingIntent)
├── Models/
│   ├── MeetingEvent.swift             # Event-Model mit zusammengesetztem Key + MeetingLink
│   └── MeetingProvider.swift          # 8 Meeting-Provider (enum) + MeetingLink (struct)
├── Services/
│   ├── CalendarService.swift          # EventKit, Timer, Tagesübersicht (@MainActor)
│   └── MeetingLinkExtractor.swift     # Multi-Provider URL-Erkennung + Deep-Links
├── Views/
│   ├── AlertOverlayView.swift         # Vollbild-Overlay: Countdown, LIVE Badge, Liquid Glass
│   ├── OverlayController.swift        # NSPanel Lifecycle + Screen-Sharing-Erkennung
│   ├── OverlayPanel.swift             # NSPanel-Konfiguration + Keyboard Shortcuts
│   ├── SettingsView.swift             # Popover: Status, Kalender, Einstellungen
│   └── TodayMeetingsView.swift        # Tagesübersicht aller Meetings im Popover
└── Info.plist                         # LSUIElement=true, NSCalendarsUsageDescription
```

### Meeting-Link-Erkennung (8 Provider)

`MeetingLinkExtractor` erkennt URLs aus 8 Providern mit Regex-Patterns:

| Provider | Patterns | Deep-Link |
|----------|----------|-----------|
| Microsoft Teams | 5 Patterns (meetup-join, /meet/, GCC, DoD, Live) | `msteams://` |
| Zoom | /j/, /my/, /s/ + regionale Subdomains (us02web, eu01web, ...) | `zoommtg://` |
| Google Meet | meet.google.com/* | Browser |
| WebEx/Cisco | /meet/, /join/, j.php + Subdomains | `webex://` |
| GoTo Meeting | gotomeet.me, gotomeeting.com/join, meet.goto.com | `gotomeeting://` |
| Slack Huddle | app.slack.com/huddle/ | Browser |
| Whereby | whereby.com/* | Browser |
| Jitsi Meet | meet.jit.si/* | Browser |

Suchpriorität: `location` → `notes` (HTML-decoded) → `url`. Ergebnis wird als `MeetingLink` in MeetingEvent gecacht.

### MeetingEvent-Model

```swift
struct MeetingEvent: Identifiable, Sendable, Equatable {
    let eventIdentifier: String
    let title: String
    let startDate: Date
    let endDate: Date
    let location: String?
    let calendarColor: Color
    let calendarTitle: String
    let meetingLink: MeetingLink?    // Provider + URL
    let isAllDay: Bool

    var id: String                   // eventIdentifier + startDate (zusammengesetzter Key)
    var hasMeetingLink: Bool
    var meetingProvider: MeetingProvider?
    var meetingURL: URL?
}
```

### CalendarService (@MainActor)

- **EventKit Integration:** 24h-Fenster Event-Abfrage
- **Tagesübersicht:** todayEvents (Mitternacht bis Mitternacht)
- **Timer-Management:** Ein gezielter Timer pro nächstes relevantes Event (kein Polling)
- **Debounce:** `EKEventStoreChangedNotification` mit 500ms Debounce
- **Fallback-Check:** Alle 30 Min Events neu laden
- **Sleep/Wake-Handling:** verpasste Meetings nach Aufwachen erkennen
- **Screen-Sharing-Erkennung:** CGWindowList auf Capture-Prozesse
- **Upcoming-Count:** upcomingEventsCount für Menüleisten-Badge

## Berechtigungen (Minimal)

| Entitlement | Zweck |
|---|---|
| `com.apple.security.personal-information.calendars` | Kalender lesen |
| `com.apple.security.app-sandbox` | App Sandbox |
| `com.apple.security.network.client` | Deep-Link-Öffnung (msteams://, zoommtg://, etc.) |
| `LSUIElement = true` | Menüleisten-App (kein Dock-Icon) |

## Build & Run

```bash
cd "/Users/hendrik.grueger/Coding/1_privat/Apple Apps/Meeting Reminder"
xcodegen generate
xcodebuild build -project NevLate.xcodeproj -scheme NevLate \
  -destination "platform=macOS" -derivedDataPath ./build \
  CODE_SIGN_IDENTITY="Apple Development: Hendrik Grueger (HY44A7L7D7)" DEVELOPMENT_TEAM=CU87QNNB3N
```

## Tests

```bash
xcodebuild test -project NevLate.xcodeproj -scheme NevLate \
  -destination "platform=macOS" -derivedDataPath ./build \
  CODE_SIGN_IDENTITY="Apple Development: Hendrik Grueger (HY44A7L7D7)" DEVELOPMENT_TEAM=CU87QNNB3N
```

**4 Test-Dateien | 153 Tests:**
- `MeetingLinkExtractorTests` (117 Tests): Alle 8 Provider, Deep-Links, HTML-Decode, Edge Cases
- `CalendarServiceTests` (36 Tests): Event-Relevanz, Dismissed-Cleanup, Sortierung, Grenzfälle
- `MeetingEventTests` (27 Tests): Model, Equatable, Provider-Varianten, Extremwerte
- `MeetingReminderTests` (1 Test): Kompilierungstest

**Import in Tests:** `@testable import NevLate`

## Overlay-Features

### Alert-Overlay (AlertOverlayView)

Zentrale Content-Card mit `.glassEffect()` (Liquid Glass macOS 26):
- **Uhrzeit** oben (monospaced)
- **Titel** mit Kalender-Farbbalken + Kalender-Name
- **Zeitraum + Countdown** mit animiertem Pill
- **LIVE Badge** mit pulsierendem roten Dot (wenn Meeting läuft)
- **Countdown < 10 Sek:** wird größer und rot
- **Provider-Icon + Label** im Beitreten-Button ("Zoom beitreten", "Teams beitreten", etc.)
- **"via Provider"** Hinweis unter dem Button
- **Slide-Down Animation** (Card fliegt von oben rein)
- **Snooze** "Später erinnern" (1 Minute)
- **Warnung** "Kein Einwahllink vorhanden" (nur ohne Meeting-Link)

### Keyboard Shortcuts

| Shortcut | Aktion |
|---|---|
| `Return` / `Enter` | Beitreten (wenn Meeting-Link vorhanden) |
| `Escape` | Schließen |
| `Space` | Später erinnern (Snooze) |
| `Cmd+Shift+J` | Globaler Shortcut: Nächstes Meeting direkt öffnen |

## Einstellungen (Menüleisten-Popover)

### Sektionen

1. **Status:** Nächstes anstehendes Meeting oder "Keine anstehenden Meetings"
2. **Heute:** Chronologische Tagesübersicht aller Meetings (vergangene ausgegraut, laufende hervorgehoben)
3. **Kalender:** Nach Account gruppiert (iCloud, Exchange, Google, etc.) mit Toggles
4. **Einstellungen:** Vorlaufzeit (Stepper 1-10 Min), Nur Online-Meetings, Screen-Sharing, Sound, Globaler Shortcut, Autostart
5. **Über:** App-Version, Copyright

### Menüleisten-Icon

Custom Path-Drawing (`HeadsetClockMark`), dynamisch je nach Status:
- **Rot/aktiv** — Meeting in < 5 Minuten (höchste Dringlichkeit)
- **Gelb/warnend** — Meeting in < 15 Minuten
- **Normal** — kein Meeting in Kürze
- **Gestreift/fehler** — keine Kalender-Berechtigung / Fehler
- Meetings-Zähler (nächste 60 Min) neben dem Icon
- Tooltip: "Nächstes Meeting: [Name] in [X] Min"

## App Store

- **Bundle ID:** `de.hendrikgrueger.nevrlate`
- **App Name:** Nevr Late — Meeting Reminder
- **Preis:** Kostenlos
- **Kategorie:** Productivity (Sekundär: Utilities)
- **Minimum:** macOS 26+

## Konventionen

- **Sprache:** Deutsch (Kommentare, Commits, UI-Text, Accessibility-Labels)
- **Git:** GitHub MAIN (`hendrikgrueger-web`)
- **Testing:** Swift Testing + XCTest (macOS 26+)
- **Umlaute:** IMMER korrekt (ä, ö, ü, ß)
- **Code Style:** Swift 6 Concurrency, @MainActor wo nötig
- **Accessibility:** VoiceOver, Dynamic Type, Reduced Motion

## Nächste Schritte

- [x] App in App Store Connect angelegt (App-ID: `6761079659`)
- [x] Screenshots erstellt und hochgeladen (5× DE + 5× EN, alle ≥ 17/20 Punkte, kein Monetarisierungs-Versprechen)
- [x] App Store Review eingereicht (READY_FOR_REVIEW seit 31.03.2026)
- [x] Monetarisierung aus App-Code entfernt (StoreKit, ReminderCounter, PaywallView, NevLate.storekit entfernt)
- [ ] Xcode Cloud Pipeline einrichten (Push main → TestFlight automatisch)
- [ ] Sleep/Wake-Handling im Feld testen (MacBook Wake-Szenarios)
- [ ] Screen-Sharing-Erkennung auf Stabilität prüfen

## Screenshots

- **Quelle:** `docs/screenshots/screenshot_N_*.html` (HTML → Playwright → PNG)
- **DE:** `docs/screenshots/appstore_1–5.png` | **EN:** `docs/screenshots/en/appstore_1–5.png`
- **Workflow:** `../docs/screenshot-workflow.md` (Render-Befehl, Bewertungsmatrix ≥ 17/20, Sprachen)
- **Zuletzt aktualisiert:** 2026-03-31 — alle 5 Screens neu, ohne Logos (nur Text), ohne Monetarisierung

## Review Context

Bei Code-Reviews für Nevr Late beachten:
- **Kein StoreKit** — App ist komplett kostenlos, keine Monetarisierung im Code
- **Kein Provider-Filter** — Alle 8 Meeting-Provider werden immer unterstützt
- **Custom Icon** — Menüleisten-Icon ist `HeadsetClockMark` (Path-Drawing), kein SF Symbol
- **App Intents** — `AppIntents.swift` für Siri/Shortcuts/Spotlight-Integration vorhanden
- **@MainActor** — CalendarService ist @MainActor, kein ReminderCounter/StoreKitService mehr

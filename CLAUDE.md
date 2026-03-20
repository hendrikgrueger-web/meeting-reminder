# CLAUDE.md — Meeting Reminder

> Zuletzt aktualisiert: 2026-03-21

## Projektübersicht

Schlanke macOS-Menüleisten-App, die an bevorstehende Kalender-Events erinnert und das Beitreten zu MS Teams Meetings per Klick ermöglicht. Vollbild-Overlay mit konfigurierbarer Vorlaufzeit, Screen-Sharing-Schutz und Sleep/Wake-Handling. Maximal ressourcenschonend (kein Polling, event-basiertes Scheduling).

**Dokumentation:** `docs/superpowers/specs/2026-03-20-meeting-reminder-design.md` (Vollständiges Design Spec)

## Tech Stack

| Bereich | Technologie |
|---------|-------------|
| Sprache | Swift 6 |
| UI | SwiftUI |
| Kalender-API | EventKit (EKEventStore) |
| Overlay | NSPanel (AppKit-Bridge) |
| Persistenz | UserDefaults |
| Testing | Swift Testing Framework |
| Sound | NSSound (Systemtöne) |
| Autostart | SMAppService (macOS Login Item API) |
| Minimum | macOS 26+ (Tahoe) |
| Concurrency | @MainActor auf CalendarService |

## Architektur

**12 Swift-Dateien | 4 Test-Dateien**

### Quellcode-Struktur

```
Meeting Reminder/
├── MeetingReminderApp.swift           # @main, MenuBarExtra, App-Lifecycle
├── Models/
│   └── MeetingEvent.swift             # Event-Model mit zusammengesetztem Key für Recurring Events
├── Services/
│   └── CalendarService.swift          # EventKit, Timer-Management, Link-Erkennung (@MainActor)
├── Views/
│   ├── AlertOverlayView.swift         # Vollbild-Overlay mit Countdown, Liquid Glass, Accessibility
│   ├── OverlayPanel.swift             # NSPanel-Konfiguration (NSVisualEffectView, Blurring)
│   └── SettingsView.swift             # Menüleisten-Popover: Status, Kalender-Toggles, Einstellungen
└── Info.plist                         # LSUIElement=true, NSCalendarsUsageDescription
```

### Teams-Link-Erkennung

`CalendarService` extrahiert Microsoft Teams URLs mit 5 Regex-Patterns:
- `https://teams.microsoft.com/l/meetup-join/`
- `https://teams.microsoft.com/meet/`
- `https://teams.microsoft.us/l/meetup-join/` (Government/GCC)
- `https://dod.teams.microsoft.us/l/meetup-join/` (DoD)
- `https://teams.live.com/meet/` (Consumer)

Suchpriorität: `location` → `notes` (HTML-decoded) → `url`. Ergebnis wird in MeetingEvent gecacht.

### MeetingEvent-Model

```swift
struct MeetingEvent: Identifiable {
    let id: String                  // eventIdentifier + startDate (zusammengesetzter Key)
    let eventIdentifier: String
    let title: String
    let startDate: Date
    let endDate: Date
    let location: String?
    let calendarColor: Color
    let calendarTitle: String
    let teamsURL: URL?              // Einmalig beim Laden extrahiert
    let isAllDay: Bool
}
```

**Zusammengesetzter Key:** `"\(eventIdentifier)_\(startDate.timeIntervalSince1970)"` — kritisch für Recurring Events, die alle dieselbe `eventIdentifier` haben.

### CalendarService (@MainActor)

- **EventKit Integration:** 24h-Fenster Event-Abfrage (erfasst alle Events heute + morgen früh)
- **Timer-Management:** Ein gezielter Timer pro nächstes relevantes Event (kein Polling)
- **Debounce:** `EKEventStoreChangedNotification` mit 500ms Debounce (Burst-Handling bei iCloud-Sync)
- **Fallback-Check:** Alle 30 Min Events neu laden (bei verloren gegangenen Notifications)
- **Sleep/Wake-Handling:** `NSWorkspace.didWakeNotification` — verpasste Meetings nach Aufwachen erkennen
- **Screen-Sharing-Erkennung:** CGWindowList auf Capture-Prozesse prüfen

## Berechtigungen (Minimal)

| Entitlement | Zweck |
|---|---|
| `com.apple.security.personal-information.calendars` | Kalender lesen (Events + Teams-Links) |
| `com.apple.security.app-sandbox` | App Sandbox |
| `LSUIElement = true` | Menüleisten-App (kein Dock-Icon) |

**Kein Netzwerkzugriff-Entitlement nötig** — `NSWorkspace.open(url)` funktioniert aus der Sandbox.
**Kein Accessibility-Entitlement nötig** — VoiceOver wird mit `accessibilityLabel()` unterstützt.

## Build & Run

```bash
cd "/Users/hendrik.grueger/Coding/1_privat/Apple Apps/Meeting Reminder"
xcodegen generate
# Dann in Xcode öffnen: Meeting Reminder.xcodeproj
# Cmd+R zum Starten
```

## Tests

```bash
xcodebuild test -project "Meeting Reminder.xcodeproj" -scheme "Meeting ReminderTests" -destination "platform=macOS"
```

**4 Test-Dateien** — Abdeckung für:
- MeetingEvent Model & zusammengesetzter Key
- TeamsLinkExtractor (25+ Regex-Tests mit Edge Cases)
- CalendarService (Timer, Debounce, Sleep/Wake)
- OverlayPanel (NSPanel-Konfiguration)

**Testing-Framework:** Swift Testing (native macOS 26+)

## Ressourcenschonung (Performance)

- **CPU:** 0% im Ruhezustand (Timer schläft, kein Rendering)
- **RAM:** < 20 MB (kein großes Event-Modell, nur nächstes Event loaded)
- **Startzeit:** < 1 Sekunde (schnelle EventKit-Abfrage)

**Event-basiertes Scheduling:** Kein Polling — ein Timer pro nächstes relevantes Event. Bei Kalender-Änderung oder Mac-Wake: nur dann neu laden.

## Overlay-Features

### Layout

Zentrale Content-Card mit `.glassEffect()` (Liquid Glass macOS 26):
- **Oben:** Uhrzeit
- **Titel:** Mit Kalender-Farbbalken links
- **Zeitraum + Countdown:** "Die Ereignis beginnt in X Sek." oder "Meeting läuft seit X Min."
- **Ort:** Prominent angezeigt
- **Buttons:** "Beitreten" (glassProminent, nur bei Teams-Link), "Schließen"
- **Snooze:** "Später erinnern" (1 Minute)
- **Hinweis:** "⚠ Kein Einwahllink vorhanden" (nur ohne Teams-Link)

### Keyboard Shortcuts

| Shortcut | Aktion |
|---|---|
| `Return` / `Enter` | Beitreten (wenn Teams-Link) |
| `Escape` | Schließen |
| `Space` | Später erinnern (Snooze) |

### NSPanel-Konfiguration

```swift
panel.level = .screenSaver                     // Über Vollbild-Apps
panel.collectionBehavior = [
    .canJoinAllSpaces,
    .fullScreenAuxiliary,
    .stationary
]
panel.styleMask = [.borderless, .nonactivatingPanel]
panel.isOpaque = false
panel.backgroundColor = .clear
panel.ignoresMouseEvents = false
```

**Multi-Monitor:** Erscheint auf `NSScreen.main` (Bildschirm mit aktuellem Fokus).

### Screen-Sharing-Schutz

Bei aktiver Bildschirmfreigabe: statt Vollbild-Overlay → macOS System-Notification mit "Beitreten"-Action (nur wenn Setting "Bei Bildschirmfreigabe: nur Notification" aktiv).

### Accessibility

- Meeting-Titel: `.accessibilityAddTraits(.isHeader)`
- Countdown: `.accessibilityAddTraits(.updatesFrequently)` + Label mit Klartext
- Beitreten-Button: `.accessibilityLabel("Beitreten via Microsoft Teams")`
- Overlay-Erscheinen: `NSAccessibility.post(element:notification:)` mit `.layoutChanged`
- Reduced Motion respektieren: kein Fade-In wenn `.accessibilityReduceMotion` aktiv

## Einstellungen (Menüleisten-Popover)

### Status-Bereich

Nächstes anstehendes Meeting oder "Keine anstehenden Meetings".

### Einstellungen

| Einstellung | Typ | Standard |
|---|---|---|
| Kalender | Toggles pro Kalender | Alle aktiv |
| Vorlaufzeit | Picker: 1, 2, 3, 5 Min | 1 Minute |
| Nur Online-Meetings | Toggle | Aus |
| Bei Bildschirmfreigabe: nur Notification | Toggle | An |
| Sound | Toggle + Ton-Auswahl | Aus |
| Bei Anmeldung starten | Toggle | Aus |

### Menüleisten-Icon

SF Symbol, dynamisch je nach Status:
- `bell.badge` — Meeting in nächsten 15 Minuten
- `bell` — kein Meeting in Kürze
- `bell.slash` — keine Kalender-Berechtigung / Fehler

## Event-Evaluation

Ein Event ist "relevant" wenn:
1. **Kein ganztägiges Event** (`isAllDay == false`)
2. **Im aktivierten Kalender**
3. **In der Zukunft oder gerade am Laufen** (max 5 Min nach Start)
4. **"Nur Online-Meetings" erfüllt** (wenn aktiv: nur Events mit Teams-Link)
5. **Noch nicht dismissed** (In-Memory Set mit zusammengesetztem Key)

**Dismissed-Set:** Nicht persistiert — bei App-Neustart (Reboot, Crash) werden laufende Events erneut angezeigt.

## Gleichzeitige Events

Wenn mehrere Events gleichzeitig starten:
1. Alle relevanten Events sammeln
2. Erstes Event als Overlay anzeigen
3. Nach Dismiss/Beitreten/Schließen: nächstes gleichzeitiges Event anzeigen
4. Reihenfolge: Events mit Teams-Link zuerst, dann nach Kalender-Sortierung

## Fehlerzustände

| Zustand | Verhalten |
|---|---|
| Kalender-Zugriff verweigert | Icon: `bell.slash` + Popover-Hinweis mit Systemeinstellungen-Link |
| Kalender-Zugriff nachträglich entzogen | Wie oben, bei nächster EKEventStoreChangedNotification erkannt |
| Keine Kalender konfiguriert | Popover: "Keine Kalender gefunden" + Link zu Systemeinstellungen > Internet-Accounts |
| Login Item `.requiresApproval` | Popover-Hinweis + Link zu Systemeinstellungen > Anmeldeobjekte |
| Event während Overlay gelöscht | Overlay automatisch schließen, nächstes Event anzeigen |

## Snooze-Verhalten

- "Später erinnern" setzt einen neuen Timer in 1 Minute
- Verfügbar solange Event noch relevant ist (max 5 Min nach Start)
- Wenn bei Snooze-Trigger das Event > 5 Min läuft: kein erneuter Alert, auto-dismiss

## Konventionen

- **Sprache:** Deutsch (Kommentare, Commits, UI-Text, Accessibility-Labels)
- **Git:** GitHub MAIN (`hendrikgrueger-web`)
- **Testing:** Swift Testing Framework (native macOS 26+)
- **Umlaute:** IMMER korrekt (ä, ö, ü, ß) — niemals ae/oe/ue/ss
- **Code Style:** Swift 6 Concurrency Best Practices, @MainActor wo nötig
- **Accessibility:** VoiceOver, Dynamic Type, Reduced Motion

## Git-History (Commit-Überblick)

```
dc3f4d4 feat: MeetingReminderApp mit vollständigem Alert-Flow, Keyboard, Screen-Sharing-Fallback
a4a709e feat: SettingsView mit Status-Anzeige, Kalender-Toggles und Login Item
b5ac0b4 feat: CalendarService mit EventKit, Debounce, Sleep/Wake und 19 Swift Testing Tests
28a0e57 feat: MeetingEvent Model mit zusammengesetztem Key für Recurring Events
47b0412 feat: AlertOverlayView mit Countdown, Liquid Glass Material und Accessibility
cfdea01 feat: OverlayPanel NSPanel-Wrapper mit Keyboard Shortcuts
e970fe8 feat: OverlayController mit Screen-Sharing-Erkennung
8454382 feat: MeetingEvent Model mit zusammengesetztem Key für Recurring Events + 10 Tests
89a18e2 feat: TeamsLinkExtractor mit 5 URL-Patterns, HTML-Decode und 25+ Tests
```

## Nächste Schritte

- [ ] TestFlight-Build über App Store Connect erstellen
- [ ] UI-Refinements und Liquid Glass Feinabstimmung
- [ ] Sleep/Wake-Handling im Feld testen (MacBook Wake-Szenarios)
- [ ] Screen-Sharing-Erkennung auf Stabilität prüfen
- [ ] Release Notes für App Store schreiben

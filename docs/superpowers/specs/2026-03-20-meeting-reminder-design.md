# Meeting Reminder — macOS App Design Spec

> Datum: 2026-03-20
> Status: Reviewed (3-Agenten-Review abgeschlossen)

## Zusammenfassung

Schlanke macOS-Menüleisten-App, die an bevorstehende Kalender-Events erinnert. Vollbild-Overlay mit "Beitreten"-Button für MS Teams Meetings. Maximal ressourcenschonend, Apple-nativ, minimale Berechtigungen.

## Anforderungen

### Must-Have
- Vollbild-Overlay-Alert vor Kalender-Events
- MS Teams Join-Link erkennen und per Klick öffnen
- Kalender-Auswahl (welche Kalender überwacht werden)
- Konfigurierbare Vorlaufzeit (Standard: 1 Minute)
- Snooze-Funktion (1 Minute)
- Menüleisten-App (kein Dock-Icon)
- Events ohne Teams-Link: Alert mit Ort, Hinweis "Kein Einwahllink"
- Option "Nur Online-Meetings"
- Sound konfigurierbar (Standard: aus)
- Keyboard Shortcuts im Overlay (Enter=Beitreten, Esc=Schließen, Space=Snooze)
- Sleep/Wake-Handling (verpasste Meetings nach Mac-Aufwachen erkennen)
- Ganztägige Events ignorieren
- VoiceOver-Accessibility für Overlay

### Nicht im Scope
- Andere Videokonferenz-Dienste (Zoom, Google Meet, WebEx)
- iOS / watchOS / iPad
- Eigene Kalender-Verwaltung
- Netzwerk-Kommunikation (außer Teams-Link öffnen)
- Cloud-Sync von Einstellungen

## Architektur

### Technologie

| Komponente | Technologie | Begründung |
|---|---|---|
| Sprache | Swift 6 | Aktueller Standard |
| UI | SwiftUI | Native macOS, deklarativ |
| Kalender | EventKit (EKEventStore) | Apple-native API |
| Persistenz | UserDefaults | Triviale Settings, kein Datenmodell |
| Scheduling | Ein gezielter Timer + Notifications | Null CPU-Last zwischen Events |
| Teams beitreten | `NSWorkspace.shared.open(url)` | Öffnet Teams-App oder Browser |
| Sound | `NSSound` | Systemtöne, kein Import nötig |
| Autostart | `SMAppService` | macOS Login Item API |
| Minimum | macOS 26+ | Aktuelles Tahoe |
| Concurrency | `@MainActor` auf CalendarService | EKEventStore ist nicht Sendable |

### Berechtigungen (minimal)

| Berechtigung | Entitlement | Zweck |
|---|---|---|
| Kalender lesen | `com.apple.security.personal-information.calendars` | Events + Links lesen |
| App Sandbox | `com.apple.security.app-sandbox` | Sandboxed App |

Kein Netzwerkzugriff-Entitlement nötig. `NSWorkspace.open()` funktioniert aus der Sandbox heraus. Kein Accessibility-Zugriff. `SMAppService.mainApp` braucht kein zusätzliches Entitlement.

## Ressourcenschonung

### Event-basiertes Scheduling (kein Polling)

```
App-Start
  ↓
Nächstes relevantes Event aus EventKit laden (24h-Fenster)
  ↓
Einen Timer setzen auf: EventStart - Vorlaufzeit
  ↓
Timer feuert → Vollbild-Overlay anzeigen
  ↓
Nächsten Timer berechnen
```

### Kalender-Änderungen erkennen

`EKEventStoreChangedNotification` abonnieren. Wird von EventKit gefeuert wenn:
- Neues Event hinzugefügt (spontanes Meeting)
- Event verschoben oder geändert
- Event gelöscht
- Kalender-Sync abgeschlossen (Exchange, iCloud, Google)

Bei Notification: Events neu laden, Timer neu berechnen. Kein periodisches Polling.

**Debounce:** Die Notification kann in Bursts feuern (z.B. 20 Events bei iCloud-Sync). Alle Notifications werden mit 500ms Debounce zusammengefasst — erst nach 500ms Ruhe wird tatsächlich neu geladen.

**Fallback-Check:** Alle 30 Minuten Events zusätzlich neu laden, falls eine Notification verloren geht (z.B. bei Exchange-Polling-Sync). Kostet nahezu nichts.

### Sleep/Wake-Handling

**Pflicht** — MacBooks schlafen ständig, Timer werden dabei pausiert.

`NSWorkspace.didWakeNotification` abonnieren. Bei Wake:
1. Timer sofort neu berechnen
2. Prüfen ob ein Meeting WÄHREND des Schlafs hätte starten sollen
3. Wenn ein Meeting läuft und < 5 Min seit Start: sofort Overlay anzeigen
4. Wenn ein Meeting > 5 Min läuft: auto-dismiss (Meeting verpasst)

`NSWorkspace.willSleepNotification`: Timer invalidieren (optional, spart Ressourcen).

### Ergebnis

- **Nahezu null CPU-Last** zwischen Meetings (Timer schläft, kein Rendering)
- App wacht nur bei Kalender-Änderung, Timer-Event oder Mac-Wake auf
- Kein Hintergrund-Rendering — SwiftUI View wird erst bei Alert erstellt
- Regex nur einmal pro Event beim Laden, Ergebnis in MeetingEvent-Model gecacht
- Während Overlay sichtbar: 1 Update/Sekunde für Countdown (minimal)

## Dateistruktur

```
Meeting Reminder/
├── MeetingReminderApp.swift       # @main, MenuBarExtra, App-Lifecycle
├── Models/
│   └── MeetingEvent.swift         # Leichtgewichtiges Event-Model
├── Services/
│   └── CalendarService.swift      # EventKit, Timer, Link-Erkennung (@MainActor)
├── Views/
│   ├── AlertOverlayView.swift     # Vollbild-Overlay mit Meeting-Details
│   ├── OverlayPanel.swift         # NSPanel-Konfiguration (AppKit-Bridge)
│   └── SettingsView.swift         # Menüleisten-Popover mit Status + Settings
└── Info.plist                     # Kalender-Berechtigung, LSUIElement=true
```

**Info.plist Pflicht-Einträge:**
- `LSUIElement = true` — kein Dock-Icon (zwingend für Menüleisten-App)
- `NSCalendarsUsageDescription` — Begründung für Kalender-Zugriff

## MeetingEvent-Model

Leichtgewichtiges Model, das die relevanten Daten aus `EKEvent` extrahiert und cached:

```swift
struct MeetingEvent: Identifiable {
    let id: String              // eventIdentifier + startDate (zusammengesetzter Key)
    let eventIdentifier: String // EKEvent.eventIdentifier
    let title: String
    let startDate: Date
    let endDate: Date
    let location: String?
    let calendarColor: Color
    let calendarTitle: String
    let teamsURL: URL?          // Einmalig beim Laden extrahiert
    let isAllDay: Bool
}
```

**Zusammengesetzter Key:** `"\(eventIdentifier)_\(startDate.timeIntervalSince1970)"` — löst das Problem mit Recurring Events, die alle dieselbe `eventIdentifier` haben.

## Teams-Link-Erkennung

### Regex-Patterns

Mehrere Patterns, da Microsoft verschiedene URL-Formate verwendet:

```
# Klassisches Format
https://teams\.microsoft\.com/l/meetup-join/[^\s"<>]+

# Neues /meet/ Format (seit 2024)
https://teams\.microsoft\.com/meet/[^\s"<>]+

# Government/GCC-Instanzen
https://teams\.microsoft\.us/l/meetup-join/[^\s"<>]+
https://dod\.teams\.microsoft\.us/l/meetup-join/[^\s"<>]+

# Consumer/Personal
https://teams\.live\.com/meet/[^\s"<>]+
```

Alle Patterns case-insensitive.

### Suchpriorität der Event-Felder

1. **`location`** (String) — hier steht der Teams-Link am häufigsten (Outlook setzt ihn als "Ort")
2. **`notes`** (String, oft HTML) — kompletter Meeting-Body, HTML-Decode vor Regex nötig (`&amp;` → `&`)
3. **`url`** (URL?) — selten gesetzt, direkter Host-Check statt Regex

Erster Treffer wird verwendet.

### HTML-Entity-Decode für Notes

Vor dem Regex-Match auf `notes` einfacher HTML-Decode:
- `&amp;` → `&`
- `&lt;` → `<`
- `&gt;` → `>`
- `&quot;` → `"`

## NSPanel-Konfiguration (Overlay)

### Kritische Flags

Das Overlay MUSS über Vollbild-Apps, Stage Manager und allen Spaces erscheinen:

```swift
let panel = NSPanel(
    contentRect: screen.frame,
    styleMask: [.borderless, .nonactivatingPanel],
    backing: .buffered,
    defer: false
)

panel.level = .screenSaver                    // Über allem, inkl. Vollbild-Apps
panel.collectionBehavior = [
    .canJoinAllSpaces,                        // Auf allen Spaces sichtbar
    .fullScreenAuxiliary,                     // Über Vollbild-Apps
    .stationary                               // Bewegt sich nicht bei Space-Wechsel
]
panel.isOpaque = false
panel.backgroundColor = .clear
panel.hasShadow = false
panel.ignoresMouseEvents = false
panel.hidesOnDeactivate = false               // Bleibt sichtbar wenn App nicht aktiv
panel.isFloatingPanel = true
```

### Multi-Monitor

Overlay erscheint auf `NSScreen.main` (= Bildschirm mit aktuellem Key-Window / Mausfokus). Nicht auf allen Monitoren.

### Screen-Sharing-Schutz

**Problem:** Bei aktiver Bildschirmfreigabe zeigt das Overlay vertrauliche Kalenderinfos für alle Teilnehmer.

**Lösung:** Einstellung "Bei Bildschirmfreigabe: nur Notification" (Standard: An). Wenn aktiv und Screen Sharing erkannt (via `CGWindowListCopyWindowInfo` auf bekannte Capture-Prozesse): statt Vollbild-Overlay eine macOS-System-Notification (`UNUserNotificationCenter`) mit "Beitreten"-Action verwenden.

## Vollbild-Overlay

### Layout

```
┌─────────────────────────────────────────────┐
│                                    14:59:03  │  ← Uhrzeit oben rechts
│                                              │
│              ■ Meeting-Titel                 │  ← Kalenderfarbe + Titel
│              15:00 – 16:00                   │  ← Zeitraum
│         Das Ereignis beginnt in 50 Sek.      │  ← Countdown
│                                              │
│              Conference Room A               │  ← Ort (prominent)
│                                              │
│         ┌──────────────────────┐             │
│         │   ☐ Beitreten        │             │  ← Nur wenn Teams-Link
│         └──────────────────────┘             │
│         ┌──────────────────────┐             │
│         │     Schließen        │             │
│         └──────────────────────┘             │
│                                              │
│           Später erinnern                    │
│        ┌─────────┐                           │
│        │ 1 Minute │                          │  ← Snooze
│        └─────────┘                           │
│                                              │
│     ⚠ Kein Einwahllink vorhanden             │  ← Nur wenn KEIN Teams-Link
└─────────────────────────────────────────────┘
```

### Design

- **Hintergrund:** Dimmed/Blurred — `NSVisualEffectView` mit `.behindWindow` + `Color.black.opacity(0.7)`. Bildschirminhalt soll unlesbar werden.
- **Content-Card:** Zentraler Bereich mit `.glassEffect()` (macOS 26 Liquid Glass) für modernen Tahoe-Look.
- **Buttons:** `.buttonStyle(.glass)` / `.buttonStyle(.glassProminent)` für "Beitreten".
- **Kalenderfarbe:** Farbiger vertikaler Strich links neben dem Titel.

### Keyboard Shortcuts

| Shortcut | Aktion |
|---|---|
| `Return` / `Enter` | Beitreten (wenn Teams-Link vorhanden) |
| `Escape` | Schließen |
| `Space` | Später erinnern (Snooze) |

### Verhalten

- Erscheint über allen Fenstern, Spaces und Vollbild-Apps
- Erscheint auf dem Bildschirm mit aktuellem Fokus (`NSScreen.main`)
- Blockiert NICHT Tastatur/Maus (kein modaler Dialog, `nonactivatingPanel`)
- Verschwindet bei "Schließen" oder "Beitreten"
- Bei "Später erinnern": verschwindet, neuer Timer in 1 Minute
- Countdown aktualisiert sich jede Sekunde
- Wenn Event bereits begonnen: "Meeting läuft seit X Minuten"
- Wenn Event während Overlay gelöscht wird (EKEventStoreChanged): Overlay automatisch schließen

### VoiceOver-Accessibility

- Meeting-Titel: `.accessibilityAddTraits(.isHeader)`
- Countdown: `.accessibilityAddTraits(.updatesFrequently)` + Label mit Klartext
- Beitreten-Button: `.accessibilityLabel("Beitreten via Microsoft Teams")`
- Bei Overlay-Erscheinen: `NSAccessibility.post(element:notification:)` mit `.layoutChanged`
- Reduced Motion respektieren: kein Fade-In wenn `.accessibilityReduceMotion` aktiv

## Einstellungen (Menüleisten-Popover)

Erscheint als Popover beim Klick auf das Menüleisten-Icon.

### Oberer Bereich: Status

Nächstes anstehendes Meeting anzeigen (Titel + Uhrzeit), oder "Keine anstehenden Meetings". Gibt dem User sofortigen Kontext ohne den Kalender öffnen zu müssen.

### Unterer Bereich: Einstellungen

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
- `bell.badge` — Meeting in den nächsten 15 Minuten
- `bell` — kein Meeting in Kürze
- `bell.slash` — keine Kalender-Berechtigung / Fehler

### SMAppService Status

Wenn Login Item Status `.requiresApproval`: Hinweis im Popover mit Link zu Systemeinstellungen > Anmeldeobjekte.

## Ablauf im Detail

### App-Start
1. `EKEventStore.requestFullAccessToEvents()` — Kalender-Berechtigung anfragen
2. Alle Kalender laden, gespeicherte Auswahl aus UserDefaults anwenden
3. `EKEventStoreChangedNotification` abonnieren (mit 500ms Debounce)
4. `NSWorkspace.didWakeNotification` abonnieren
5. Nächstes relevantes Event berechnen, Timer setzen
6. Beim allerersten Start (`hasLaunchedBefore` Flag): Popover automatisch öffnen

### Event-Evaluation
Ein Event ist "relevant" wenn:
1. Es **kein** ganztägiges Event ist (`isAllDay == false`)
2. Es in einem aktivierten Kalender liegt
3. Es in der Zukunft liegt (oder gerade läuft, max 5 Min nach Start)
4. Wenn "Nur Online-Meetings" aktiv: es einen Teams-Link hat
5. Es nicht bereits geschlossen/dismissed wurde

**Event-Laden:** `eventStore.predicateForEvents(withStart: now - 5min, end: now + 24h)`. 24h-Fenster ist optimal — erfasst alle Events von heute und morgen früh, selbst bei 500 Events sind im 24h-Fenster selten mehr als 20-30.

**Dismissed-Set:** In-Memory `Set<String>` mit zusammengesetztem Key `eventIdentifier + startDate`. Wird NICHT persistiert. Bei App-Neustart (Reboot, Crash) werden laufende Events erneut angezeigt — damit man nach einem Neustart nicht ein laufendes Meeting verpasst.

**Zusammengesetzter Key nötig wegen Recurring Events:** Alle Occurrences eines wiederkehrenden Events haben dieselbe `eventIdentifier`. Ohne `startDate` im Key würde das Montags-Meeting auch für nächsten Montag dismissed. Aufräumen: Einträge entfernen wenn `endDate` des Events in der Vergangenheit liegt.

### Gleichzeitige Events

Wenn mehrere Events gleichzeitig starten:
1. Alle relevanten Events für den Zeitpunkt sammeln
2. Erstes Event als Overlay anzeigen
3. Nach Dismiss/Beitreten/Schließen: nächstes gleichzeitiges Event anzeigen
4. Reihenfolge: Events mit Teams-Link zuerst, dann nach Kalender-Sortierung

### Alert-Trigger
1. Timer feuert (oder Wake-Notification erkennt verpasstes Meeting)
2. Alle Events für diesen Zeitpunkt aus EventKit laden (könnten sich geändert haben)
3. Relevante Events filtern
4. Screen-Sharing prüfen — wenn aktiv und Setting an: System-Notification statt Overlay
5. Wenn Events vorhanden: erstes Overlay anzeigen
6. Optional: Sound abspielen
7. Countdown starten

### Snooze-Verhalten
- "Später erinnern" setzt einen neuen Timer in 1 Minute
- Snooze ist verfügbar solange das Event noch relevant ist (max 5 Min nach Start)
- Wenn bei Snooze-Trigger das Event > 5 Min läuft: kein erneuter Alert, Event wird auto-dismissed
- Maximale Snooze-Kette: implizit begrenzt durch das 5-Minuten-Fenster

### Nach Alert
1. Event-ID (zusammengesetzter Key) in dismissed-Set speichern
2. Nächstes relevantes Event berechnen (inkl. weitere gleichzeitige Events)
3. Neuen Timer setzen

### Fehlerzustände

| Zustand | Verhalten |
|---|---|
| Kalender-Zugriff verweigert | Menüleisten-Icon: `bell.slash`. Popover: "Kalender-Zugriff benötigt" + Button zu Systemeinstellungen |
| Kalender-Zugriff nachträglich entzogen | Wie oben, wird bei nächster `EKEventStoreChangedNotification` erkannt |
| Keine Kalender konfiguriert | Popover: "Keine Kalender gefunden" + Link zu Systemeinstellungen > Internet-Accounts |
| Login Item `.requiresApproval` | Popover: Hinweis + Link zu Systemeinstellungen > Anmeldeobjekte |
| Event während Overlay gelöscht | Overlay automatisch schließen, nächstes Event anzeigen |

## Nicht-funktionale Anforderungen

- **RAM**: < 20 MB im Ruhezustand
- **CPU**: 0% zwischen Events
- **Startzeit**: < 1 Sekunde
- **Accessibility**: VoiceOver, Dynamic Type, Reduced Motion
- **Concurrency**: `@MainActor` auf CalendarService — EKEventStore ist nicht Sendable

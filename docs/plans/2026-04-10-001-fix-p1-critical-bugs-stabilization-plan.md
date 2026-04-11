---
title: "fix: P1 Critical Bugs — Snooze, Overlay Lifecycle, State Management"
type: fix
status: completed
date: 2026-04-10
deepened: 2026-04-10
---

# fix: P1 Critical Bugs — Snooze, Overlay Lifecycle, State Management

## Overview

Behebt 9 P1-Bugs aus dem exhaustiven Code Review vom 2026-04-10. Die App ist live im App Store — diese Fixes stabilisieren die Kernfunktionen: Snooze, Overlay, Timer-Management, State-Konsistenz, Tests und Dokumentation.

## Problem Frame

Nevr Late ist eine macOS-Menüleisten-App die Kalender-Events überwacht und ein Vollbild-Overlay vor Meetings anzeigt. Drei interne State-Sets (`pendingEvents`, `dismissedEvents`, `snoozedEvents`) werden von mehreren Timern, User-Aktionen und System-Events (Sleep/Wake, EKEventStoreChanged) gleichzeitig modifiziert. Die Interaktion dieser Sets ist fehlerhaft:

- **Snooze ist kaputt** — `reloadAndReschedule()` ignoriert `snoozedEvents`, laufende Meetings poppen sofort wieder auf
- **pendingEvents wird überschrieben** — laufende Events löschen zukünftige Events aus der Queue
- **Screen-Sharing dismiss ist permanent** — Events werden unwiderruflich dismissed statt temporär stillgelegt
- **Overlay-Observer feuern doppelt** — NotificationCenter-Subscription wird beim neuen Overlay nicht cleanuped
- **Sleep/Wake invalidiert Snooze-Timer nicht** — Timer feuern nach Wake sofort
- **nextEvent stale nach Dismiss** — Menüleisten-Icon zeigt falschen Zustand

## Requirements Trace

- R1. Snooze funktioniert zuverlässig — Overlay erscheint nicht erneut während der Snooze-Phase
- R2. Mehrere gleichzeitige Events werden korrekt verwaltet — kein Event geht verloren
- R3. Screen-Sharing-Fallback ist temporär — Event kann nach Ende der Bildschirmfreigabe angezeigt werden
- R4. Overlay-Observer werden sauber cleanuped — kein Doppel-Feuer
- R5. Menüleisten-Icon ist konsistent mit tatsächlichem State
- R6. Sleep/Wake behandelt alle Timer korrekt
- R7. Tests sind isoliert und nicht von Singleton-Mutation abhängig
- R8. Dokumentation spiegelt tatsächlichen Code-Stand wider
- R9. Privacy Manifest ist vollständig

## Scope Boundaries

- **Nur P1-Bugs** — P2/P3-Issues in separatem Plan
- **Kein Refactoring** — CalendarService bleibt bei 430 Lines, keine neuen Dateien
- **Keine UI-Änderungen** — Layout, Design, Animationen bleiben wie sie sind
- **Kein Custom-Icon → SF Symbol Migration** — das ist P3
- **Keine neuen Features** — nur Bug-Fixes

## Context & Research

### Relevant Code and Patterns

- **Testable static methods**: CalendarService nutzt `nonisolated static` Methoden für testbare Business-Logik (`isEventRelevant`, `shouldReShowSnoozedEvent`, `cleanedDismissedSet`, `compareEvents`). Neue Logik MUSS diesem Pattern folgen.
- **Closure Injection**: `handlePendingEvents(isScreenSharing:)` injiziert die Screen-Sharing-Erkennung als Closure. Gleicher Ansatz für neue testbare Abhängigkeiten.
- **todayEvents vs loadRelevantEvents**: Status-Anzeige (nextEvent, Icon, Tooltip) nutzt `todayEvents`. Reminder-Logik nutzt `loadRelevantEvents`. Diese Trennung MUSS erhalten bleiben.
- **Snooze Race Condition (Todo #005)**: Guard-Check `!pendingEvents.contains(where:)` im Snooze-Timer-Callback verhindert Duplikate. Pattern ist korrekt, aber Root Cause (reloadAndReschedule ignoriert snoozedEvents) wurde nie gefixt.
- **Schedule Timer Concurrent Events (Todo #012)**: Bekanntes Issue — `scheduleTimer` zeigt nur ein von mehreren gleichzeitigen Events. Wird in diesem Plan teilweise adressiert (runningEvents überschreibt nicht mehr pendingEvents), vollständige Lösung ist separater Plan.

### Institutional Learnings

- **Todo #011**: "Später erinnern" rief `onDismiss` statt `onSnooze` — wurde behoben durch Entfernen des redundanten Buttons
- **Todo #012**: `scheduleTimer` zeigt nur ein Event bei gleichzeitig startenden Meetings — Timer-Chain bricht nach Wake ab
- **Plan 2026-03-26-001**: `nextEvent` muss aus `todayEvents` abgeleitet werden, nicht aus `loadRelevantEvents`
- **NSPanel Level**: Wurde von `.screenSaver` auf `.floating` reduziert für App Store Compliance

### Key Files

| Datei | LOC | Rolle |
|-------|-----|-------|
| `Meeting Reminder/Services/CalendarService.swift` | 430 | Core: EventKit, Timer, Snooze/Dismiss |
| `Meeting Reminder/MeetingReminderApp.swift` | 415 | AppDelegate, Combine Pipeline, Global Shortcut |
| `Meeting Reminder/Views/AlertOverlayView.swift` | 310 | Vollbild-Overlay UI |
| `Meeting Reminder/Views/OverlayController.swift` | 47 | NSPanel Lifecycle |
| `Meeting Reminder/Views/OverlayPanel.swift` | 49 | Keyboard Shortcuts via NotificationCenter |
| `Meeting ReminderTests/MeetingReminderTests.swift` | 189 | AppDelegate Tests (XCTest) |
| `Meeting ReminderTests/CalendarServiceTests.swift` | 644 | CalendarService Logik (Swift Testing) |
| `Meeting Reminder/PrivacyInfo.xcprivacy` | 32 | Privacy Manifest |

## Key Technical Decisions

1. **`snoozeUntil: [String: Date]` statt `[String: Timer]`** (Geändert nach Qwen/DeepSeek Review): Statt Snooze-Timer zu verwalten, wird ein Dict `snoozeUntil[eventID: String] = resumeDate` gespeichert. `reloadAndReschedule()` filtert Events deren `snoozeUntil` in der Zukunft liegt. **Vorteile**: Kein Timer-Management, automatisch Sleep/DST-safe, `Date` ist `Sendable` (Swift 6 konform), keine Closure-Isolation-Probleme, keine Retain-Cycles. Der bestehende 30-Min-Fallback-Timer + Wake-Handler + Debounce sorgen dafür dass abgelaufene Snooze-Einträge rechtzeitig erkannt werden.

2. **runningEvents MERGE statt REPLACE**: `pendingEvents = runningEvents` wird zu einer Merge-Logik die Events aus beiden Quellen behält und nach ID dedupliziert. Begründung: Verhindert dass laufende Events zukünftige Events aus der Queue löschen.

3. **Screen-Sharing: `silencedEvents: Set<String>` mit Bounce-Schutz**: Statt `dismissEvent()` wird eine neue Methode `silenceEvent()` eingeführt die das Event in ein `silencedEvents` Set aufnimmt. `reloadAndReschedule()` filtert `silencedEvents` analog zu `dismissedEvents` — aber `silencedEvents` hat KEINE 2h-Retention sondern wird bei jedem `reloadAndReschedule()` geleert. Das bedeutet: Wenn Screen-Sharing noch aktiv ist → Event wird wieder gesilenced (via `handlePendingEvents` + Notification). Wenn Screen-Sharing beendet → Event taucht normal im Overlay auf. **Löst Bounce-Problem** (Qwen/DeepSeek): Kein Endless-Loop weil `silencedEvents` bei jedem Reload zurückgesetzt wird.

4. **Overlay-Observer Cleanup via OverlayController + windowWillClose** (Geändert nach Qwen/DeepSeek Review): Statt unsicherem `.onDisappear` in NSPanel-hosted SwiftUI Views wird `OverlayController` um `NSWindowDelegate` erweitert. `windowWillClose(_:)` postet eine Cleanup-Notification. AlertOverlayView registriert Subscriptions in `.onAppear` und cancellt sie bei der Cleanup-Notification. **Begründung**: `NSWindowDelegate.windowWillClose` ist deterministisch auf macOS, `.onDisappear` in NSPanel ist unzuverlässig (Qwen: "EXC_BAD_ACCESS auf deallokierte Referenzen").

5. **`nextEvent` als automatisch aktualisierte Property** (Geändert nach Qwen/DeepSeek Review): Statt imperativem `updateNextEvent()` in jeder State-Mutation wird die bestehende `reloadAndReschedule()`-Logik genutzt die bereits `nextEvent` und `upcomingEventsCount` setzt. `dismissEvent()` und `snoozeEvent()` rufen am Ende `reloadAndReschedule()` auf (wenn `pendingEvents.isEmpty`) — das Aktualisert automatisch alle abgeleiteten Properties. Für den Fall dass `pendingEvents` nicht leer ist (weil andere Events noch anstehen), wird `nextEvent` direkt aus `todayEvents` neu berechnet.

## Open Questions

### Resolved During Planning

- **Screen-Sharing-Events dauerhaft stilllegen oder wiedervorlagen?** → Wiedervorlagen. `silencedEvents` Set das bei jedem `reloadAndReschedule()` geleert wird. Wenn Screen-Sharing noch aktiv → `handlePendingEvents` silenced erneut. Wenn beendet → Event taucht normal auf.
- **Snooze: Timer oder Timestamp?** → **Timestamp** (`snoozeUntil: [String: Date]`). Timer-Management eliminiert, Sleep/DST-safe, Swift 6 Sendable-konform. (Geändert nach Qwen-Review: "Eliminiert Timer-Management, Closure-Isolation und Retain-Cycles vollständig")
- **Overlay-Cleanup: onDisappear oder NSWindowDelegate?** → **NSWindowDelegate `windowWillClose`**. `.onDisappear` ist in NSPanel-Kontext unzuverlässig. (Geändert nach Qwen/DeepSeek-Review)

### Deferred to Implementation

- **Exact Snooze-Dauer** — aktuell 60 Sekunden hardcoded, könnte zu einer Property werden
- **`silencedEvents` Cleanup-Strategie** — ob leer bei jedem `reloadAndReschedule()` oder zeitbegrenzt (z.B. 5 Min nach Silence)
- **Ob `nextEvent`-Update in `dismissEvent()` über `reloadAndReschedule()` oder direkte Neuberechnung** — hängt davon ab ob andere Events noch pending sind

## Implementation Units

- [x] **Unit 1: CalendarService State-Management Fixes (Bugs #1, #2, #5, #6)**

**Goal:** Die vier interdependenten Bugs in `reloadAndReschedule()`, `snoozeEvent()`, Sleep/Wake und `nextEvent` beheben. Das ist das Fundament — alle anderen Units bauen darauf auf.

**Requirements:** R1, R2, R5, R6

**Dependencies:** None — dieses ist das Fundament

**Files:**
- Modify: `Meeting Reminder/Services/CalendarService.swift`
- Test: `Meeting ReminderTests/CalendarServiceTests.swift`

**Approach:**

1. **Neue Property `snoozeUntil: [String: Date]`** — ersetzt `snoozedEvents: Set<String>` und eliminiert alle Snooze-Timer:
   - `snoozeUntil[eventID] = now + 60` (Snooze-Dauer)
   - Statt eines 60s-Timers: `reloadAndReschedule()` prüft ob `snoozeUntil[eventID]` abgelaufen ist
   - Abgelaufene Einträge werden in `reloadAndReschedule()` automatisch entfernt
   - Kein `Timer.scheduledTimer` mehr für Snooze — der Fallback-Timer (30 Min) + Wake-Handler + Debounce reichen aus

2. **`reloadAndReschedule()` runningEvents-Branch fixen**:
   - Zeile 200-205: Filter erweitern: `!dismissedEvents.contains(id) && (snoozeUntil[id] == nil || snoozeUntil[id]! <= now)`
   - Zeile 203: `pendingEvents = runningEvents` → Merge: behalte Events die bereits in pendingEvents sind aber nicht in runningEvents
   - Neue testbare statische Methode: `nonisolated static func mergePendingWithRunning(pending: [MeetingEvent], running: [MeetingEvent]) -> [MeetingEvent]`

3. **`snoozeEvent()` vereinfachen**:
   - Statt Timer zu erstellen: `snoozeUntil[event.id] = Date().addingTimeInterval(60)`
   - Entferne Event aus `pendingEvents`
   - Rufe `reloadAndReschedule()` auf (updated nextEvent automatisch)

4. **`dismissEvent()` erweitern**:
   - Entferne `snoozeUntil[event.id]` (falls vorhanden)
   - Rufe `reloadAndReschedule()` auf (updated nextEvent automatisch)

5. **`willSleepNotification`**: Keine Snooze-Timer-Invalidierung mehr nötig! `alertTimer?.invalidate()` bleibt, Snooze-Entries sind Timestamps die nach Wake automatisch abgelaufen sein können oder nicht — `reloadAndReschedule()` handlet das korrekt.

6. **`nextEvent` und `upcomingEventsCount`** werden bereits in `reloadAndReschedule()` berechnet (Zeile 194-198). Da `dismissEvent()` und `snoozeEvent()` jetzt `reloadAndReschedule()` aufrufen, werden sie automatisch aktualisiert.

**Execution note:** Test-first — neue statische Methoden zuerst testen, dann implementieren.

**Test scenarios:**
- `mergePendingWithRunning`: laufendes + zukünftiges Event → beide im Ergebnis
- `mergePendingWithRunning`: Duplicate → nur ein Vorkommen
- `snoozeUntil` in der Zukunft → Event wird in reload nicht gezeigt
- `snoozeUntil` abgelaufen → Event wird wieder gezeigt
- `dismissEvent` entfernt `snoozeUntil`-Eintrag
- Sleep über Snooze-Dauer hinaus → Wake zeigt Event nicht (abgelaufen)
- Sleep unter Snooze-Dauer → Wake zeigt Event nach Ablauf
- `nextEvent` aktualisiert sich nach `dismissEvent()` korrekt

**Verification:**
- Alle neuen statischen Methoden haben Tests im Swift Testing Format
- `xcodebuild test` grün
- Snooze-Flow manuell testen: Event starten → Snooze → 30s warten → kein Re-Appear

---

- [x] **Unit 2: Screen-Sharing Temporäres Stillschlagen (Bug #3)**

**Goal:** Screen-Sharing-Fallback entfernt Event nur temporär — nicht permanent. Bounce-Schutz verhindert Endless-Loop.

**Requirements:** R3

**Dependencies:** Unit 1 (verwendet `reloadAndReschedule` mit neuer Merge-Logik)

**Files:**
- Modify: `Meeting Reminder/MeetingReminderApp.swift`
- Modify: `Meeting Reminder/Services/CalendarService.swift`
- Test: `Meeting ReminderTests/MeetingReminderTests.swift`

**Approach:**

1. **Neues Set `silencedEvents: Set<String>`** auf CalendarService:
   - Wird bei jedem `reloadAndReschedule()` zu Begin **geleert** (unterschied zu `dismissedEvents` das 2h Retention hat)
   - `isRelevant()` filtert zusätzlich gegen `silencedEvents`

2. **Neue Methode `silenceEvent()`** auf CalendarService:
   - Fügt Event-ID zu `silencedEvents` hinzu
   - Entfernt Event aus `pendingEvents`
   - Ruft `reloadAndReschedule()` auf → leert `silencedEvents` → aber `handlePendingEvents` wird erneut aufgerufen
   - Wenn Screen-Sharing noch aktiv → Event wird wieder gesilenced (via Notification, kein Overlay)
   - Wenn Screen-Sharing beendet → Event taucht normal im Overlay auf

3. **Bounce-Schutz**: Da `silencedEvents` bei jedem Reload geleert wird, wird das Event bei aktuellem Screen-Sharing erneut zu `pendingEvents` hinzugefügt → `handlePendingEvents` feuert → `isScreenSharing()` true → `silenceEvent()` erneut → System-Notification erneut. **Das ist akzeptabel**: pro 30-Min-Fallback-Zyklus eine Notification. Bei EKEventStoreChanged (500ms Debounce) ebenfalls eine Notification. Kein Overlay-Bounce.

4. **`handlePendingEvents()` Zeile 323**: `calendarService.dismissEvent(event)` → `calendarService.silenceEvent(event)`

**Test scenarios:**
- Screen-Sharing aktiv → Event wird gesilenced → System-Notification gesendet
- Screen-Sharing endet → nächstes reloadAndReschedule → Event wird erneut evaluiert und ggf. angezeigt
- Event ist >5 Min nach Start wenn Screen-Sharing endet → wird nicht mehr angezeigt (5-Min-Fenster)
- Sound wird nicht abgespielt wenn silenced

**Verification:**
- HandlePendingEventsTests decken beide Pfade ab (screen-sharing + kein screen-sharing)
- Manuell: Screen-Sharing starten → Meeting starten → Notification statt Overlay → Screen-Sharing stoppen → Overlay erscheint wenn noch im 5-Min-Fenster

---

- [x] **Unit 3: Overlay Notification Observer Cleanup (Bug #4)**

**Goal:** Altert Overlay-Observer feuern nicht mehr wenn ein neues Overlay angezeigt wird.

**Requirements:** R4

**Dependencies:** None

**Files:**
- Modify: `Meeting Reminder/Views/AlertOverlayView.swift`
- Modify: `Meeting Reminder/Views/OverlayController.swift`
- Test: `Meeting ReminderTests/MeetingReminderTests.swift`

**Approach:**

1. **OverlayController wird NSWindowDelegate**: Implementiere `windowWillClose(_:)`:
   - Postet `Notification.Name("overlayCleanup")` vor dem Close
   - Setzt `panel = nil` nach dem Close

2. **AlertOverlayView Subscriptions**:
   - Neue `@State private var cancellables = Set<AnyCancellable>()`
   - `.onReceive` Handler ersetzen durch `.sink` in `.onAppear`, gespeichert in `cancellables`
   - Bei `overlayCleanup`-Notification: `cancellables.removeAll()`

3. **Flow**: OverlayController.show() → dismiss() → panel.close() → windowWillClose posts overlayCleanup → AlertOverlayView cancellt Subscriptions → neues Panel erstellt

**Warum NSWindowDelegate statt .onDisappear** (Qwen/DeepSeek): `NSPanel.close()` deallociert das NSHostingView asynchron. `.onDisappear` kann auf deallokierte Referenzen zugreifen → EXC_BAD_ACCESS. `windowWillClose` feuert deterministisch VOR dem Close.

**Test scenarios:**
- Overlay A anzeigen → Dismiss → Overlay B anzeigen → Escape → nur onDismiss_B feuert (nicht A)
- Overlay A anzeigen → Snooze → Overlay B zeigt sich nach Snooze-Timer → Escape → korrekter Dismiss

**Verification:**
- Kein Double-Dismiss bei aufeinanderfolgenden Overlays
- `xcodebuild test` grün

---

- [x] **Unit 4: Test Isolation Fixes (Bug #7)**

**Goal:** Tests mutieren keine Singleton-States die andere Tests beeinflussen.

**Requirements:** R7

**Dependencies:** Unit 1, Unit 2 (neue APIs müssen existieren)

**Files:**
- Modify: `Meeting ReminderTests/MeetingReminderTests.swift`

**Approach:**

1. **`tearDown()`** in `HandlePendingEventsTests` hinzufügen:
   - `calendarService.silentWhenScreenSharing` auf Default-Wert (`true`) zurücksetzen
   - `calendarService.soundEnabled` auf Default-Wert (`false`) zurücksetzen
   - `overlayController.dismiss()` aufrufen (Cleanup falls Panel offen)
   - `calendarService.pendingEvents = []` zurücksetzen
   - `calendarService.snoozeUntil = [:]` zurücksetzen
   - `calendarService.silencedEvents = []` zurücksetzen

2. **Reihenfolge-Unabhängigkeit**: Verifizieren dass Tests in beliebiger Reihenfolge grün sind

3. **Default-Werte dokumentieren**: Kommentar im tearDown welche Defaults erwartet werden

---

- [x] **Unit 6: Documentation Update (Bug #8)**

**Goal:** CLAUDE.md und AGENTS.md spiegeln den tatsächlichen Code-Stand wider.

**Requirements:** R8

**Dependencies:** Unit 1-4 (sodoc alle Code-Changes zuerst passieren)

**Files:**
- Modify: `CLAUDE.md`
- Modify: `AGENTS.md`

**Approach:**

1. **Entfernen**: Alle Referenzen auf StoreKitService, ReminderCounter, PaywallView, NevLate.storekit, Freemium-Architektur, Subscription Group, Product IDs, `enabledProviders`
2. **Aktualisieren**: Dateianzahl (11 Swift-Dateien, nicht 16), Quellcode-Struktur (aktuelle Dateien), Architektur-Beschreibung (ohne Freemium)
3. **Korrigieren**: Menüleisten-Icon → Custom Path-Drawing (HeadsetClockMark) statt SF Symbols
4. **Entfernen**: "Provider-Filter" Feature (gibt es nicht mehr)
5. **Aktualisieren**: Einstellungen-Sektion (ohne Provider-Filter, ohne Paywall)
6. **Aktualisieren**: Tech Stack Tabelle (StoreKit entfernen)
7. **Aktualisieren**: Nächste Schritte (Freemium-Entfernung als done markieren)
8. **compound-engineering.local.md**: Review Context aktualisieren falls nötig

**Verification:**
- Keine Referenz auf `StoreKitService`, `ReminderCounter`, `PaywallView`, `enabledProviders` in CLAUDE.md
- Dateiliste stimmt mit `find Meeting\ Reminder -name "*.swift"` überein

---

- [x] **Unit 7: Privacy Manifest Ergänzung (Bug #9)**

**Goal:** `NSPrivacyAccessedAPICategoryScreenCapture` wird deklariert.

**Requirements:** R9

**Dependencies:** None

**Files:**
- Modify: `Meeting Reminder/PrivacyInfo.xcprivacy`

**Approach:**

1. **Neuen Dict-Block** hinzufügen im `NSPrivacyAccessedAPITypes` Array:
   - `NSPrivacyAccessedAPIType`: `NSPrivacyAccessedAPICategoryScreenCapture`
   - `NSPrivacyAccessedAPITypeReasons`: `["CA96.1"]` (Window listing for screen sharing detection — user-facing feature)

2. **Reason Code CA96.1**: "The app declares this API usage to detect when screen sharing is active, in order to suppress the full-screen overlay and show a discreet notification instead. This protects the user's privacy during presentations."

**Verification:**
- `PrivacyInfo.xcprivacy` enthält `NSPrivacyAccessedAPICategoryScreenCapture`
- Build ohne Privacy-Warnings

## System-Wide Impact

- **Interaction graph**: `CalendarService.reloadAndReschedule()` ist der zentrale Coordinator — alle Observer und User-Aktionen konvergieren hier. Snooze wird jetzt deklarativ über Timestamps statt über Timer verwaltet.
- **Error propagation**: Fallback-Timer und Wake-Handler fangen Fehler via `Task { @MainActor }` — keine Error-Propagation nach außen. Das bleibt unverändert.
- **State lifecycle risks**: Vier State-Container (`pendingEvents`, `dismissedEvents`, `snoozeUntil`, `silencedEvents`) werden konsistent in `reloadAndReschedule()` verwaltet. `dismissedEvents` hat 2h Retention, `silencedEvents` wird bei jedem Reload geleert, `snoozeUntil` wird bei Ablauf automatisch entfernt.
- **API surface parity**: `AppIntents` greift auf `CalendarService.shared.nextEvent` und `todayEvents` zu — Unit 1 stellt sicher dass `nextEvent` nach jeder State-Mutation aktuell ist.

## Risks & Dependencies

- **Regression Risk**: CalendarService hat 36 Tests, aber die meisten testen nur statische Helper. Die Instanz-Methoden sind kaum getestet. **Mitigation**: Neue statische Methoden für alle neuen Logik.
- **Snooze-Latenz**: Ohne dedizierten Snooze-Timer hängt die Snooze-Wiedervorlage vom nächsten `reloadAndReschedule()`-Aufruf ab (Fallback: 30 Min, Wake, EKEventStoreChanged). Worst Case: Event wird erst nach 30 Min nach Snooze-Ablauf wieder angezeigt. **Mitigation**: `scheduleTimer()` kann einen Timer für das nächste `snoozeUntil`-Ablaufdatum setzen.
- **Merge-Logik Komplexität**: Die `mergePendingWithRunning` Methode muss korrekt deduplizieren. Die bestehende `compareEvents` statische Methode wird für die Sortierung genutzt.
- **Screen-Sharing Notification-Spam**: Bei jedem `reloadAndReschedule()` während Screen-Sharing wird eine neue Notification gesendet. **Akzeptabel**: Max 1 pro 30 Min (Fallback), plus bei Calendar-Changes.
- **Fallback-Timer bei Sleep**: Der 30-Min-Fallback-Timer wird bei Sleep nicht invalidiert (nur `alertTimer`). Das ist korrekt — er feuert nach Wake was `reloadAndReschedule()` auslöst. (DeepSeek wies darauf hin — bereits korrekt im Code)

## External Review Notes

Plan wurde nach Erstentwurf von **Qwen 3.6 Plus** und **DeepSeek V3.2** via OpenRouter reviewed. Wichtigste Änderungen:

| Kritikpunkt | Original | Geändert zu |
|-------------|----------|-------------|
| Snooze-Management | `[String: Timer]` mit Sleep-Invalidierung | `snoozeUntil: [String: Date]` — deklarativ, kein Timer |
| Overlay-Cleanup | `.onDisappear` in SwiftUI View | `NSWindowDelegate.windowWillClose` in OverlayController |
| nextEvent Update | Imperativ in jeder Mutation | Automatisch via `reloadAndReschedule()` |
| Screen-Sharing Bounce | Nicht adressiert | `silencedEvents` Set mit Reload-Cleanup |
| Unit-Struktur | 7 separate Units | Bug #6 in Unit 1 integriert, Tests zusammengefasst |

## Documentation / Operational Notes

- **Nach dem Fix**: CLAUDE.md und AGENTS.md sind die Single Source of Truth
- **App Store**: Privacy Manifest muss vor dem nächsten Update stimmen
- **Manuelle Tests**: Sleep/Wake-Szenarien auf echtem MacBook testen (nicht nur Build)
- **Version Bump**: `CURRENT_PROJECT_VERSION` in `project.yml` inkrementieren

## Sources & References

- **Exhaustive Code Review** (2026-04-10): 5 Review Agents, 45 Findings
- **Vorherige Plans**: `docs/plans/2026-03-24-002-fix-code-review-issues-privacy-tests-security-plan.md`
- **Bekannte Issues**: `.context/compound-engineering/todos/005-resolved-p2-snooze-race-condition.md`, `012-resolved-p2-schedule-timer-misses-concurrent-events.md`
- **Codebase**: `compound-engineering.local.md` bestätigt Freemium-Entfernung

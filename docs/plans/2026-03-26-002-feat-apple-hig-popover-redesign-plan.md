---
title: "feat: Apple-HIG-konformes Popover-Redesign + Code-Review-Fixes"
type: feat
status: completed
date: 2026-03-26
---

# Apple-HIG-konformes Popover-Redesign + Code-Review-Fixes

## Overview

Das Menüleisten-Popover wirkt nicht wie eine native Apple-App: niedrige Kontraste im Dark Mode, vergangene Meetings visuell nicht von zukünftigen unterscheidbar, Provider-Icons zu klein, Namensinkonsistenz. Gleichzeitig hat das Code Review 11 Findings identifiziert (1x P1-Bug, 6x P2, 4x P3).

Dieser Plan kombiniert das visuelle Redesign nach Apple HIG mit den wichtigsten Review-Fixes — alles mit dem Ziel: **besser und minimalistischer**.

## Problem Frame

Screenshot-Analyse zeigt konkret:
1. Alle Meeting-Zeilen wirken gleich gedimmt — kein klares "jetzt" oder "als nächstes"
2. Uhrzeiten und Titel haben zu wenig Kontrast gegen den dunklen macOS-Hintergrund
3. Kalender-Farbbalken (3px auf dunklem Grund) ist kaum sichtbar
4. Provider-Icons (10px) sind zu klein um Informationswert zu haben
5. "Beenden" in Rot suggeriert Gefahr statt Standard-Aktion
6. About-Section zeigt "QuickJoin" statt "Nevr Late"
7. Status "Keine anstehenden Meetings" + gleichzeitige Meeting-Liste = widersprüchlich (Fix aus Plan 001 bereits committed)

Code-Review-Bug: "Später erinnern" Button ruft `onDismiss` statt `onSnooze` auf.

## Requirements Trace

- R1. Popover-Design folgt Apple HIG: native Kontraste, korrektes Dark/Light Mode, systemkonforme Typographie
- R2. Visuelles Zeitmanagement: vergangene Meetings deutlich zurückgesetzt, aktuelles hervorgehoben, zukünftige klar sichtbar
- R3. Snooze-Bug (#011) gefixt — kein Button der "erinnern" sagt aber permanent dismissed
- R4. Dead Code entfernt (#014) — extractURL, dismissKey, decodeEnabledCalendarIDs, hasLaunchedBefore
- R5. Duplizierte Meeting-Öffnen-Logik konsolidiert (#015)
- R6. Provider-Filter entfernt (#016) — YAGNI, 50 LOC weniger, einfacheres Settings-UI
- R7. DateFormatter gecacht (#021) — keine Inline-Allokation jede Sekunde
- R8. App minimalistisch halten — weniger UI-Elemente, nicht mehr

## Scope Boundaries

- **Kein** neues Feature (App Intents, URL Scheme) — das ist ein separater Plan
- **Kein** Timer-Refactoring (#012) — erfordert tiefere Änderungen, separater Plan
- **Kein** neue-Kalender-Bug (#013) — separater Fix
- **Keine** Deep-Link-Sanitization (#017) — separater Security-Fix
- **Keine** neuen Test-Dateien — Test-Coverage (#020) ist ein separater Plan
- **Kein** Accessibility-Audit (#019) — separater Plan

## Context & Research

### Relevant Code and Patterns

- `SettingsView.swift`: 363 Zeilen, 320pt Breite, 7 Sektionen, konsistente 16pt horizontale Padding
- `TodayMeetingsView.swift`: 119 Zeilen, 28pt Zeilenhöhe, 3 Event-Status (past/current/future)
- `AlertOverlayView.swift`: 320 Zeilen, 440pt Card, Liquid Glass, snoozeSection mit Bug
- `CalendarService.swift`: enabledProviders Set<String> (50 LOC zu entfernen)
- `MeetingLinkExtractor.swift`: extractURL (dead code), deepLinkURL (dupliziert in TodayMeetingsView)
- `MeetingReminderApp.swift`: openMeetingDirectly (Duplikat), hasLaunchedBefore (dead)

### Apple HIG Design-Prinzipien für Menüleisten-Popovers

- **Systemfarben verwenden**: `.primary`, `.secondary`, `.tertiary` passen sich automatisch an Dark/Light Mode an
- **SF Symbols** in konsistenten Größen (nicht unter 12pt für Informationswert)
- **Vibrancy**: macOS Material-Backgrounds für native Transparenz
- **Compact aber lesbar**: 11-13pt für kompakte Listen, nie unter 11pt
- **Kein Rot für Standard-Aktionen**: `.red` nur für destruktive Aktionen (Apple HIG), Quit ist Standard
- **Klare visuelle Hierarchie**: Aktives/nächstes Element deutlich hervorgehoben, vergangenes dezent

## Key Technical Decisions

- **Provider-Filter komplett entfernen statt reparieren**: Kein User-Szenario rechtfertigt selektives Provider-Deaktivieren. "Nur Online-Meetings" deckt den echten Use Case ab. ~50 LOC weniger.
- **Snooze-Section auf einen Button reduzieren**: "Schließen" ist der Dismiss, "In 1 Min. erinnern" ist der Snooze. Kein zweiter Button mit irreführendem Label.
- **Meeting-Open-Logik als statische Methode auf MeetingLinkExtractor**: Passt thematisch, eine einzige Callsite-Änderung pro Datei.
- **TodayMeetingsView Redesign nach Apple-Kalender-App-Vorbild**: Vergangene Meetings deutlich gedimmt (opacity 0.35), aktuelles mit Kalenderfarbe-Akzent und "Jetzt"-Label, zukünftige in voller `.primary`-Farbe.
- **Kalender-Farbbalken dicker machen**: 3px → 4px, und auf hellem/dunklem Hintergrund sichtbar dank leichtem Glow/Border.
- **"QuickJoin" → "Nevr Late"** in About-Section korrigieren.

## High-Level Technical Design

> *Directional guidance, not implementation specification.*

### Popover Visual Hierarchy (TodayMeetingsView)

```
VERGANGEN (opacity 0.35, kein Hover-Effekt):
│  14:00  BA PUB Services Reviews: KIWI
│  15:00  BA PUB Services Reviews: Health

AKTUELL (Kalenderfarbe-Hintergrund 0.15, "Jetzt"-Badge):
│▌ 16:30  Finalisierung_Partnervertrag   🟢 Jetzt   📹

ZUKÜNFTIG (volle Opazität, Hover-Highlight):
│  17:00  BA PUB Services Reviews: ahs
│  18:00  Anlieferung Pizzeria Marco
```

### Snooze-Section (AlertOverlayView)

```
VORHER:
  [Schließen]
  Später erinnern | In 1 Minute erneut erinnern    ← BUG + redundant

NACHHER:
  [Schließen]
  [In 1 Min. erinnern]                              ← ein klarer Snooze-Link
```

## Implementation Units

- [x] **Unit 1: Snooze-Bug fixen + Snooze-Section vereinfachen**

**Goal:** P1-Bug (#011) fixen. Snooze-Section von 2 Buttons auf 1 reduzieren.

**Requirements:** R3, R8

**Dependencies:** Keine

**Files:**
- Modify: `Meeting Reminder/Views/AlertOverlayView.swift`

**Approach:**
- `snoozeSection`: "Später erinnern" Button und "|" Separator entfernen
- Nur "In 1 Min. erinnern" behalten, `onSnooze` Aktion
- Label vereinfachen zu "In 1 Min. erinnern" (ohne "erneut")

**Patterns to follow:**
- Bestehender Button-Stil in snoozeSection

**Test scenarios:**
- Space-Taste im Overlay löst Snooze aus (bestehend, funktioniert über OverlayPanel)
- Kein zweiter dismiss-ähnlicher Button mehr vorhanden

**Verification:**
- "Später erinnern" Button existiert nicht mehr
- Snooze-Button ruft onSnooze auf
- Build grün

---

- [x] **Unit 2: Provider-Filter entfernen (YAGNI)**

**Goal:** enabledProviders Set, Persistenz, Filter-Logik und Settings-UI entfernen (#016).

**Requirements:** R6, R8

**Dependencies:** Keine

**Files:**
- Modify: `Meeting Reminder/Services/CalendarService.swift`
- Modify: `Meeting Reminder/Views/SettingsView.swift`

**Approach:**
- `CalendarService`: `enabledProviders` Property + `didSet` + UserDefaults-Code entfernen
- `CalendarService.isRelevant()`: Provider-Filter-Block (Zeile 337-340) entfernen
- `SettingsView`: gesamte `providerSection` entfernen (Zeilen 148-182)
- UserDefaults-Key "enabledProviders" wird einfach ignoriert (kein Migration nötig)

**Test scenarios:**
- Events aller 8 Provider lösen Reminder aus ohne Konfiguration
- Settings-UI hat keine Provider-Toggles mehr
- Bestehende Tests weiterhin grün (keine Tests testen Provider-Filter direkt)

**Verification:**
- ~50 LOC weniger
- Build + alle Tests grün
- Settings-Popover hat 4 statt 5 Sektionen

---

- [x] **Unit 3: Dead Code entfernen**

**Goal:** extractURL, dismissKey, decodeEnabledCalendarIDs, hasLaunchedBefore entfernen (#014).

**Requirements:** R4

**Dependencies:** Keine

**Files:**
- Modify: `Meeting Reminder/Services/MeetingLinkExtractor.swift`
- Modify: `Meeting Reminder/Services/CalendarService.swift`
- Modify: `Meeting Reminder/MeetingReminderApp.swift`
- Modify: `Meeting ReminderTests/CalendarServiceTests.swift`
- Modify: `Meeting ReminderTests/MeetingLinkExtractorTests.swift`

**Approach:**
- `MeetingLinkExtractor`: `extractURL` Methode löschen
- `CalendarService`: `dismissKey(for:)` und `decodeEnabledCalendarIDs(from:)` static Methoden löschen
- `CalendarService`: `hasLaunchedBefore` @AppStorage Property löschen
- `MeetingReminderApp`: `hasLaunchedBefore`-Setzung in applicationDidFinishLaunching löschen
- Tests: Referenzen auf gelöschte Methoden aktualisieren (event.id statt dismissKey, etc.)

**Test scenarios:**
- Alle bestehenden Tests grün (nach Anpassung)
- Keine Referenzen auf gelöschte Methoden mehr im Projekt

**Verification:**
- ~14 LOC Source + ~25 LOC Tests weniger
- Build + Tests grün

---

- [x] **Unit 4: Meeting-Öffnen-Logik konsolidieren**

**Goal:** Duplizierte Deep-Link-mit-Fallback-Logik in eine einzige Methode extrahieren (#015).

**Requirements:** R5

**Dependencies:** Unit 3 (extractURL entfernt, Methode wird an gleicher Stelle hinzugefügt)

**Files:**
- Modify: `Meeting Reminder/Services/MeetingLinkExtractor.swift`
- Modify: `Meeting Reminder/MeetingReminderApp.swift`
- Modify: `Meeting Reminder/Views/TodayMeetingsView.swift`

**Approach:**
- Neue statische Methode `MeetingLinkExtractor.open(_ meetingLink: MeetingLink)` die:
  - Deep-Link URL erzeugt
  - Prüft ob native App installiert ist
  - Deep-Link oder HTTPS-Fallback öffnet
- `MeetingAppDelegate.openMeetingDirectly` delegiert an neue Methode (oder wird entfernt)
- `TodayMeetingsView.handleTap` delegiert an neue Methode

**Test scenarios:**
- Klick auf Meeting-Zeile in Today → öffnet Meeting (funktional unverändert)
- Cmd+Shift+J → öffnet nächstes Meeting (funktional unverändert)
- Overlay Join-Button → öffnet Meeting (funktional unverändert)

**Verification:**
- Eine einzige Definition der Öffnen-Logik
- Build grün

---

- [x] **Unit 5: DateFormatter cachen**

**Goal:** Inline DateFormatter-Allokation in AlertOverlayView durch static let ersetzen (#021).

**Requirements:** R7

**Dependencies:** Keine

**Files:**
- Modify: `Meeting Reminder/Views/AlertOverlayView.swift`

**Approach:**
- Zwei `private static let` DateFormatter auf AlertOverlayView-Ebene
- `timeRange` Computed Property nutzt die gecachten Formatter

**Verification:**
- Build grün
- timeRange zeigt identisches Format

---

- [x] **Unit 6: TodayMeetingsView — Apple-HIG-Redesign**

**Goal:** Visuelle Hierarchie nach Apple-Kalender-Vorbild: vergangene Meetings deutlich gedimmt, aktuelles hervorgehoben mit "Jetzt"-Badge, zukünftige klar lesbar.

**Requirements:** R1, R2

**Dependencies:** Unit 2 (Provider-Filter entfernt → Provider-Icon kann größer dargestellt werden)

**Files:**
- Modify: `Meeting Reminder/Views/TodayMeetingsView.swift`

**Approach:**

**Vergangene Meetings:**
- Opacity 0.35 (statt 0.4) — deutlicher gedimmt
- Nicht klickbar, kein Hover-Effekt
- Durchgestrichene oder ausgegraute Zeitanzeige
- Kein Provider-Icon (spart Platz, Info irrelevant für vergangene Events)

**Aktuelles/laufendes Meeting:**
- Kalender-Farbbalken: 4px breit (statt 3px), volle Sättigung
- Hintergrund: Kalenderfarbe mit 0.12 Opacity (statt 0.1) — minimal stärker
- "Jetzt"-Badge: kleine Capsule in `.green` neben der Uhrzeit
- Titel in `.semibold` (bereits implementiert)
- Provider-Icon in 12pt (statt 10pt) mit vollem Kontrast

**Zukünftige Meetings:**
- Volle `.primary` Textfarbe (nicht `.secondary`)
- Kalender-Farbbalken: 4px, volle Farbe
- Provider-Icon in 12pt, `.secondary` Farbe
- Hover-Highlight für klickbare Meetings

**Allgemein:**
- Uhrzeiten: `.monospacedDigit()` + `.secondary` (statt `.tertiary` für vergangene)
- Titel: `.primary` für aktuelle+zukünftige (statt nur `.primary` für zukünftige)
- `AnyShapeStyle` durch direkte `Color`-Conditional ersetzen (Simplification)

**Patterns to follow:**
- Apple Kalender-App Sidebar-Design
- Apple Erinnerungen-App Listendarstellung

**Test scenarios:**
- Meeting vor 2h → stark gedimmt, kein Provider-Icon
- Meeting läuft gerade → hervorgehoben mit "Jetzt"-Badge
- Meeting in 1h → volle Sichtbarkeit, klickbar
- Kein Meeting heute → "Keine Meetings heute" Meldung

**Verification:**
- Visuell: Klare 3-Stufen-Hierarchie (vergangen/aktuell/zukünftig) im Dark Mode sichtbar
- Build grün

---

- [x] **Unit 7: SettingsView — Design-Polish + Namensfix**

**Goal:** Konsistentes Apple-HIG-Design, "QuickJoin" → "Nevr Late" korrigieren, "Beenden" nicht mehr rot.

**Requirements:** R1, R8

**Dependencies:** Unit 2 (Provider-Section entfernt), Unit 6 (TodayMeetingsView Design-Sprache)

**Files:**
- Modify: `Meeting Reminder/Views/SettingsView.swift`

**Approach:**

**About-Section:**
- "QuickJoin" → "Nevr Late" (Zeile 263) — Namenskorrektur
- Copyright bleibt "© 2026 Grüpi GmbH"

**Beenden-Button:**
- `.foregroundStyle(.red)` → `.foregroundStyle(.secondary)` — kein Rot für Standard-Aktion
- Evtl. dezenter Hover-Effekt statt roter Farbe

**Status-Section Verfeinerung:**
- Wenn nächstes Meeting ein laufendes ist: "Jetzt"-Indikator auch hier (konsistent mit TodayMeetingsView)
- Zeitanzeige: relative Zeit ergänzen (z.B. "in 25 Min." neben absoluter Zeit)

**Kalender-Section:**
- Kalender-Farbkreise: 10px (statt 8px) für bessere Sichtbarkeit im Dark Mode
- Toggle-Labels: dezenter `.secondary`-Ton (nicht zu dominant)

**Einstellungen-Section:**
- Stepper-Design beibehalten (funktioniert gut)
- Help-Tooltips beibehalten

**Patterns to follow:**
- Apple Systemeinstellungen-Style für Toggles
- Apple Menüleisten-Apps (z.B. Bluetooth, WiFi) für Status-Design

**Test scenarios:**
- About-Section zeigt "Nevr Late" (nicht "QuickJoin")
- Beenden-Button ist nicht rot
- Status zeigt laufendes Meeting mit Zeitindikator

**Verification:**
- Visuell: Popover wirkt wie eine native Apple Menüleisten-App
- Namenskorrektur in About-Section
- Build grün

## System-Wide Impact

- **Interaction graph:** Provider-Filter-Entfernung betrifft CalendarService.isRelevant() → weniger Filterung → mehr Events triggern Reminders (gewünschtes Verhalten)
- **Error propagation:** Keine Änderung
- **State lifecycle:** enabledProviders UserDefaults-Key bleibt als Orphan (harmlos, wird beim nächsten Clean-Install aufgeräumt)
- **API surface parity:** MeetingLinkExtractor.open() wird neue zentrale Methode für Meeting-Öffnen
- **AlertOverlayView:** Snooze-Bug-Fix hat direkten Einfluss auf User-Experience (Meetings werden nicht mehr versehentlich dismissed)

## Risks & Dependencies

- **Dark Mode Kontraste:** macOS Popover-Background ist systemgesteuert. Unsere Farbanpassungen müssen in Light UND Dark Mode funktionieren. Semantic Colors (`.primary`, `.secondary`) lösen das automatisch — aber Kalenderfarben und der "Jetzt"-Badge müssen in beiden Modi getestet werden.
- **Provider-Filter-Entfernung:** User die bewusst Provider deaktiviert haben, verlieren diese Einstellung. Da das Feature wahrscheinlich nie benutzt wurde, ist das Risiko minimal.
- **MeetingLinkExtractor.open():** Muss auf @MainActor laufen wegen NSWorkspace.shared.open(). Die Methode sollte als `@MainActor static func` deklariert werden.

## Sources & References

- Code Review Findings: `.context/compound-engineering/todos/011-021`
- Apple HIG Menüleisten-Apps: https://developer.apple.com/design/human-interface-guidelines/the-menu-bar
- Bestehendes Overlay-Design: `docs/superpowers/specs/2026-03-20-meeting-reminder-design.md`
- Screenshot: `/var/folders/fs/838tsvjs7hq3tx3lx0r8yqy80000gp/T/TemporaryItems/NSIRD_screencaptureui_IahkMP/Bildschirmfoto 2026-03-26 um 22.49.52.png`

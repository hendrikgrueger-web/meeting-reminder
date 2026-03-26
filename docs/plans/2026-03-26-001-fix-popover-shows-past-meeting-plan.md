---
title: "fix: Popover/Menüleiste zeigt vergangene Meetings statt aktuelles/nächstes"
type: fix
status: active
date: 2026-03-26
---

# fix: Popover/Menüleiste zeigt vergangene Meetings statt aktuelles/nächstes

## Overview

`nextEvent` wird aus der Reminder-gefilterten Liste (`loadRelevantEvents`) abgeleitet — diese
hat ein 5-Minuten-Fenster nach Meetingstart, Provider-Filter, Online-Only-Filter und
Dismissed/Snoozed-Logik. Für die Statusanzeige (Popover, Menüleisten-Icon, Tooltip,
Cmd+Shift+J) ist das die falsche Quelle. Die richtige: `todayEvents`, das bereits alle
heutigen Events enthält (nur Kalender-Filter + keine ganztägigen).

**Fix: 2 Zeilen in `reloadAndReschedule()` ändern.** Keine neue Property, kein neuer Timer.

## Problem Frame

`nextEvent = events.first` (Zeile 195) nutzt `loadRelevantEvents` — gefiltert nach
Reminder-Relevanz (5-Min-Fenster, dismissed, snoozed, onlyOnlineMeetings, Provider-Filter).
Zwischen Timer-Fire-Zeitpunkten wird `nextEvent` nicht neu berechnet. Öffnet der User
das Popover nach Ablauf des 5-Min-Fensters, zeigt `nextEvent` entweder ein veraltetes
Meeting oder — nach Fallback-Timer — gar keines, obwohl laufende Meetings existieren.

Dasselbe gilt für `upcomingEventsCount` (Menüleisten-Badge), der ebenfalls aus der
gefilterten Liste zählt.

## Requirements

- R1. Status-Sektion, Menüleisten-Icon, Tooltip und Cmd+Shift+J zeigen das gerade
      laufende Meeting (startDate ≤ jetzt < endDate) ODER das nächste zukünftige
      Meeting heute — unabhängig von Reminder-Filtern
- R2. Menüleisten-Badge zählt alle anstehenden Meetings in den nächsten 60 Min,
      nicht nur Reminder-eligible
- R3. Reminder-Logik (pendingEvents, Timer-Scheduling) bleibt vollständig unverändert
- R4. Kein zusätzlicher Ressourcenverbrauch (kein neuer Timer, keine neue Property, kein onAppear-Reload)

## Scope

- Keine Änderung an `TodayMeetingsView` (zeigt bewusst alle Events inkl. vergangener)
- Keine Änderung an `loadRelevantEvents` oder `isRelevant` (Reminder-Logik)
- Keine neue Published Property

## Technische Entscheidungen

- **`todayEvents` als Quelle statt `loadRelevantEvents`:** `todayEvents` ist bereits nach
  aktivierten Kalendern gefiltert, schließt ganztägige Events aus, und ist chronologisch
  sortiert — exakt was die Statusanzeige braucht. Die Reminder-spezifischen Filter (5-Min-Fenster,
  dismissed, snoozed, onlyOnlineMeetings, Provider) gehören nicht in die Statusanzeige.
- **`endDate > now` statt `startDate`-basiert:** Ein laufendes Meeting hat `startDate ≤ now`
  aber `endDate > now`. Durch `first(where: { $0.endDate > now })` auf der chronologisch
  sortierten `todayEvents`-Liste wird automatisch das laufende Meeting bevorzugt
  (startDate < jetzt, kommt in Sortierung vor zukünftigen Events).
- **Kein `onAppear`-Refresh:** `reloadAndReschedule()` läuft alle 30 Min via Fallback-Timer,
  bei jedem Timer-Fire, bei Wake und bei Kalender-Änderungen. Das ist ausreichend. Ein
  `onAppear`-Refresh würde die Worst-Case-Staleness von ~30 Min auf ~0 Min reduzieren,
  aber der Kernbug (falsche Datenquelle) ist ohne `onAppear` gelöst. Kann als Follow-up
  ergänzt werden, wenn in der Praxis nötig.

## Implementation Units

- [ ] **Unit 1: `reloadAndReschedule()` — nextEvent und upcomingEventsCount aus todayEvents ableiten**

**Goal:** `nextEvent` und `upcomingEventsCount` aus `todayEvents` statt aus der
Reminder-gefilterten Liste berechnen.

**Requirements:** R1, R2, R3, R4

**Dependencies:** Keine

**Files:**
- Modify: `Meeting Reminder/Services/CalendarService.swift`
- Test: `Meeting ReminderTests/CalendarServiceTests.swift`

**Approach:**
- In `reloadAndReschedule()`, nach `todayEvents = loadTodayEvents(now: now)`:
  - `nextEvent` ableiten aus `todayEvents` gefiltert nach `endDate > now`, erstes Element
  - `upcomingEventsCount` ableiten aus `todayEvents` gefiltert nach `startDate > now`
    UND `startDate ≤ oneHourFromNow`
- Beide Zeilen ersetzen die bisherigen Zuweisungen, die `events` (= `loadRelevantEvents`) nutzten
- `events` (= `loadRelevantEvents`) wird weiterhin für `pendingEvents`, `runningEvents`
  und `scheduleTimer` genutzt — dort ist die Reminder-Filterung korrekt

**Patterns to follow:**
- Bestehende `todayEvents`-Berechnung in `reloadAndReschedule()`

**Test scenarios:**
- Meeting lief vor 2h (endDate vor 2h) → `nextEvent` überspringt es, zeigt nächstes
- Meeting läuft gerade (startDate vor 30min, endDate in 30min) → `nextEvent` zeigt es
- Nächstes Meeting in 3h → `nextEvent` zeigt es
- Kein Meeting mehr heute → `nextEvent` nil
- 2 Meetings in nächsten 60 Min → `upcomingEventsCount` = 2 (auch ohne Meeting-Link)
- Meeting ohne Meeting-Link in 30 Min → wird in `upcomingEventsCount` gezählt
  (vorher nicht, wenn `onlyOnlineMeetings` aktiv war)

**Verification:**
- Alle 153 bestehenden Tests grün
- Neue Tests für die beschriebenen Szenarien grün
- Manuell: App starten, Meeting verpassen, Popover öffnen → kein vergangenes Meeting in Status

## System-Wide Impact

- **`menuBarIconName`:** Profitiert — bell.badge.fill zeigt sich jetzt auch für laufende
  Meetings die keine Reminder-eligible Events wären (z.B. ohne Link bei onlyOnlineMeetings)
- **`menuBarTooltipText`:** Profitiert — zeigt "Meeting läuft: ..." korrekt
- **`handleShortcutEvent`:** Profitiert — Cmd+Shift+J öffnet auch laufende Meetings
- **`pendingEvents` / Overlay-Flow:** Kein Impact — nutzt weiterhin `loadRelevantEvents`
- **`TodayMeetingsView`:** Kein Impact — nutzt `todayEvents` direkt
- **`OverlayController` / `AlertOverlayView`:** Kein Impact

## Risiken

- **Staleness:** `nextEvent` wird nur bei `reloadAndReschedule()` aktualisiert (alle ~30 Min
  Fallback). Ein Meeting das gerade endet, kann bis zu 30 Min im Status stehen bleiben.
  Das ist akzeptabel und identisch zum bisherigen Verhalten. Follow-up: `onAppear`-Refresh
  auf SettingsView ergänzen, falls User sich beschwert.

## Abgewogene Alternativen

| Ansatz | Warum nicht gewählt |
|--------|-------------------|
| Neue `@Published var currentOrNextEvent` | Unnötige Property — `nextEvent` hat schon die richtige Semantik, nur die falsche Quelle |
| `onAppear { reloadAndReschedule() }` | Löst den Kernbug nicht (falsche Datenquelle), nur die Staleness. Als Follow-up sinnvoll |
| Computed Property auf View-Seite | Braucht eigenen Timer für Reaktivität, dupliziert Logik |
| `nextEvent` als computed var (nicht @Published) | SwiftUI-Reaktivität geht verloren bei Status-Übergängen |

## Sources & References

- `CalendarService.reloadAndReschedule()` — Zeile 174ff
- `CalendarService.loadTodayEvents()` — Zeile 258ff
- `CalendarService.loadRelevantEvents()` — Zeile 212ff
- `SettingsView.statusSection` — Zeile 55ff
- `MeetingReminderApp.menuBarIconName` — static Hilfsfunktion

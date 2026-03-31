---
status: resolved
priority: p2
issue_id: "012"
tags: [code-review, correctness, reliability]
dependencies: []
---

# scheduleTimer verpasst gleichzeitige Events + Wake-Recovery bricht Timer ab

## Problem Statement

Zwei zusammenhängende Bugs in CalendarService:

1. **scheduleTimer** (Zeile 356): Findet nur das erste zukünftige Event. Wenn mehrere Events bereits im Lead-Time-Fenster liegen, wird nur das erste als pending gesetzt. Für die restlichen wird kein Timer gesetzt.

2. **Running Events nach Wake** (Zeile 203-207): Wenn nach dem Aufwachen laufende Events erkannt werden, wird `return` aufgerufen — `scheduleTimer` wird nie aufgerufen. Zukünftige Events bekommen keinen Timer bis entweder (a) der User das Overlay dismissed oder (b) der 30-Min-Fallback-Timer feuert.

## Findings

- `CalendarService.swift:356`: `events.first(where:)` ignoriert weitere Events
- `CalendarService.swift:203-207`: Early return nach Running-Events-Erkennung
- `CalendarService.swift:363`: Nur ein Event wird zu pendingEvents hinzugefügt
- Worst Case: Zwei Meetings starten gleichzeitig, nur eines wird angezeigt, das andere erst nach 30 Min Fallback

## Proposed Solutions

### Option A: Alle Events im Lead-Time-Fenster sammeln + Timer für nächstes danach
- In `scheduleTimer`: Alle Events sammeln deren `fireDate <= now`, alle zu pendingEvents
- Timer auf das erste Event setzen dessen `fireDate > now`
- Nach Running-Events: trotzdem `scheduleTimer` aufrufen
- **Effort:** Medium
- **Risk:** Low

## Acceptance Criteria

- [ ] Zwei gleichzeitige Events im Lead-Time-Fenster → beide in pendingEvents
- [ ] Nach Wake mit laufendem Event → Timer für nächstes zukünftiges Event gesetzt
- [ ] Tests für Multi-Event-Szenarien

## Work Log

| Datum | Aktion |
|-------|--------|
| 2026-03-26 | Finding erstellt via Code Review |

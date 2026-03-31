---
status: resolved
priority: p1
issue_id: "011"
tags: [code-review, correctness, bug, ux]
dependencies: []
---

# "Später erinnern" Button ruft onDismiss statt onSnooze auf

## Problem Statement

In `AlertOverlayView.swift:278` ruft der Button "Später erinnern" `onDismiss` auf statt `onSnooze`. Das bedeutet: Wenn ein User auf "Später erinnern" klickt, wird das Event **permanent dismissed** (2h TTL im dismissedEvents-Set) statt gesnoozed.

Der User denkt, er wird später erinnert — tatsächlich verpasst er das Meeting.

Zusätzlich: "Schließen" (Zeile 257) tut exakt dasselbe wie "Später erinnern" — es gibt zwei Buttons mit identischem Verhalten aber unterschiedlicher Beschriftung.

**Gefunden von:** correctness-reviewer, maintainability-reviewer, simplicity-reviewer (alle 3 unabhängig)

## Findings

- `AlertOverlayView.swift:278`: `Button(action: onDismiss)` mit Label "Später erinnern"
- `AlertOverlayView.swift:289`: `Button(action: onSnooze)` mit Label "In 1 Minute erneut erinnern"
- `AlertOverlayView.swift:257`: `Button(action: onDismiss)` mit Label "Schließen"
- Der Snooze-Flow (CalendarService.snoozeEvent) wird durch "Später erinnern" nie ausgelöst

## Proposed Solutions

### Option A: "Später erinnern" auf onSnooze verdrahten (empfohlen)
- `Button(action: onDismiss)` → `Button(action: onSnooze)` in Zeile 278
- Beide Snooze-Buttons behalten (verschiedene Labels, gleiche Aktion)
- **Pro:** Minimaler Fix, kein UI-Redesign
- **Contra:** Zwei Buttons für die gleiche Aktion (Snooze) + ein Dismiss-Button — etwas redundant
- **Effort:** Small
- **Risk:** Low

### Option B: Snooze-Section vereinfachen (sauberer)
- "Später erinnern" entfernen
- Nur "In 1 Minute erneut erinnern" als Snooze behalten
- "Schließen" bleibt der einzige Dismiss-Button
- **Pro:** Cleaner UI, weniger Verwirrung, ~8 LOC weniger
- **Contra:** Minimaler UI-Umbau
- **Effort:** Small
- **Risk:** Low

## Recommended Action

Option B — Section vereinfachen. Der Separator "|" und der redundante Button machen die UI unübersichtlich.

## Technical Details

- **Affected files:** `Meeting Reminder/Views/AlertOverlayView.swift`
- **Lines:** 276-298 (snoozeSection)

## Acceptance Criteria

- [ ] "Schließen" = permanent dismiss
- [ ] Snooze-Aktion = 1 Minute warten, dann erneut erinnern
- [ ] Kein Button mit irreführendem Label
- [ ] Test: Snooze-Button ruft calendarService.snoozeEvent auf (nicht dismissEvent)

## Work Log

| Datum | Aktion |
|-------|--------|
| 2026-03-26 | Finding erstellt via Code Review |

## Resources

- AlertOverlayView.swift:276-298
- CalendarService.snoozeEvent (Zeile 388)

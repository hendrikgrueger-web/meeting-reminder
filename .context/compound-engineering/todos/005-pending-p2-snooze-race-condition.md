---
status: pending
priority: p2
issue_id: "005"
tags: [code-review, correctness, concurrency]
---

# Race Condition: snoozeEvent + reloadAndReschedule → doppelter Overlay

## Problem Statement
Wenn `snoozeEvent` einen 60-Sekunden-Timer startet und in diesem Fenster `reloadAndReschedule` feuert (via 30-Min-Fallback, Wake-Notification oder EKEventStoreChanged), kann dasselbe Event doppelt in `pendingEvents` landen. Das führt zu einem zweiten Overlay über dem ersten.

## Findings
- **File:** `Meeting Reminder/Services/CalendarService.swift:393-408`
- Konkrete Race-Sequenz:
  1. `snoozeEvent` → Event aus `pendingEvents` entfernt, 60-Sek-Timer startet
  2. `reloadAndReschedule` → setzt `pendingEvents = [event]` (laufendes Meeting) → erster Overlay erscheint
  3. Snooze-Timer feuert → `pendingEvents.append(event)` → zweiter Overlay über dem ersten
- Gefunden von correctness-reviewer

## Proposed Solutions

### Option A: Guard-Check vor append im Snooze-Timer
```swift
// In snooze-Timer-Closure:
if !self.pendingEvents.contains(where: { $0.id == event.id }) {
    self.pendingEvents.append(event)
}
```

**Effort:** Small | **Risk:** Low

### Option B: snoozedEvents Set prüfen in reloadAndReschedule
Filtere beim Reload Events heraus, die in `snoozedEvents` sind — dann können sie gar nicht in `pendingEvents` landen während der Snooze-Periode läuft.

**Effort:** Small | **Risk:** Low

## Acceptance Criteria
- [ ] Test: `snoozeEvent` → `reloadAndReschedule` → Snooze-Timer → `pendingEvents.count == 1` (nicht 2)
- [ ] Kein doppelter Overlay in der Praxis
- [ ] Alle 153 bestehenden Tests weiterhin grün

## Work Log
- 2026-03-24: Gefunden bei Code Review (ce-review), correctness-reviewer Agent

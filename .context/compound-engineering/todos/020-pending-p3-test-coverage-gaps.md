---
status: pending
priority: p3
issue_id: "020"
tags: [code-review, testing]
dependencies: ["012"]
---

# Test-Coverage-Lücken schließen: Snooze, Wake, Provider-Filter

## Problem Statement

Mehrere kritische Code-Pfade haben null Test-Coverage:

1. **Snooze-Flow** (CalendarService.snoozeEvent Timer-Callback) — Entscheidungslogik ob Event nach Snooze erneut angezeigt wird
2. **Wake-Recovery** (reloadAndReschedule Zeile 203-207) — Running-Events-Erkennung nach Sleep
3. **Provider-Filter** (isRelevant Zeile 333-349) — snoozed + enabledProviders Checks
4. **scheduleTimer Immediate-Fire** (Zeile 361-364) — Event bereits im Lead-Time-Fenster
5. **False-Confidence Test** (testEmptyEvents_dismissesOverlay) — testet Initial-State statt Transition

## Proposed Solutions

- Snooze/Wake/Timer-Logik als static Methoden extrahieren (wie isEventRelevant)
- Unit Tests für alle Branches
- False-Confidence Test fixen (erst show(), dann dismiss(), dann assert)
- **Effort:** Medium
- **Risk:** Low

## Acceptance Criteria

- [ ] Snooze-Callback Branches getestet (>5min, dismissed, already pending)
- [ ] Wake-Recovery getestet (running event erkannt, dismissed event ignoriert)
- [ ] Provider-Filter getestet
- [ ] testEmptyEvents_dismissesOverlay prüft echte State-Transition

## Work Log

| Datum | Aktion |
|-------|--------|
| 2026-03-26 | Finding erstellt via Code Review |

---
status: resolved
priority: p2
issue_id: "014"
tags: [code-review, simplicity, dead-code]
dependencies: []
---

# Dead Code entfernen: extractURL, dismissKey, decodeEnabledCalendarIDs, hasLaunchedBefore

## Problem Statement

4 Code-Stellen die keinen Zweck erfüllen:

1. **`extractURL`** (MeetingLinkExtractor.swift:120-123) — "Abwärtskompatibilität" Wrapper, wird nirgends aufgerufen
2. **`dismissKey(for:)`** (CalendarService.swift:314-316) — gibt nur `event.id` zurück, reine Indirektion
3. **`decodeEnabledCalendarIDs(from:)`** (CalendarService.swift:329-331) — wraps JSONDecoder, nur in Tests benutzt
4. **`hasLaunchedBefore`** (CalendarService.swift:29 + MeetingReminderApp.swift:147-149) — wird gesetzt aber nie gelesen

## Proposed Solutions

- Alle 4 entfernen + zugehörige Tests anpassen
- ~14 LOC Source + ~25 LOC Tests
- **Effort:** Small
- **Risk:** None

## Acceptance Criteria

- [ ] Alle 4 Dead-Code-Stellen entfernt
- [ ] Tests angepasst (event.id statt dismissKey, etc.)
- [ ] Build + Tests grün

## Work Log

| Datum | Aktion |
|-------|--------|
| 2026-03-26 | Finding erstellt via Code Review |

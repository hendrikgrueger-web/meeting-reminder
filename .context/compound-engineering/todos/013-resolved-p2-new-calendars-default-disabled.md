---
status: resolved
priority: p2
issue_id: "013"
tags: [code-review, correctness, ux]
dependencies: []
---

# Neue Kalender werden nach erster Einstellungsänderung standardmäßig deaktiviert

## Problem Statement

`enabledCalendarIDs` Getter (CalendarService.swift:82-84) gibt bei leerem/ungültigem Data alle Kalender zurück. Sobald der User einen Kalender deaktiviert, werden nur die verbleibenden IDs gespeichert. Neue Kalender (z.B. Abo eines Team-Kalenders) erscheinen danach als deaktiviert — Meetings aus neuen Kalendern werden still ignoriert.

## Proposed Solutions

### Option A: Neue Kalender automatisch aktivieren
- Beim Laden: gespeicherte IDs + alle unbekannten Kalender-IDs (die nicht in einer "bekannten" Liste stehen) aktivieren
- "Bekannte" IDs separat tracken
- **Effort:** Small-Medium
- **Risk:** Low

### Option B: Einfacher — beim Laden prüfen ob neue IDs dazugekommen sind
- `let savedIDs = decode(data)` → `savedIDs.union(newCalendarIDs)` wobei `newCalendarIDs = allIDs.subtracting(allKnownIDs)`
- **Effort:** Small

## Acceptance Criteria

- [ ] Neuer Kalender wird automatisch aktiviert
- [ ] Bestehende Deaktivierungen bleiben erhalten

## Work Log

| Datum | Aktion |
|-------|--------|
| 2026-03-26 | Finding erstellt via Code Review |

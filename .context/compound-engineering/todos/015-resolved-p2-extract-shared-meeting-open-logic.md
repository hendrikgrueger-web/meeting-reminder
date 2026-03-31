---
status: resolved
priority: p2
issue_id: "015"
tags: [code-review, maintainability, dry]
dependencies: []
---

# Duplizierte Meeting-Öffnen-Logik extrahieren

## Problem Statement

Die Deep-Link-mit-Fallback-Logik ist identisch in zwei Dateien:
- `MeetingAppDelegate.openMeetingDirectly()` (MeetingReminderApp.swift:253-264)
- `TodayMeetingsView.handleTap()` (TodayMeetingsView.swift:104-117)

Wenn sich die Öffnen-Strategie ändert, müssen beide Stellen synchron aktualisiert werden.

## Proposed Solutions

### Option A: Statische Methode auf MeetingLinkExtractor
- `MeetingLinkExtractor.open(_ meetingLink: MeetingLink)` — passt thematisch
- Beide Callsites rufen die eine Methode auf
- **Effort:** Small (~8 LOC gespart)

## Acceptance Criteria

- [ ] Eine einzige Methode für Meeting-Link-Öffnen
- [ ] Beide bisherigen Callsites nutzen die neue Methode

## Work Log

| Datum | Aktion |
|-------|--------|
| 2026-03-26 | Finding erstellt via Code Review |

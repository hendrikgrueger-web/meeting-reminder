---
status: pending
priority: p3
issue_id: "008"
tags: [code-review, maintainability]
---

# Veralteter Kommentar: --demo-paywall nicht mehr vorhanden

## Problem Statement
Kommentar in Zeile 104 von `MeetingReminderApp.swift` erwähnt noch `--demo-paywall`, das zusammen mit `PaywallView` gelöscht wurde. Irreführend für zukünftige Entwickler.

## Findings
- **File:** `Meeting Reminder/MeetingReminderApp.swift:104`
- Aktuell: `// Demo-Modus für Screenshots (Launch-Argument --demo-overlay / --demo-paywall)`
- `--demo-paywall` existiert nicht mehr

## Fix
```swift
// Demo-Modus für Screenshots (Launch-Argument: --demo-overlay)
```

## Acceptance Criteria
- [ ] Kommentar enthält nur `--demo-overlay`

## Work Log
- 2026-03-24: Gefunden bei Code Review (ce-review), maintainability-reviewer + correctness-reviewer

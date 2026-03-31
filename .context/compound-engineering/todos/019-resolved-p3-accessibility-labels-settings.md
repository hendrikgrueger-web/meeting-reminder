---
status: resolved
priority: p3
issue_id: "019"
tags: [code-review, accessibility, agent-native]
dependencies: []
---

# Accessibility Labels für SettingsView und TodayMeetingsView

## Problem Statement

AlertOverlayView hat vorbildliche Accessibility Labels. SettingsView und TodayMeetingsView haben keine einzigen `accessibilityLabel` oder `accessibilityIdentifier`. Alle Toggles nutzen `.labelsHidden()`, was auch VoiceOver-Labels versteckt.

## Proposed Solutions

- accessibilityLabel auf alle Toggles in SettingsView
- accessibilityLabel auf Meeting-Rows in TodayMeetingsView
- accessibilityIdentifier für UI-Test-Automation
- **Effort:** Small

## Acceptance Criteria

- [ ] VoiceOver kann alle Toggles in Settings benennen
- [ ] VoiceOver kann Meeting-Rows in Today beschreiben

## Work Log

| Datum | Aktion |
|-------|--------|
| 2026-03-26 | Finding erstellt via Code Review |

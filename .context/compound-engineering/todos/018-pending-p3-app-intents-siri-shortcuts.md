---
status: pending
priority: p3
issue_id: "018"
tags: [code-review, agent-native, feature, ux]
dependencies: []
---

# App Intents für Siri/Shortcuts/Spotlight hinzufügen

## Problem Statement

Die App hat keinerlei programmatische Schnittstelle — kein App Intents, kein URL Scheme, kein AppleScript. Auf macOS 26 sind App Intents trivial zu implementieren und bringen Siri, Shortcuts.app und Spotlight-Integration kostenlos mit.

## Proposed Solutions

### 3 App Intents implementieren:
1. **NextMeetingIntent** — gibt nächstes Meeting zurück (Titel, Zeit, Provider)
2. **JoinNextMeetingIntent** — öffnet den Meeting-Link direkt
3. **ListTodayMeetingsIntent** — gibt heutige Meetings zurück

### Bonus: URL Scheme `nevrlate://`
- Aktionen: `join-next`, `show`, `settings`
- ~30 LOC in `MeetingAppDelegate.application(_:open:)`

## Acceptance Criteria

- [ ] 3 App Intents funktionieren in Shortcuts.app
- [ ] Siri-Befehl "Nächstes Meeting" funktioniert
- [ ] Optional: nevrlate:// URL Scheme registriert

## Work Log

| Datum | Aktion |
|-------|--------|
| 2026-03-26 | Finding erstellt via Code Review |

---
status: pending
priority: p2
issue_id: "007"
tags: [code-review, localization, app-store]
---

# NSCalendarsUsageDescription nur auf Deutsch — App Store Rejection Risk

## Problem Statement
`Info.plist` enthält `NSCalendarsUsageDescription` nur auf Deutsch. `CFBundleLocalizations` deklariert aber `[en, de]`. Auf English-Systemen kann macOS zum Base-Localization fallback fallen — zeigt dann eine leere oder fehlende Permission-Beschreibung. Apple kann dies bei der App Review als Rejection-Grund werten.

## Findings
- **File:** `Meeting Reminder/Info.plist:33`
- Kein `en.lproj/InfoPlist.strings` vorhanden
- English-Nutzer sehen ggf. leere Calendar Permission-Beschreibung
- Flagged von correctness-reviewer (IMPORTANT)

## Proposed Solutions

### Option A: InfoPlist.strings für en + de erstellen
Erstelle `en.lproj/InfoPlist.strings` und `de.lproj/InfoPlist.strings`:
```
NSCalendarsUsageDescription = "Nevr Late reads your calendar events (read-only) to remind you about meetings and detect join links. No data leaves your device.";
```
Und passe Info.plist an: `NSCalendarsUsageDescription` als Platzhalter `$(NSCalendarsUsageDescription)` oder direkt English als Default.

**Effort:** Small | **Risk:** None

### Option B: String Catalog (Localizable.xcstrings)
Nutze die bereits vorbereitete `Localizable.xcstrings` Infrastruktur um Usage Descriptions zu lokalisieren.

**Effort:** Small | **Risk:** Low

## Acceptance Criteria
- [ ] NSCalendarsUsageDescription auf Englisch vorhanden (en.lproj oder als Default in Info.plist)
- [ ] English-Systemsprache → englischer Permission-Dialog
- [ ] Deutsche Systemsprache → deutscher Permission-Dialog

## Work Log
- 2026-03-24: Gefunden bei Code Review (ce-review), correctness-reviewer Agent

---
status: resolved
priority: p2
issue_id: "004"
tags: [code-review, security, maintainability, app-store]
---

# NSNotificationCenterUsageDescription aus Info.plist entfernen (iOS-only Key)

## Problem Statement
`Info.plist` enthält `NSNotificationCenterUsageDescription` — dieser Key ist iOS-only (für iOS Notification Center Widget-Zugriff). Auf macOS hat er keine Wirkung, wird aber von App Store Connect als Teil des Privacy-Audits gelesen. Er kann fälschlicherweise als "claimed permission" ohne Verwendung interpretiert werden und App Store Review Flags auslösen.

## Findings
- **File:** `Meeting Reminder/Info.plist:34`
- Key ist für macOS bedeutungslos, für iOS wäre er für den Notification Center Widget-Zugriff zuständig
- macOS-Notification-Berechtigung läuft über `requestAuthorization()` zur Laufzeit — kein Plist-Key nötig
- Flagged von: security-reviewer und maintainability-reviewer

## Proposed Solutions

### Option A: Key löschen
Entferne `NSNotificationCenterUsageDescription` aus Info.plist vollständig.

**Effort:** Small | **Risk:** None (macOS ignoriert den Key sowieso)

## Acceptance Criteria
- [ ] `NSNotificationCenterUsageDescription` nicht mehr in `Info.plist`
- [ ] App läuft weiterhin, UNUserNotificationCenter.requestAuthorization() funktioniert
- [ ] Build + alle Tests bestehen

## Work Log
- 2026-03-24: Gefunden bei Code Review (ce-review), security-reviewer + maintainability-reviewer Agents

---
status: resolved
priority: p2
issue_id: "006"
tags: [code-review, security, url-handling]
---

# Deep-Link URL-Konstruktion per String-Replace ohne Validierung

## Problem Statement
`MeetingLinkExtractor.deepLinkURL()` baut Deep-Links per String-Replacement (`https://` → `webex://`, `msteams:`, etc.). Dabei werden Pfad und Query-Parameter aus dem original Kalender-Event unvalidiert übernommen. Bei manipulierten Kalender-Events (shared/subscribed calendars) könnten crafted Deep-Link-URLs an native Apps übergeben werden.

## Findings
- **File:** `Meeting Reminder/Services/MeetingLinkExtractor.swift` (deepLinkURL Methode)
- WebEx: `urlString.replacingOccurrences(of: "https://", with: "webex://")` — kompletter Pfad inkl. user-controlled segments
- Teams: `https://teams.microsoft.com` → `msteams:` — Pfad/Query aus Kalender-Notiz
- Angriffspfad: Geteilter Kalender → crafted Meeting-URL → manipulierter Deep-Link → native App
- Confidence: 0.68 (moderate risk)

## Proposed Solutions

### Option A: URLComponents-basierte Scheme-Substitution
Statt String-Replace:
```swift
var components = URLComponents(url: httpsURL, resolvingAgainstBaseURL: false)!
components.scheme = "webex"
// Nur Host + Path übernehmen, Query validieren
return components.url
```

**Effort:** Small-Medium | **Risk:** Low

### Option B: Host-Validierung nach Deep-Link-Konstruktion
Nach dem Konstruieren prüfen ob `URLComponents(url: deepLink).host` dem erwarteten Wert entspricht.

**Effort:** Small | **Risk:** Low (Defense in depth)

## Acceptance Criteria
- [ ] Deep-Link-Konstruktion verwendet URLComponents statt String-Replacement
- [ ] Tests für alle 8 Provider, die prüfen ob nur der Scheme geändert wird
- [ ] Kein unvalidierter Pfad/Query aus Kalender-Notes in Deep-Link übernommen

## Work Log
- 2026-03-24: Gefunden bei Code Review (ce-review), security-reviewer Agent

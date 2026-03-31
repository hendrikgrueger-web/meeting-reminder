---
status: resolved
priority: p3
issue_id: "010"
tags: [code-review, correctness, ui]
---

# Location-URL-Filter in AlertOverlayView unvollständig (GoTo/Slack/Whereby/Jitsi fehlen)

## Problem Statement
`AlertOverlayView` filtert Meeting-URLs aus dem Location-Feld heraus, um zu vermeiden dass Meeting-URLs als physische Adresse mit Map-Pin angezeigt werden. Die Filterliste deckt aber nur Teams/Zoom/Google Meet/WebEx ab — GoTo, Slack Huddle, Whereby und Jitsi fehlen.

## Findings
- **File:** `Meeting Reminder/Views/AlertOverlayView.swift:130-144`
- Fehlend: `gotomeet.me`, `gotomeeting.com`, `app.slack.com/huddle`, `whereby.com`, `meet.jit.si`
- Bei diesen Providern erscheint die Meeting-URL als "Ort" mit Map-Pin

## Proposed Fix
Elegantere Lösung: Prüfe ob `event.hasMeetingLink && event.meetingURL?.absoluteString == event.location` anstatt String-Pattern-Matching.

**Effort:** Small | **Risk:** Low

## Acceptance Criteria
- [ ] Alle 8 Provider-URLs werden nicht als physische Adresse angezeigt
- [ ] Test für alle 8 Provider-Typen in AlertOverlayView

## Work Log
- 2026-03-24: Gefunden bei Code Review (ce-review), correctness-reviewer Agent

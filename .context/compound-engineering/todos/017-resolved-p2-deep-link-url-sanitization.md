---
status: resolved
priority: p2
issue_id: "017"
tags: [code-review, security]
dependencies: []
---

# Deep-Link URLs aus Kalenderdaten sanitieren

## Problem Statement

`MeetingLinkExtractor.deepLinkURL()` und `substituteScheme()` übernehmen Path/Query-Komponenten aus Kalender-Events direkt in Deep-Link-URLs (msteams://, zoommtg://, webex://, gotomeeting://). Bei geteilten Kalendern könnten manipulierte Events beliebige Path/Query-Parameter einschleusen.

Regex-Pattern `[^\s"<>]+` ist sehr permissiv für den Path/Query-Teil.

**Risiko:** Moderat — macOS Sandbox schützt, und Regex anchort auf bekannte Hosts. Aber die Target-Apps (Teams, Zoom) könnten eigene Schwachstellen in URL-Handlern haben.

## Proposed Solutions

### Option A: Query-Parameter nach Scheme-Substitution filtern
- Nach `substituteScheme`: URLComponents parsen, nur erwartete Query-Parameter behalten
- Zoom: nur `confno` + `pwd`
- Teams: Path muss mit `/l/meetup-join/` starten
- **Effort:** Small-Medium
- **Risk:** Low

## Acceptance Criteria

- [ ] Deep-Link URLs haben nur erwartete Query-Parameter
- [ ] Tests für manipulierte Kalender-URLs

## Work Log

| Datum | Aktion |
|-------|--------|
| 2026-03-26 | Finding erstellt via Code Review |

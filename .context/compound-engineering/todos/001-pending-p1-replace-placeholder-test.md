---
status: pending
priority: p1
issue_id: "001"
tags: [code-review, testing, quality]
---

# MeetingReminderTests.swift — Placeholder-Test ersetzt keine echten Tests

## Problem Statement
`MeetingReminderTests.swift` enthält nur `XCTAssertTrue(true)` — einen Literal-Assert ohne jegliche Verhaltenstests. Nach dem Freemium-Removal ist dies die einzige Testdatei für die gesamte App-Level-Orchestrierungsschicht (MeetingAppDelegate, handlePendingEvents, menuBarIcon, menuBarTooltip). Die 153 Tests decken ausschließlich untere Schichten ab (MeetingLinkExtractor, CalendarService statische Methoden, MeetingEvent Model).

## Findings
- `testProjectCompiles()` asserts `true` — keinerlei Verhaltensprüfung
- Alle `MeetingAppDelegate`-Methoden: `handlePendingEvents`, `registerGlobalShortcut`, `handleShortcutEvent`, `sendSystemNotification` — **null Coverage**
- `menuBarIcon` und `menuBarTooltip` (4 Branches je) — untested pure logic
- Misleading: erscheint als "passing test" in CI ohne echten Mehrwert

## Proposed Solutions

### Option A: Minimaler Fix — Placeholder durch sinnvolle Tests ersetzen
Ersetze `XCTAssertTrue(true)` durch Tests für die pure Logic:
- `menuBarIcon` bei 4 Fällen (kein Zugriff, kein Event, < 5 Min, < 15 Min)
- `menuBarTooltip` bei 4 Fällen
- Extrahiere dazu beides in nonisolated static Funktionen mit injizierbaren Parametern

**Effort:** Small | **Risk:** Low

### Option B: Vollständige Behavioral Tests für AppDelegate
Erstelle Factory-Methoden für FakeCalendarService + FakeOverlayController, teste:
- `handlePendingEvents` (leer → dismiss, mit Event → show, screen-sharing → notification)
- `--demo-overlay` Early Return

**Effort:** Medium | **Risk:** Low

## Acceptance Criteria
- [ ] Kein `XCTAssertTrue(true)` oder Literal-Assert in Testdateien
- [ ] menuBarIcon: alle 4 Fälle abgedeckt
- [ ] menuBarTooltip: alle 4 Fälle abgedeckt
- [ ] handlePendingEvents: happy path (Event → Overlay anzeigen) getestet

## Work Log
- 2026-03-24: Gefunden bei Code Review (ce-review), testing-reviewer Agent

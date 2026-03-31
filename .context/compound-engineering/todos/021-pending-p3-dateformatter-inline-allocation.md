---
status: pending
priority: p3
issue_id: "021"
tags: [code-review, performance, maintainability]
dependencies: []
---

# DateFormatter in AlertOverlayView als static let cachen

## Problem Statement

`AlertOverlayView.timeRange` (Zeile 302-308) erstellt bei jedem Aufruf 2 DateFormatter-Instanzen. Die View wird jede Sekunde neu evaluiert (Timer). Das sind ~120 unnötige Allokationen pro Minute.

## Proposed Solutions

- Beide Formatter als `private static let` auf AlertOverlayView
- **Effort:** Trivial (2 Zeilen verschieben)

## Acceptance Criteria

- [ ] DateFormatters sind static let
- [ ] timeRange nutzt die gecachten Formatter

## Work Log

| Datum | Aktion |
|-------|--------|
| 2026-03-26 | Finding erstellt via Code Review |

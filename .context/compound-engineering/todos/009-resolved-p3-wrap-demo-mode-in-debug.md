---
status: resolved
priority: p3
issue_id: "009"
tags: [code-review, security, debug]
---

# Demo-Modus --demo-overlay in Production Binary — mit #if DEBUG schützen

## Problem Statement
Die `--demo-overlay` Behandlung ist im Production Binary enthalten. Jeder Prozess, der die App mit diesem Launch-Argument starten kann, triggert den vollständigen Demo-Overlay ohne Calendar-Auth oder andere Guards.

## Findings
- **File:** `Meeting Reminder/MeetingReminderApp.swift:105-112`
- Demo-Code im Release-Build bedeutet externe Steuerbarkeit des Overlays
- `--demo-paywall` Kommentar gibt Hinweis auf potenziell zukünftig hinzugefügte Demo-Argumente

## Proposed Fix
```swift
#if DEBUG
let args = ProcessInfo.processInfo.arguments
if args.contains("--demo-overlay") {
    Task { @MainActor in
        try? await Task.sleep(nanoseconds: 800_000_000)
        MeetingAppDelegate.showDemoOverlay()
    }
    return
}
#endif
```

## Acceptance Criteria
- [ ] Demo-Code in `#if DEBUG` gewrappt
- [ ] Release Build enthält keinen `--demo-overlay` Pfad
- [ ] Debug Build funktioniert weiterhin für Screenshots

## Work Log
- 2026-03-24: Gefunden bei Code Review (ce-review), security-reviewer Agent

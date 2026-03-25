---
status: pending
priority: p2
issue_id: "003"
tags: [code-review, security, privacy, app-store]
---

# Privacy Manifest fehlt NSPrivacyAccessedAPICategoryFileTimestamp (EventKit)

## Problem Statement
`PrivacyInfo.xcprivacy` deklariert nur `NSPrivacyAccessedAPICategoryUserDefaults`. EventKit (`EKEventStore`) greift intern auf die Kalender-Datenbankdateien zu und liest dabei File Timestamps (stat() calls). Apple verlangt diese Deklaration für App Store Submission — fehlt sie, führt Apple's automatisierter Binary-Scan zu **automatischer Ablehnung**.

## Findings
- **File:** `Meeting Reminder/PrivacyInfo.xcprivacy`
- EventKit = Pflicht-Deklaration laut Apple Privacy Required Reason APIs
- Xcode's Privacy Report (Report Navigator → Generate Privacy Report) würde dies ebenfalls anzeigen
- Betroffen: alle Zugriffe via `CalendarService.swift` (EKEventStore-basiert)

## Proposed Solutions

### Option A: NSPrivacyAccessedAPICategoryFileTimestamp hinzufügen
Füge in PrivacyInfo.xcprivacy hinzu:
```xml
<dict>
    <key>NSPrivacyAccessedAPIType</key>
    <string>NSPrivacyAccessedAPICategoryFileTimestamp</string>
    <key>NSPrivacyAccessedAPITypeReasons</key>
    <array>
        <string>C617.1</string>
    </array>
</dict>
```
Reason C617.1: "Display file timestamps to the user"

**Effort:** Small | **Risk:** Low

### Option B: Xcode Privacy Report zuerst laufen lassen
`Product → Archive → Distribute App → Privacy Report` in Xcode generiert den vollständigen Report. Darauf aufbauend sicherstellen, dass alle gefundenen APIs deklariert sind.

**Effort:** Small | **Risk:** Low (aber zusätzlicher manueller Schritt)

## Acceptance Criteria
- [ ] `PrivacyInfo.xcprivacy` enthält `NSPrivacyAccessedAPICategoryFileTimestamp` mit Reason C617.1 oder DDA9.1
- [ ] Xcode Privacy Report zeigt keine fehlenden Deklarationen
- [ ] Build läuft durch ohne Privacy-Warnings

## Work Log
- 2026-03-24: Gefunden bei Code Review (ce-review), security-reviewer Agent

---
title: "fix: Code Review Issues — Privacy Manifest, Tests, Deep-Link Security"
type: fix
status: active
date: 2026-03-24
---

# fix: Code Review Issues — Privacy Manifest, Tests, Deep-Link Security

## Overview

Behebt 10 Issues aus dem `ce-review` Code Review vom 2026-03-24. Enthält **3 App-Store-blockeerende P2-Issues** (Privacy Manifest unvollständig, iOS-only Plist-Key, fehlende EN-Lokalisierung), **1 Correctness-Bug** (Snooze Race Condition → doppelter Overlay), **1 Security Issue** (Deep-Link String-Replace ohne Validierung) und **5 Quality/Testing-Issues** (Placeholder-Test, fehlende Coverage, veraltete Kommentare, Demo-Modus in Production-Binary).

> **Skill-Quellen genutzt:** `security/privacy-manifests`, `macos/macos-capabilities/sandboxing`, `macos/coding-best-practices/modern-concurrency`, `app-store/rejection-handler/common-rejections`, `macos/macos-capabilities/menubar`

---

## Issue-Übersicht

| # | ID | Prio | Kategorie | Kurzbeschreibung | App Store Blocker? |
|---|-----|------|-----------|-----------------|-------------------|
| 1 | 003 | P2 | Privacy/Security | Privacy Manifest fehlt FileTimestamp (EventKit) | ✅ Ja — automatisch |
| 2 | 004 | P2 | Plist/Maintainability | `NSNotificationCenterUsageDescription` iOS-only → entfernen | ⚠️ Möglich |
| 3 | 007 | P2 | Lokalisierung | `NSCalendarsUsageDescription` nur DE → App Review Rejection | ✅ Ja — Review |
| 4 | 005 | P2 | Correctness | Race Condition: snoozeEvent + reloadAndReschedule → 2 Overlays | ❌ Nein |
| 5 | 006 | P2 | Security | Deep-Link String-Replace ohne Validierung | ❌ Nein |
| 6 | 001 | P1 | Testing | Placeholder-Test `XCTAssertTrue(true)` → echte Tests | ❌ Nein |
| 7 | 002 | P1 | Testing | Kein Test für Screen-Sharing Notification Fallback | ❌ Nein |
| 8 | 008 | P3 | Maintainability | Veralteter Kommentar: `--demo-paywall` | ❌ Nein |
| 9 | 009 | P3 | Security | Demo-Modus `--demo-overlay` nicht in `#if DEBUG` gewrappt | ❌ Nein |
| 10 | 010 | P3 | Correctness/UI | Location-URL-Filter unvollständig (GoTo/Slack/Whereby/Jitsi) | ❌ Nein |

---

## Implementation Units

### Unit 1 — Privacy Manifest: FileTimestamp hinzufügen (P2, BLOCKER)

**Goal:** `PrivacyInfo.xcprivacy` um `NSPrivacyAccessedAPICategoryFileTimestamp` ergänzen, da EventKit intern auf Kalender-Datenbankdateien zugreift (stat() calls). Fehlt dieser Eintrag → Apple's Binary-Scan beim Upload lehnt automatisch ab.

**Patterns to follow:**
- `security/privacy-manifests` Skill → "Common Patterns: Typical App (No Tracking)":
  ```xml
  <dict>
      <key>NSPrivacyAccessedAPIType</key>
      <string>NSPrivacyAccessedAPICategoryFileTimestamp</string>
      <key>NSPrivacyAccessedAPITypeReasons</key>
      <array><string>C617.1</string></array>
  </dict>
  ```
- Reason Code **C617.1**: "Access timestamps inside the app container" — korrekt für EKEventStore-interne Zugriffe auf die Kalender-DB im Container

**Files:**
- `Meeting Reminder/PrivacyInfo.xcprivacy` — FileTimestamp-Block hinzufügen

**Approach:**
1. Existierenden `NSPrivacyAccessedAPITypes`-Array in `PrivacyInfo.xcprivacy` um den FileTimestamp-Dict-Block ergänzen
2. Nach Build: `Product > Generate Privacy Report` in Xcode laufen lassen → prüfen dass keine weiteren fehlenden APIs erscheinen

**Verification:**
- [ ] `PrivacyInfo.xcprivacy` enthält `NSPrivacyAccessedAPICategoryFileTimestamp` mit Reason `C617.1`
- [ ] Build läuft durch ohne Privacy-Warnings
- [ ] Xcode Privacy Report zeigt keine undeklarifizierten APIs

---

### Unit 2 — Info.plist: iOS-only Key entfernen + EN-Lokalisierung (P2, BLOCKER)

**Goal:** Zwei verwandte Info.plist-Korrekturen in einem Schritt:
1. `NSNotificationCenterUsageDescription` entfernen (iOS-only, auf macOS bedeutungslos, kann App Review-Flags auslösen)
2. `NSCalendarsUsageDescription` lokalisieren: English-Version hinzufügen damit English-Nutzer keinen leeren Permission-Dialog sehen

**Skill-Basis:** Apple verlangt Usage Descriptions in allen deklarierten Sprachen (`CFBundleLocalizations: [en, de]`). Fehlt die EN-Version → leere Beschreibung auf English-Systemen → App Review Guideline 5.1.1 Rejection.

**Files:**
- `Meeting Reminder/Info.plist` — `NSNotificationCenterUsageDescription` löschen, `NSCalendarsUsageDescription` als EN Default setzen
- `Meeting Reminder/en.lproj/InfoPlist.strings` (neu erstellen) — EN Übersetzungen
- `Meeting Reminder/de.lproj/InfoPlist.strings` (neu erstellen) — DE Übersetzungen
- `project.yml` — `en.lproj` und `de.lproj` als Ressourcen aufnehmen

**Approach:**
1. In `Info.plist`: `NSNotificationCenterUsageDescription` Key+Value löschen
2. `NSCalendarsUsageDescription` in Info.plist als EN-Fallback-Text setzen:
   ```
   "Nevr Late reads your calendar events (read-only) to remind you about upcoming meetings and detect video conference join links. No data leaves your device."
   ```
3. `en.lproj/InfoPlist.strings` erstellen:
   ```
   NSCalendarsUsageDescription = "Nevr Late reads your calendar events (read-only) to remind you about upcoming meetings and detect video conference join links. No data leaves your device.";
   ```
4. `de.lproj/InfoPlist.strings` erstellen:
   ```
   NSCalendarsUsageDescription = "Nevr Late liest deine Kalender-Events (nur lesend), um dich rechtzeitig an Meetings zu erinnern und Beitreten-Links zu erkennen. Keine Daten verlassen dein Gerät.";
   ```
5. `project.yml` prüfen/updaten: `en.lproj/**` und `de.lproj/**` in `sources:` oder `resources:` aufnehmen
6. `xcodegen generate` + `xcodebuild build` — prüfen ob Lokalisierungen korrekt gebündelt werden

**Verification:**
- [ ] `NSNotificationCenterUsageDescription` nicht mehr in `Info.plist`
- [ ] `en.lproj/InfoPlist.strings` und `de.lproj/InfoPlist.strings` existieren
- [ ] Simulator mit English-Locale: Kalender-Permission-Dialog zeigt englischen Text
- [ ] Simulator mit German-Locale: Kalender-Permission-Dialog zeigt deutschen Text
- [ ] `xcodebuild build` erfolgreich

---

### Unit 3 — Snooze Race Condition beheben (P2)

**Goal:** Verhindern dass das gleiche Event nach `snoozeEvent` + `reloadAndReschedule` doppelt in `pendingEvents` landet (führt zu zwei Overlays hintereinander).

**Race-Sequenz (Korrektheit-Analyse):**
1. `snoozeEvent(event)` → Event aus `pendingEvents` entfernt, 60-Sek-Timer registriert
2. `reloadAndReschedule()` feuert (Wake-Notification, 30-Min-Fallback, EKStoreChanged) → setzt `pendingEvents = [event]` (Meeting noch laufend) → erster Overlay erscheint
3. Snooze-Timer feuert → `pendingEvents.append(event)` → zweiter Overlay über dem ersten

**Swift 6 Concurrency Note:** `CalendarService` ist `@MainActor` → kein concurrent-access, aber der Timer-Closure läuft ebenfalls auf `@MainActor` → Race ist durch Timer-vs-reloadAndReschedule-Scheduling möglich, nicht durch Threading.

**Files:**
- `Meeting Reminder/Services/CalendarService.swift` — Snooze-Timer-Closure Guard

**Approach:**
```swift
// In snoozeEvent Timer-Closure (CalendarService.swift ~line 401):
// VORHER:
if timeSinceStart < 5 * 60 && !self.dismissedEvents.contains(event.id) {
    self.pendingEvents.append(event)
}

// NACHHER:
if timeSinceStart < 5 * 60 &&
   !self.dismissedEvents.contains(event.id) &&
   !self.pendingEvents.contains(where: { $0.id == event.id }) {
    self.pendingEvents.append(event)
}
```

**Verification:**
- [ ] Kein doppelter Overlay-Guard in `pendingEvents.append`
- [ ] Alle 153 bestehenden Tests weiterhin grün

---

### Unit 4 — Deep-Link URL-Validierung mit URLComponents (P2)

**Goal:** `MeetingLinkExtractor.deepLinkURL()` verwendet `String.replacingOccurrences(of:with:)` um HTTPS-Scheme durch App-Schemes zu ersetzen. Dabei werden Pfad/Query aus Kalender-Notizen unvalidiert übernommen. Umstellung auf `URLComponents` um nur den Scheme zu tauschen und Host+Path zu validieren.

**Security-Kontext:** Bei manipulierten Kalender-Events (geteilte/abonnierte Kalender) könnten crafted Deep-Links an native Apps (Teams, Zoom, WebEx) übergeben werden. Durch URLComponents-basierte Konstruktion wird sichergestellt, dass immer nur der Schema-Teil geändert wird.

**Files:**
- `Meeting Reminder/Services/MeetingLinkExtractor.swift` — `deepLinkURL(for:)` Methode

**Approach:**
```swift
// VORHER (für WebEx als Beispiel):
// urlString.replacingOccurrences(of: "https://", with: "webex://")

// NACHHER — elegante URLComponents-Methode:
private static func substituteScheme(_ url: URL, newScheme: String) -> URL? {
    var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    // Nur Scheme ändern — Host, Path, Query bleiben unverändert
    components?.scheme = newScheme
    return components?.url
}
```

Für Teams (spezifischer Schritt `https://teams.microsoft.com` → `msteams:`):
```swift
private static func substituteScheme(_ url: URL, newScheme: String,
                                      removeHost: Bool = false) -> URL? {
    var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    components?.scheme = newScheme
    if removeHost { components?.host = nil }
    return components?.url
}
```

Alle Aufrufe in `deepLinkURL(for:)` auf diese Hilfsmethode umstellen.

**Verification:**
- [ ] `deepLinkURL` verwendet `URLComponents` statt String-Replacement
- [ ] Bestehende 117 `MeetingLinkExtractorTests` weiterhin grün
- [ ] Test: Crafted URL mit Extra-Pfadsegmenten → nur Scheme ändert sich, Pfad bleibt unverändert

---

### Unit 5 — Echte Tests für AppDelegate-Logic (P1)

**Goal:** `MeetingReminderTests.swift` von `XCTAssertTrue(true)` zu echten Behavioral Tests umbauen. Schwerpunkt: pure Logic die ohne AppKit/MenuBarExtra testbar ist.

**Skill-Basis (macos/coding-best-practices):** Pure Logic (`menuBarIcon`, `menuBarTooltip`) als `nonisolated static` Funktionen extrahieren damit Unit Tests ohne laufende App funktionieren. Folgt dem SOLID-Prinzip: Trennung von reiner Berechnungslogik und UI-Lifecycle.

**Test-Strategie:**
- `menuBarIcon` und `menuBarTooltip` als `static nonisolated` Hilfsfunktionen mit injizierbaren Parametern extrahieren
- Diese direkt testen — kein AppKit Setup nötig

**Files:**
- `Meeting Reminder/MeetingReminderApp.swift` — `menuBarIcon` + `menuBarTooltip` als `static nonisolated` Hilfsfunktionen extrahieren
- `Meeting ReminderTests/MeetingReminderTests.swift` — alle Branches der extrahierten Funktionen testen

**Approach:**

**(1) Extraction in MeetingReminderApp.swift:**
```swift
// Neue nonisolated static Hilfsfunktionen (testbar ohne MainActor):
extension MeetingReminderApp {
    nonisolated static func menuBarIconName(
        accessGranted: Bool,
        nextEvent: MeetingEvent?,
        now: Date = Date()
    ) -> String {
        guard accessGranted else { return "bell.slash" }
        guard let next = nextEvent else { return "bell" }
        let minUntilStart = next.startDate.timeIntervalSince(now) / 60
        if minUntilStart < 5 { return "bell.badge.fill" }
        if minUntilStart < 15 { return "bell.badge" }
        return "bell"
    }

    nonisolated static func menuBarTooltipText(
        accessGranted: Bool,
        nextEvent: MeetingEvent?,
        now: Date = Date()
    ) -> String {
        guard accessGranted else { return "Kein Kalenderzugriff – Einstellungen öffnen" }
        guard let next = nextEvent else { return "Keine anstehenden Meetings" }
        let minutes = Int(next.startDate.timeIntervalSince(now) / 60)
        if minutes <= 0 { return "Meeting läuft: \(next.title)" }
        if minutes == 1 { return "Nächstes Meeting: \(next.title) in 1 Min" }
        return "Nächstes Meeting: \(next.title) in \(minutes) Min"
    }
}

// Bestehende computed properties delegieren an die testbaren Hilfsfunktionen:
private var menuBarIcon: String {
    Self.menuBarIconName(accessGranted: calendarService.accessGranted,
                         nextEvent: calendarService.nextEvent)
}
private var menuBarTooltip: String {
    Self.menuBarTooltipText(accessGranted: calendarService.accessGranted,
                            nextEvent: calendarService.nextEvent)
}
```

**(2) Tests in MeetingReminderTests.swift:**
```swift
// Meeting ReminderTests/MeetingReminderTests.swift
@testable import NevLate

final class MeetingReminderTests: XCTestCase {
    // menuBarIcon — 4 Fälle
    func testMenuBarIcon_NoAccess_ReturnsSlash() { ... }
    func testMenuBarIcon_NoEvent_ReturnsBell() { ... }
    func testMenuBarIcon_Under5Min_ReturnsFill() { ... }
    func testMenuBarIcon_Under15Min_ReturnsBadge() { ... }
    func testMenuBarIcon_Over15Min_ReturnsBell() { ... }

    // menuBarTooltip — 4 Fälle
    func testTooltip_NoAccess() { ... }
    func testTooltip_NoEvent() { ... }
    func testTooltip_RunningMeeting() { ... } // minutes <= 0
    func testTooltip_1Minute() { ... }
    func testTooltip_MultipleMinutes() { ... }
}
```

**Verification:**
- [ ] Alle neuen Tests sind grün
- [ ] Kein `XCTAssertTrue(true)` in Testdateien
- [ ] `menuBarIcon`/`menuBarTooltip` computed properties verwenden intern die testbaren static Funktionen
- [ ] Alle 153 + N neuen Tests bestehen

---

### Unit 6 — Test für Screen-Sharing Notification Fallback (P1)

**Goal:** Den Branch `silentWhenScreenSharing && isScreenSharing()` in `handlePendingEvents` testbar machen und testen. Dieser Branch ist der einzige verbleibende "komplexe" Pfad nach dem Freemium-Removal.

**Testbarkeit-Problem:** `OverlayController.isScreenSharing()` ist eine `static` Methode die `CGWindowList` aufruft — in Unit Tests nicht mockbar ohne Injection.

**Approach — isScreenSharing als injizierbarer Default-Closure:**
```swift
// In MeetingAppDelegate:
// Statt direktem Aufruf von OverlayController.isScreenSharing()
// Default-Parameter macht es testbar:
private func handlePendingEvents(
    _ events: [MeetingEvent],
    calendarService: CalendarService,
    overlayController: OverlayController,
    isScreenSharing: () -> Bool = { OverlayController.isScreenSharing() }
) {
    // ...
    if calendarService.silentWhenScreenSharing && isScreenSharing() {
        // screen-sharing path
    }
    // ...
}
```

**Files:**
- `Meeting Reminder/MeetingReminderApp.swift` — `handlePendingEvents` Signatur ergänzen
- `Meeting ReminderTests/MeetingReminderTests.swift` — Tests hinzufügen

**Tests:**
```swift
func testHandlePendingEvents_ScreenSharing_SendsNotification() {
    // Arrange: calendarService.silentWhenScreenSharing = true
    // isScreenSharing returns true
    // Act: handlePendingEvents mit fake isScreenSharing: { true }
    // Assert: sendSystemNotification wurde aufgerufen
    //         dismissEvent wurde aufgerufen
    //         overlayController.show wurde NICHT aufgerufen
}

func testHandlePendingEvents_NoScreenSharing_ShowsOverlay() {
    // isScreenSharing returns false → Overlay wird gezeigt
}

func testHandlePendingEvents_EmptyEvents_DismissesOverlay() {
    // events = [] → overlayController.dismiss() aufgerufen
}
```

**Swift 6 Concurrency Note:** `handlePendingEvents` ist `@MainActor` → Tests müssen `@MainActor` annotiert oder in `Task { @MainActor in ... }` gewrappt sein.

**Verification:**
- [ ] Test: screen-sharing=true + silentWhenScreenSharing=true → Notification statt Overlay
- [ ] Test: screen-sharing=false → Overlay
- [ ] Test: empty events → dismiss
- [ ] Alle Tests grün

---

### Unit 7 — Cleanup: Kommentar, Demo-Modus, Location-Filter (P3)

**Goal:** 3 kleine P3-Issues in einem Cleanup-Commit:

**(a) Veralteter Kommentar** (008):
```swift
// VORHER:
// Demo-Modus für Screenshots (Launch-Argument --demo-overlay / --demo-paywall)

// NACHHER:
// Demo-Modus für Screenshots (Launch-Argument: --demo-overlay)
```

**(b) Demo-Modus in #if DEBUG** (009):
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
→ Gesamter `showDemoOverlay()` + `makeDemoEvent()` Block ebenfalls in `#if DEBUG` wrappen.

**(c) Location-URL-Filter vervollständigen** (010):
Elegante Lösung: Statt Pattern-Liste prüfen ob `event.meetingURL?.absoluteString == event.location`:
```swift
// In AlertOverlayView, bei der Entscheidung ob location angezeigt wird:
// VORHER: Explizite URL-Pattern-Liste (nur 4 Provider)
// NACHHER:
var displayLocation: String? {
    guard let loc = event.location, !loc.isEmpty else { return nil }
    // Meeting-URL nicht als physische Adresse zeigen
    if let meetingURL = event.meetingURL,
       loc.contains(meetingURL.host ?? "") { return nil }
    if event.hasMeetingLink && loc.hasPrefix("http") { return nil }
    return loc
}
```

**Files:**
- `Meeting Reminder/MeetingReminderApp.swift` — Kommentar + `#if DEBUG`
- `Meeting Reminder/Views/AlertOverlayView.swift` — Location-Filter

**Verification:**
- [ ] Kein `--demo-paywall` in Kommentaren
- [ ] Demo-Code in `#if DEBUG`
- [ ] Release-Build enthält keinen `--demo-overlay` Codepfad
- [ ] Alle 8 Provider-URLs werden nicht als physische Adresse angezeigt
- [ ] Alle Tests grün

---

## Reihenfolge der Implementation Units

```
Phase 1 (App Store Blocker — zuerst):
  Unit 1: Privacy Manifest FileTimestamp       [~15 Min]
  Unit 2: Info.plist cleanup + EN Lokalisierung [~30 Min]

Phase 2 (Correctness + Security):
  Unit 3: Snooze Race Condition Fix             [~15 Min]
  Unit 4: Deep-Link URLComponents               [~30 Min]

Phase 3 (Tests):
  Unit 5: AppDelegate-Logic testbar machen      [~45 Min]
  Unit 6: Screen-Sharing Test                   [~30 Min]

Phase 4 (Cleanup):
  Unit 7: Kommentar, Debug-Guard, Location-Filter [~20 Min]
```

---

## Technical Considerations

### Privacy Manifest vollständige Checkliste (aus `security/privacy-manifests` Skill)

Nach Unit 1+2 nochmals prüfen:
- [ ] `NSPrivacyTracking`: false ✅ (bereits korrekt)
- [ ] `NSPrivacyTrackingDomains`: [] ✅ (korrekt)
- [ ] `NSPrivacyCollectedDataTypes`: [] ✅ (korrekt — keine Daten gesammelt)
- [ ] `NSPrivacyAccessedAPITypes`: UserDefaults CA92.1 ✅, **FileTimestamp C617.1** ← hinzufügen
- [ ] Xcode Privacy Report nach Build generieren
- [ ] Drittanbieter-SDKs: keine (keine Pods/SPM-Abhängigkeiten) ✅

### Sandbox-Verhalten UNUserNotificationCenter (aus `macos/macos-capabilities/sandboxing`)

Der Security-Reviewer hat `network.client` als potenziell nötig für `UNUserNotificationCenter` eingestuft. **Nachrecherche:** Lokale Notifications auf macOS 14+ kommunizieren über sandboxierten XPC-Pfad — kein `network.client` nötig. **Aktion:** Console.app nach dem Deploy auf Sandbox-Violations prüfen. Kein Entitlement hinzufügen, es sei denn Violations erscheinen.

### Swift 6 Concurrency in Tests (aus `macos/coding-best-practices/modern-concurrency`)

`MeetingAppDelegate` ist `@MainActor` → Tests die AppDelegate-Methoden aufrufen müssen `@MainActor`-annotiert sein:
```swift
@MainActor
final class MeetingReminderTests: XCTestCase { ... }
// ODER einzelne Tests:
func testFoo() async throws {
    await MainActor.run { ... }
}
```

### Regressions-Absicherung

- Alle 153 bestehenden Tests müssen nach jedem Unit grün bleiben
- `xcodebuild test` nach jedem Unit ausführen
- Commit-Strategie: Pro Unit einen eigenen Commit (atomar)

---

## System-Wide Impact

### Interaction Graph

**Unit 1 (Privacy Manifest):** Rein deklarativ — kein Laufzeit-Impact. Ändert nur die `.xcprivacy`-Datei die Apple beim Upload scannt.

**Unit 2 (Info.plist):** Entfernen von `NSNotificationCenterUsageDescription` → keine Runtime-Änderung. Hinzufügen von `InfoPlist.strings` → macOS lokalisiert Permission-Dialog bei nächster Installation/Kaltstart.

**Unit 3 (Snooze):** `pendingEvents` wird durch Combine-Sink beobachtet. Das `!contains`-Guard verhindert das doppelte Append → verhindert zwei consecutive `sink`-Fires → verhindert doppeltes Overlay.

**Unit 4 (Deep-Link):** `openMeetingDirectly` in `MeetingAppDelegate` ruft `MeetingLinkExtractor.deepLinkURL(for:)` auf → `NSWorkspace.shared.open(url)`. Änderung: Gleiche URL, nur konstruiert über URLComponents statt String-Replace. Für alle 117 vorhandenen Test-Fälle kein Output-Unterschied.

**Unit 5+6 (Tests):** Keine Laufzeit-Änderung. Extraction von `menuBarIconName`/`menuBarTooltipText` als `static nonisolated` → `menuBarIcon`/`menuBarTooltip` delegieren → identisches Laufzeitverhalten, aber testbar.

**Unit 7 (Cleanup):** `#if DEBUG` um Demo-Code → Production-Binary leaner und sicherer. Location-Filter-Verbesserung → korrekteres UI für GoTo/Slack/Whereby/Jitsi.

### Error & Failure Propagation

`URLComponents(url:resolvingAgainstBaseURL:)` kann `nil` zurückgeben bei ungültigen URLs. `deepLinkURL` soll weiterhin die original HTTPS-URL als Fallback zurückgeben:
```swift
// Fallback wenn URLComponents nil:
static func substituteScheme(_ url: URL, newScheme: String) -> URL {
    var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    components?.scheme = newScheme
    return components?.url ?? url  // Fallback auf original URL
}
```

### State Lifecycle Risks

Snooze-Timer (Unit 3): Der Guard `!pendingEvents.contains(where:)` ist ein Lese-Zugriff auf `@MainActor`-geschütztes State → sicher, da auch der Timer-Closure auf `@MainActor` läuft (Timer-scheduled Task im `@MainActor`-Kontext).

---

## Acceptance Criteria

### App Store Readiness (P2-Issues)
- [ ] `PrivacyInfo.xcprivacy` enthält `NSPrivacyAccessedAPICategoryFileTimestamp` mit `C617.1`
- [ ] `NSNotificationCenterUsageDescription` nicht mehr in `Info.plist`
- [ ] `en.lproj/InfoPlist.strings` mit englischem `NSCalendarsUsageDescription` vorhanden
- [ ] `de.lproj/InfoPlist.strings` mit deutschem `NSCalendarsUsageDescription` vorhanden
- [ ] Xcode Privacy Report zeigt keine ungeklätten Zugriffe

### Correctness
- [ ] Snooze + reloadAndReschedule → `pendingEvents.count == 1` (nicht 2)
- [ ] Deep-Link-Konstruktion via URLComponents für alle 8 Provider
- [ ] Location-URL für alle 8 Provider wird nicht als physische Adresse angezeigt

### Security
- [ ] Demo-Code in `#if DEBUG` — Release-Build enthält keinen `--demo-overlay` Pfad
- [ ] `deepLinkURL` validiert URL-Struktur via URLComponents

### Tests
- [ ] Kein `XCTAssertTrue(true)` in Testdateien
- [ ] `menuBarIconName`: alle 5 Branches getestet
- [ ] `menuBarTooltipText`: alle 5 Branches getestet
- [ ] Screen-Sharing Fallback: 3 Fälle getestet
- [ ] Leere Events → dismiss getestet
- [ ] Alle 153 + neue Tests grün

### Code Quality
- [ ] Kommentar `--demo-paywall` entfernt
- [ ] `CalendarService.swift` Snooze-Timer-Guard vorhanden

---

## Dependencies & Risks

| Abhängigkeit | Risiko | Mitigation |
|---|---|---|
| `xcodegen generate` nach project.yml-Änderungen | lproj-Dateien könnten nicht erkannt werden | Manuell in `.xcodeproj` prüfen nach `xcodegen generate` |
| URLComponents nil-Return | Fallback auf original HTTPS-URL verhindert Crash | `?? url` Fallback in `substituteScheme` |
| `@MainActor` in Tests | Swift 6 strict isolation errors | Tests mit `@MainActor` annotieren oder `MainActor.run{}` verwenden |
| Xcode Privacy Report | Zeigt möglicherweise weitere undeklarierte APIs | Nach Report nachpatchen, dann nochmals generieren |

---

## Commit-Strategie

Pro Unit ein Commit:
```
fix: Privacy Manifest — FileTimestamp C617.1 hinzugefügt
fix: Info.plist — iOS-only Key entfernt, EN/DE Lokalisierung für Permissions
fix: CalendarService — Snooze race condition guard gegen doppelten Overlay
fix: MeetingLinkExtractor — Deep-Link via URLComponents statt String-Replace
feat(test): AppDelegate menuBarIcon/Tooltip als testbare static Funktionen
feat(test): handlePendingEvents screen-sharing Fallback getestet
refactor: Demo-Modus in #if DEBUG, stale Kommentar, Location-Filter-Cleanup
```

---

## Sources & References

### Apple Skills genutzt

| Skill | Relevanz |
|-------|---------|
| `security/privacy-manifests` | FileTimestamp Reason-Codes, Xcode Privacy Report |
| `macos/macos-capabilities/sandboxing` | Sandbox-Entitlement-Analyse (network.client) |
| `macos/coding-best-practices/modern-concurrency` | @MainActor in Tests, nonisolated static |
| `app-store/rejection-handler/common-rejections` | Guideline 5.1.1 Usage Descriptions, Guideline 5.1.2 |
| `macos/macos-capabilities/menubar` | MenuBarExtra Pattern, Dynamic Icon |

### Interne Referenzen

- `Meeting Reminder/PrivacyInfo.xcprivacy` — aktueller Stand (nur UserDefaults)
- `Meeting Reminder/Info.plist` — `NSNotificationCenterUsageDescription` zu entfernen
- `Meeting Reminder/Services/MeetingLinkExtractor.swift` — `deepLinkURL(for:)` Methode
- `Meeting Reminder/Services/CalendarService.swift` — `snoozeEvent` ~line 393
- `Meeting Reminder/MeetingReminderApp.swift` — `handlePendingEvents`, `menuBarIcon`, `menuBarTooltip`
- `.context/compound-engineering/todos/` — 10 Todo-Dateien (001–010) aus Code Review

### Code Review Origin

- **Code Review:** `ce-review` auf commits `ef724ae` + `e15d2b3`, 2026-03-24
- **Agents:** correctness-reviewer, security-reviewer, testing-reviewer, maintainability-reviewer
- **Todo-Dateien:** `.context/compound-engineering/todos/001-010`

### Apple Documentation

- [Privacy manifest files](https://developer.apple.com/documentation/bundleresources/privacy_manifest_files)
- [Describing use of required reason API](https://developer.apple.com/documentation/bundleresources/privacy_manifest_files/describing_use_of_required_reason_api)
- [NSCalendarsUsageDescription](https://developer.apple.com/documentation/bundleresources/information_property_list/nscalendarsusagedescription)

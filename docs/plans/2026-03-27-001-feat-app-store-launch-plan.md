---
title: "feat: Nevr Late — App Store Launch (Cleanup + Submission + Preismodell)"
type: feat
status: completed
date: 2026-03-27
---

# Nevr Late — App Store Launch Plan

## Overview

Finaler Sprint zum App Store Launch: Code-Cleanup (30 LOC Dead Code), Timer-Bug-Fix (SettingsView Status-Text veraltet), App Store Submission-Blocker beheben, und Pricing-Entscheidung umsetzen.

## Problem Frame

Die App ist funktional fertig, hat 150 Tests, und ist in ASC registriert (ID: 6761079659). Aber:
- 30 LOC Dead Code aus der letzten Refactoring-Runde
- SettingsView-Status aktualisiert sich nicht während das Popover offen ist
- App Store Submission hat 5 Blocker (Support URL, Age Rating, Texte, Screenshot, Info.plist)
- Pricing-Modell noch nicht implementiert

## Preismodell-Empfehlung (Mein Rat)

**Empfehlung: Phase 1 KOSTENLOS launchen, Phase 2 Non-Consumable IAP.**

Begründung:
- macOS 26+ hat winzige Nutzerbasis (Beta-only bis Herbst 2026)
- MeetingBar (kostenlos, Open Source) ist der stärkste Wettbewerber
- €0,99 Einmalkauf bringt realistisch ~€7/Monat (100 Downloads × 10% Conversion × €0,69 nach Apple-Cut)
- Downloads und Reviews sind jetzt wertvoller als €0,69 pro Verkauf
- StoreKit-Integration spart ~8h Entwicklungsaufwand → schnellerer Launch

**Wenn trotzdem 4W Trial + €0,99:** Non-Consumable IAP ist technisch machbar. Trial-Zeitraum lokal via Keychain (überlebt App-Deinstallation). Aber: Apple hat keinen nativen Trial-Mechanismus für Non-Consumable IAPs, das muss komplett selbst gebaut werden.

**Entscheidung für diesen Plan: Kostenlos launchen.** StoreKit-Integration als separater Plan nach Launch.

## Requirements Trace

- R1. Dead Code aus Refactoring entfernen (~30 LOC)
- R2. SettingsView Timer-Bug fixen (Status-Text + Jetzt-Badge aktualisieren sich nicht)
- R3. App Store Submission-Blocker beheben (Support URL, Age Rating, Texte, Screenshots)
- R4. NSCalendarsFullAccessUsageDescription in Info.plist (Security-Finding)
- R5. Debug-Prints entfernen oder #if DEBUG wrappen
- R6. NSPanel.level von .screenSaver auf .floating (App Review Risiko reduzieren)
- R7. Accessibility-Permission-Check für globalen Shortcut
- R8. QuickJoin-Referenzen in Localizable.xcstrings bereinigen
- R9. Copyright vereinheitlichen
- R10. Build-Nummer hochsetzen + project.yml synchronisieren

## Scope Boundaries

- **Kein** StoreKit / Paywall / Trial-Logik (separater Plan nach Launch)
- **Keine** neuen Features (App Intents, URL Scheme — separater Plan)
- **Kein** Timer-Refactoring für gleichzeitige Events (#012 — separater Plan)
- **Keine** neuen Screenshots (bestehende 4 reichen, Screenshot 5 mit Paywall wird entfernt)

## Key Technical Decisions

- **Kostenlos launchen** statt Trial + IAP: Schnellerer Launch, maximiert Downloads
- **NSPanel.level = .floating** statt .screenSaver: Reduziert App Review Rejection-Risiko deutlich. Das Overlay erscheint immer noch über normalen Fenstern, aber nicht über Systemdialoge.
- **@State now + Timer in SettingsView**: Gleiche Pattern wie TodayMeetingsView, 30-Sek-Timer für konsistente Zeitanzeige
- **Keychain statt UserDefaults** für Trial-Datum: Erst relevant in Phase 2 (StoreKit-Plan)
- **App Store Description**: "FREE — ALWAYS" bleibt erstmal korrekt (da kostenlos gelauncht wird)

## Implementation Units

- [x] **Unit 1: Dead Code entfernen (6 Stellen)**

**Goal:** 30 LOC Dead Code aus der letzten Refactoring-Runde entfernen.

**Requirements:** R1

**Dependencies:** Keine

**Files:**
- Modify: `Meeting Reminder/Views/AlertOverlayView.swift` — `secondsUntilStart` entfernen
- Modify: `Meeting Reminder/Views/TodayMeetingsView.swift` — `scrollTargetID` entfernen
- Modify: `Meeting Reminder/MeetingReminderApp.swift` — `overlayController` @ObservedObject + Init entfernen, `openMeetingDirectly` inline ersetzen, `categoryIdentifier` entfernen
- Modify: `Meeting Reminder/Views/OverlayController.swift` — `isVisible` @Published entfernen

**Approach:**
- `secondsUntilStart` (AlertOverlayView:31-33): Definiert aber nie gelesen
- `scrollTargetID` (TodayMeetingsView:33-44): Redundant mit SettingsView.scrollTargetEventID
- `@ObservedObject overlayController` (MeetingReminderApp:14,20): Nie im body gelesen, verursacht unnötige Re-Renders
- `isVisible` (OverlayController): Gesetzt aber nie gelesen
- `openMeetingDirectly` (MeetingReminderApp:249-251): 1-Zeilen-Wrapper → direkt MeetingLinkExtractor.open() aufrufen
- `categoryIdentifier = "MEETING_ALERT"` (MeetingReminderApp:300): Nie registriert, hat keinen Effekt

**Verification:**
- Build + 150 Tests grün
- Keine Referenzen auf entfernte Symbole

---

- [x] **Unit 2: SettingsView Timer-Bug fixen**

**Goal:** Status-Text und Jetzt-Badge aktualisieren sich während das Popover offen ist.

**Requirements:** R2

**Dependencies:** Keine

**Files:**
- Modify: `Meeting Reminder/Views/SettingsView.swift`

**Approach:**
- `@State private var now: Date = .now` hinzufügen
- Timer.publish(every: 30) wie in TodayMeetingsView
- `statusTimeText(for:)` und `if next.startDate <= Date()` auf `now` umstellen
- `.onReceive(timer) { now = $0 }` im body

**Test scenarios:**
- Popover öffnen → 30 Sek warten → relative Zeit aktualisiert sich
- Meeting startet während Popover offen → "Jetzt"-Badge erscheint

**Verification:**
- Status-Section und TodayMeetingsView zeigen konsistente Zeitangaben

---

- [x] **Unit 3: Debug-Prints wrappen**

**Goal:** 5 print()-Aufrufe in Release-Builds unterdrücken.

**Requirements:** R5

**Dependencies:** Keine

**Files:**
- Modify: `Meeting Reminder/Services/CalendarService.swift` (4 prints)
- Modify: `Meeting Reminder/MeetingReminderApp.swift` (1 print)

**Approach:**
- Alle `print()` Aufrufe in `#if DEBUG ... #endif` wrappen

**Verification:**
- Build grün, keine print-Aufrufe außerhalb von #if DEBUG

---

- [x] **Unit 4: NSPanel.level auf .floating ändern**

**Goal:** App Review Rejection-Risiko reduzieren.

**Requirements:** R6

**Dependencies:** Keine

**Files:**
- Modify: `Meeting Reminder/Views/OverlayPanel.swift`

**Approach:**
- `self.level = .screenSaver` → `self.level = .floating`
- `.floating` erscheint über normalen Fenstern aber nicht über Systemdialoge
- Testbar: Overlay erscheint über Xcode/Browser, aber unter macOS Dialoge

**Verification:**
- Build grün
- Overlay erscheint über normalen App-Fenstern

---

- [x] **Unit 5: Info.plist + project.yml Fixes**

**Goal:** Security-Finding + Build-Nummer + Copyright beheben.

**Requirements:** R4, R9, R10

**Dependencies:** Keine

**Files:**
- Modify: `Meeting Reminder/Info.plist`
- Modify: `project.yml`

**Approach:**
- `NSCalendarsFullAccessUsageDescription` zu Info.plist hinzufügen (gleicher Text wie NSCalendarsUsageDescription)
- `NSHumanReadableCopyright` in Info.plist auf "© 2026 Grüpi GmbH" vereinheitlichen
- `CURRENT_PROJECT_VERSION` in project.yml auf `4` hochsetzen
- Gleichen Key auch in InfoPlist.strings (en.lproj + de.lproj) lokalisieren

**Verification:**
- xcodegen generate → Build grün
- Info.plist enthält beide Kalender-Usage-Descriptions

---

- [x] **Unit 6: Localizable.xcstrings QuickJoin → Nevr Late**

**Goal:** Alle "QuickJoin"-Referenzen in Lokalisierungsdateien bereinigen.

**Requirements:** R8

**Dependencies:** Keine

**Files:**
- Modify: `Meeting Reminder/Localizable.xcstrings`

**Approach:**
- Alle "QuickJoin"-Strings durch "Nevr Late" ersetzen
- Englische und deutsche Varianten prüfen

**Verification:**
- `grep -r "QuickJoin" "Meeting Reminder/"` gibt keine Treffer

---

- [x] **Unit 7: Accessibility-Check für globalen Shortcut**

**Goal:** User informieren wenn Accessibility-Berechtigung fehlt.

**Requirements:** R7

**Dependencies:** Unit 1 (Dead Code entfernt)

**Files:**
- Modify: `Meeting Reminder/Views/SettingsView.swift`
- Modify: `Meeting Reminder/MeetingReminderApp.swift`

**Approach:**
- `AXIsProcessTrusted()` Check in MeetingAppDelegate.registerGlobalShortcut()
- Wenn false: globalMonitor = nil (erwartetes Verhalten, aber jetzt explizit)
- In SettingsView: Warnung unter dem Shortcut-Toggle wenn `!AXIsProcessTrusted()` und Toggle an
- "In Systemeinstellungen aktivieren" Button (wie bei Kalender-Zugriff)

**Verification:**
- Build grün
- Ohne Accessibility-Berechtigung: Warnung sichtbar in Settings

---

- [x] **Unit 8: App Store Submission vorbereiten**

**Goal:** Alle ASC-Blocker beheben und zur Submission bereit sein.

**Requirements:** R3

**Dependencies:** Units 1-7 abgeschlossen

**Files:**
- Modify: `docs/app-store-listing.md` — Pricing-Text prüfen (bleibt "FREE" da kostenlos)

**Approach:**
- In ASC setzen (über CLI oder manuell):
  - Support URL: `mailto:hendrik@grueger.dev` oder `https://www.gruepi.de/nevrlate/support/`
  - Age Rating: 4+
  - Screenshot 5 (mit Paywall) entfernen — nur 4 Screenshots behalten
  - App Review Notes: Testanleitung hinzufügen
- Xcode Cloud Workflow einrichten (Push main → TestFlight)
- Build 4 hochladen nach allen Code-Änderungen

**Verification:**
- `asc status --app 6761079659` zeigt Ready for Review
- TestFlight Build verfügbar

## System-Wide Impact

- **NSPanel.level-Änderung:** Overlay erscheint nicht mehr über Systemdialoge. Edge Case: Wenn ein User die App als "unübersehbare Erinnerung" nutzt und absichtlich alles überdecken will, ist .floating weniger aggressiv. Das ist der richtige Trade-off für App Store Approval.
- **Accessibility-Check:** Neue UI-Warnung in SettingsView. Benötigt AXIsProcessTrusted() Import (ApplicationServices Framework).
- **Dead Code Entfernung:** overlayController @ObservedObject-Entfernung reduziert unnötige Re-Renders der MenuBarExtra-View.

## Risks & Dependencies

- **App Review Timing:** macOS 26 Apps werden möglicherweise langsamer reviewt (kleine Review-Queue). Rechne mit 24-48h.
- **NSPanel .floating vs .screenSaver:** .floating könnte von Full-Screen-Apps überdeckt werden. Wenn das ein Problem ist, .modalPanel als Kompromiss testen.
- **Accessibility-Permission:** AXIsProcessTrusted() öffnet auf manchen macOS-Versionen automatisch den Systemeinstellungen-Dialog. Das Verhalten ist nicht 100% konsistent.
- **Xcode Cloud:** Erfordert manuellen Setup-Schritt in Xcode UI (kann nicht automatisiert werden).

## Sources & References

- Code Review Findings: 5 Agents (Simplicity, Correctness, Maintainability, Security, App Store Readiness)
- Apple HIG: https://developer.apple.com/design/human-interface-guidelines/the-menu-bar
- App Store Review Guidelines: https://developer.apple.com/app-store/review/guidelines/
- StoreKit 2 Documentation: https://developer.apple.com/documentation/storekit
- Wettbewerber: MeetingBar (kostenlos, Open Source), Meeter (€9,99/Jahr), Dato (€5,99)

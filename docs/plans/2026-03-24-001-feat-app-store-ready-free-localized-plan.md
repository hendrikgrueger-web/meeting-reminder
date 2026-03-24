---
title: "feat: App Store Ready — Komplett kostenlos, DE + EN, Weltweit"
type: feat
status: completed
date: 2026-03-24
---

# App Store Ready — Nevr Late (Gratis, DE + EN, Weltweit)

## Überblick

Nevr Late wird vollständig kostenlos in den Mac App Store gebracht. Das Freemium-Modell (50 Reminders, danach Paywall) wird entfernt. Die App unterstützt Deutsch und Englisch und ist weltweit verfügbar. Ziel ist eine saubere, approbationsfähige Version 1.0 ohne In-App-Käufe.

---

## Problem Statement / Motivation

- Die App ist technisch fertig, aber nicht App Store Ready
- Freemium-Modell (StoreKit 2, Paywall, ReminderCounter) ist implementiert, soll aber zunächst entfernt werden
- Info.plist enthält noch alte "QuickJoin"-Texte statt "Nevr Late"
- App Store Texte (DE + EN) enthalten noch die Premium-Sektion
- `network.client`-Entitlement ist nur für StoreKit nötig (soll entfernt werden)
- Kein Privacy Manifest (`PrivacyInfo.xcprivacy`) vorhanden
- App Store Connect: App noch nicht angelegt, Bundle ID noch nicht registriert
- Xcode Cloud Pipeline fehlt
- Screenshots fehlen

---

## Proposed Solution

Freemium-Code entfernen → Info.plist bereinigen → App Store Texte anpassen → Privacy Manifest hinzufügen → App Store Connect einrichten → Screenshots erstellen → Xcode Cloud aufsetzen.

---

## Phasen

### Phase 1: Freemium-Code entfernen (Code-Änderungen)

#### 1.1 Dateien löschen

- `Meeting Reminder/Services/ReminderCounter.swift` → löschen (via `trash`)
- `Meeting Reminder/Services/StoreKitService.swift` → löschen (via `trash`)
- `Meeting Reminder/Views/PaywallView.swift` → löschen (via `trash`)
- `Meeting Reminder/NevLate.storekit` → löschen (via `trash`)

#### 1.2 MeetingReminderApp.swift bereinigen

Folgende Stellen anpassen:

- `StoreKitService.shared.start()` → entfernen
- `let counter = ReminderCounter.shared` + `guard counter.canShow(event:)` → entfernen
- Paywall-Branch (`PaywallView(event:) { ... }`) → entfernen
- Doppelter Paywall-Branch (Zeile ~311) → entfernen
- Imports für ReminderCounter/StoreKitService/PaywallView → entfernen

Ergebnis: `showOverlay(for:)` zeigt immer direkt `AlertOverlayView` — kein Guard, kein Counter.

#### 1.3 Entitlement bereinigen

In `Meeting Reminder/Meeting_Reminder.entitlements`:
- `com.apple.security.network.client` → entfernen (nur für StoreKit benötigt)

Behalten:
- `com.apple.security.app-sandbox`
- `com.apple.security.personal-information.calendars`

#### 1.4 project.yml bereinigen

- StoreKit-Referenz aus project.yml entfernen falls vorhanden
- `xcodegen generate` ausführen um NevLate.xcodeproj neu zu generieren

---

### Phase 2: Info.plist + Lokalisierung bereinigen

#### 2.1 Info.plist — alte "QuickJoin"-Texte ersetzen

| Key | Alt | Neu (DE) |
|-----|-----|----------|
| `NSCalendarsUsageDescription` | "QuickJoin liest deine Kalender-Events..." | "Nevr Late liest deine Kalender-Events (nur lesend), um dich rechtzeitig an Meetings zu erinnern und Beitreten-Links zu erkennen. Keine Daten verlassen dein Gerät." |
| `NSNotificationCenterUsageDescription` | "QuickJoin sendet dir..." | "Nevr Late sendet Benachrichtigungen für bevorstehende Meetings, wenn du gerade den Bildschirm teilst." |
| `CFBundleDevelopmentRegion` | `de` | `$(DEVELOPMENT_LANGUAGE)` |

#### 2.2 Localizable.xcstrings prüfen

Die Datei hat 1177 Zeilen und enthält bereits DE + EN Übersetzungen. Prüfen ob noch Strings für:
- Paywall-Texte vorhanden sind → entfernen
- Premium-Texte (z.B. "50 Reminders", "Abo", "0,99 €") → entfernen
- Alle anderen UI-Strings vollständig in EN übersetzt sind

Fehlende EN-Übersetzungen ergänzen (sourceLanguage = "en").

#### 2.3 Info.plist CFBundleLocalizations ergänzen

```xml
<key>CFBundleLocalizations</key>
<array>
    <string>en</string>
    <string>de</string>
</array>
```

---

### Phase 3: App Store Texte anpassen

**Datei:** `docs/app-store-listing.md`

#### 3.1 Englisch — Description

Premium-Sektion entfernen:

```
─────────────────────────────────
NEVR LATE PREMIUM
─────────────────────────────────
[...gesamter Block...]
```

Ersetzen durch:

```
─────────────────────────────────
FREE — ALWAYS
─────────────────────────────────

Nevr Late is completely free. No ads, no tracking, no subscription required.
```

#### 3.2 Englisch — What's New

Alt: "Free for your first 50 meetings."
Neu: "Nevr Late is completely free for everyone."

#### 3.3 Deutsch — Description

Premium-Sektion entfernen und ersetzen durch:

```
─────────────────────────────────
KOSTENLOS — FÜR IMMER
─────────────────────────────────

Nevr Late ist vollständig kostenlos. Keine Werbung, kein Tracking, kein Abo.
```

#### 3.4 Deutsch — What's New

Alt: "Kostenlos für deine ersten 50 Meetings."
Neu: "Nevr Late ist vollständig kostenlos für alle."

#### 3.5 Pricing & In-App Purchases Sektion

Gesamten "Subscription-Konfiguration" Block aus app-store-listing.md entfernen. Ersetzen durch:

```
### Pricing
Kostenlos — keine In-App-Käufe, keine Abonnements.
```

---

### Phase 4: Privacy Manifest

Apple verlangt seit Mai 2024 ein Privacy Manifest für alle App Store Apps.

**Datei erstellen:** `Meeting Reminder/PrivacyInfo.xcprivacy`

Nevr Late greift zu auf:
- **Kalender-Daten** (via EventKit) → `NSPrivacyAccessedAPICategoryCalendarData` → Zweck: App-Funktionalität
- **UserDefaults** (via `NSUserDefaults`) → `NSPrivacyAccessedAPICategoryUserDefaults` → Zweck: App-Einstellungen

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "...">
<plist version="1.0">
<dict>
    <key>NSPrivacyTracking</key>
    <false/>
    <key>NSPrivacyTrackingDomains</key>
    <array/>
    <key>NSPrivacyCollectedDataTypes</key>
    <array/>
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>CA92.1</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
```

Datei in `project.yml` unter Sources aufnehmen.

---

### Phase 5: App Store Connect Setup (Manuell)

> Diese Schritte erfordern Login im App Store Connect Portal.

#### 5.1 Bundle ID registrieren

URL: `https://developer.apple.com/account/resources/identifiers/list`

- Identifier: `de.hendrikgrueger.nevrlate`
- Platform: macOS
- Capabilities: keine (kein Push, kein CloudKit, kein StoreKit nötig)

#### 5.2 App anlegen

URL: `https://appstoreconnect.apple.com/apps`

| Feld | Wert |
|------|------|
| Platform | macOS |
| Name | Nevr Late — Meeting Reminder |
| Primary Language | English |
| Bundle ID | de.hendrikgrueger.nevrlate |
| SKU | nevrlate-macos-v1 |

#### 5.3 App-Metadaten eintragen (EN + DE)

Für beide Sprachen laut `docs/app-store-listing.md` (aktualisierte Version ohne Premium):
- Name, Subtitle, Description, Promotional Text, Keywords, What's New
- Support URL: `https://hendrikgrueger.de/nevrlate` (oder GitHub Issues)
- Privacy Policy URL: `https://hendrikgrueger.de/nevrlate/privacy` (oder direkt HTML)
- Marketing URL (optional)

#### 5.4 Kein In-App-Purchase anlegen

Keine Subscription Group, keine Produkte → App ist free.

#### 5.5 Pricing

- Preis: Free (Tier 0)
- Verfügbarkeit: All Countries and Regions (weltweit)

#### 5.6 Altersbeschränkung

- 4+ (keine bedenklichen Inhalte)
- Keine Inhalte die eine Bewertung erfordern

---

### Phase 6: App Icon prüfen

App Icon muss in `Assets.xcassets/AppIcon.appiconset/` als 1024×1024 PNG vorliegen.
Xcode generiert alle weiteren Größen automatisch.

Prüfen:
```bash
ls "Meeting Reminder/Assets.xcassets/AppIcon.appiconset/"
```

Falls kein Icon vorhanden: temporär SF Symbol `bell.badge.fill` als Platzhalter exportieren oder mit Stitch ein Icon generieren lassen.

---

### Phase 7: Screenshots (Mac App Store)

**Mac App Store erfordert:** Screenshots für 1280×800 oder 1440×900 (je nach Retina)

Empfohlene 5 Screenshots:
1. **Vollbild-Overlay** — Teams-Meeting kurz vor Start, Countdown 2:00, "Teams beitreten"-Button
2. **Menüleisten-Popover** — Tagesübersicht mit 3 Meetings (Google, Teams, Zoom) + Status
3. **Live Badge** — LIVE-Meeting läuft, Overlay mit pulsierendem roten Dot
4. **Einstellungen** — Kalender-Toggle + Provider-Filter in Popover
5. **Kein Einwahllink** — Warnung + Countdown für reinen Kalender-Termin

Vorgehen:
- App im Simulator/echten Mac starten
- Testdaten: realistische Kalender-Events mit echten Meeting-Links
- Screenshot mit `⌘⇧4` + Space oder `screencapture`
- In `docs/screenshots/` ablegen

---

### Phase 8: Xcode Cloud Pipeline

Ziel: Push auf `main` → automatischer Build → TestFlight

#### 8.1 Setup in Xcode

1. Xcode öffnen → Integrations → Xcode Cloud → "Get Started"
2. Produkt wählen: NevLate
3. Workflow-Name: "TestFlight Distribution"
4. Trigger: Push auf `main`
5. Build Action: Build + Archive
6. Post-Action: TestFlight Internal Testing

#### 8.2 Workflow-Konfiguration

```yaml
# Grundkonfiguration (via Xcode Cloud UI)
Trigger: branch = main
Build: macOS
Xcode: 26+
Action: Archive
Sign: Automatic (Distribution)
Post: TestFlight → Internal Group
```

---

### Phase 9: Build & Submission-Check

```bash
# 1. Tests laufen lassen
xcodebuild test -project NevLate.xcodeproj -scheme NevLate \
  -destination "platform=macOS" -derivedDataPath ./build \
  CODE_SIGN_IDENTITY="Apple Development: Hendrik Grueger (HY44A7L7D7)" \
  DEVELOPMENT_TEAM=CU87QNNB3N

# 2. Build prüfen (Release)
xcodebuild build -project NevLate.xcodeproj -scheme NevLate \
  -configuration Release \
  -destination "platform=macOS" -derivedDataPath ./build \
  CODE_SIGN_IDENTITY="Apple Development: Hendrik Grueger (HY44A7L7D7)" \
  DEVELOPMENT_TEAM=CU87QNNB3N

# 3. Archive für Submission
xcodebuild archive -project NevLate.xcodeproj -scheme NevLate \
  -archivePath ./build/NevLate.xcarchive \
  DEVELOPMENT_TEAM=CU87QNNB3N
```

---

## Acceptance Criteria

### Funktional
- [ ] App startet ohne Fehler (kein StoreKit-Code, kein ReminderCounter)
- [ ] Jedes Meeting zeigt Overlay ohne Limit (kein Paywall nach 50 Reminders)
- [ ] Kein `PaywallView`, kein `ReminderCounter`, kein `StoreKitService` im Code
- [ ] `NevLate.storekit` Datei nicht mehr im Projekt

### Lokalisierung
- [ ] App wechselt automatisch zwischen DE und EN je nach Systemsprache
- [ ] Alle UI-Strings in `Localizable.xcstrings` für EN und DE vorhanden
- [ ] Info.plist Usage Descriptions enthalten "Nevr Late" (kein "QuickJoin")
- [ ] `CFBundleDevelopmentRegion` = `$(DEVELOPMENT_LANGUAGE)`

### App Store
- [ ] `docs/app-store-listing.md` ohne Premium-Sektion (EN + DE)
- [ ] `PrivacyInfo.xcprivacy` vorhanden und korrekt
- [ ] App Icon (1024×1024) in Assets.xcassets vorhanden
- [ ] 5 Screenshots für Mac App Store erstellt und abgelegt
- [ ] Privacy Policy URL funktioniert (DE + EN)

### App Store Connect (Manuell)
- [ ] Bundle ID `de.hendrikgrueger.nevrlate` registriert
- [ ] App Record angelegt (macOS, Free, worldwide)
- [ ] Metadaten EN + DE eingetragen
- [ ] Preis: Free, alle Länder
- [ ] Keine In-App-Käufe angelegt

### Build
- [ ] Alle 153 Tests bestehen (nach Freemium-Entfernung)
- [ ] Release-Build kompiliert ohne Warnings
- [ ] `network.client`-Entitlement entfernt
- [ ] Xcode Cloud Pipeline konfiguriert

---

## Reihenfolge der Umsetzung

1. **Phase 1** (Code) → direkt implementierbar
2. **Phase 2** (Info.plist + Lokalisierung) → direkt implementierbar
3. **Phase 4** (Privacy Manifest) → direkt implementierbar
4. **Phase 3** (App Store Texte) → direkt implementierbar
5. **Phase 9** (Build + Tests) → nach Code-Änderungen validieren
6. **Phase 6** (App Icon) → prüfen, ggf. erstellen
7. **Phase 7** (Screenshots) → nach stabiler App
8. **Phase 5** (App Store Connect) → manuell im Portal
9. **Phase 8** (Xcode Cloud) → nach App Store Connect Setup

---

## Technische Risiken

| Risiko | Wahrscheinlichkeit | Mitigation |
|--------|-------------------|------------|
| Kompilierungsfehler durch fehlende Importe nach Datei-Löschung | Mittel | project.yml-Referenzen prüfen + `xcodegen generate` |
| Localizable.xcstrings enthält noch Paywall-Strings die zu Warnings führen | Niedrig | Xcode zeigt unused-string Warnings |
| Privacy Manifest fehlt → App Store Rejection | Hoch (ohne Manifest) | Phase 4 vor Submission umsetzen |
| App Icon fehlt → kann nicht eingereicht werden | Zu prüfen | Phase 6 |
| macOS 26 ist noch in Beta → Reviewers brauchen Testgerät | Niedrig | Apple hat interne Testgeräte |

---

## Nicht in diesem Plan

- Paid-Version / Freemium wieder einführen (bewusste Entscheidung: erstmal gratis)
- Neue Features (z.B. weitere Meeting-Provider)
- Marketing-Website
- Push-Notifications
- macOS 13/14/15 Rückwärtskompatibilität

---

## Sources & References

- **App Store Listing:** `docs/app-store-listing.md`
- **Launch Spec:** `docs/superpowers/specs/2026-03-22-app-store-launch-design.md`
- **Privacy Manifest Docs:** https://developer.apple.com/documentation/bundleresources/privacy-manifest-files
- **NSPrivacyAccessedAPITypes:** https://developer.apple.com/documentation/bundleresources/privacy-manifest-files/describing-use-of-required-reason-api
- **Mac App Store Review Guidelines:** https://developer.apple.com/app-store/review/guidelines/
- **Xcode Cloud:** https://developer.apple.com/xcode-cloud/

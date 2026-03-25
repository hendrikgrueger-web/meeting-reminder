---
title: "feat: TestFlight & App Store Submission — Nevr Late 1.0"
type: feat
status: active
date: 2026-03-24
---

# feat: TestFlight & App Store Submission — Nevr Late 1.0

## Überblick

Nevr Late 1.0 (`de.hendrikgrueger.nevrlate`) soll in TestFlight für erste Tester freigeschaltet und danach im Mac App Store veröffentlicht werden. Die App ist in App Store Connect bereits angelegt (App-ID: **6761079659**, Version 1.0 in `PREPARE_FOR_SUBMISSION`). Kein Build ist bisher hochgeladen, keine TestFlight-Gruppe existiert noch.

**Ziel dieser Iteration:**
1. Ersten Build archivieren und hochladen
2. TestFlight-Gruppe anlegen und `hendrikgrueger@gmail.com` + Sebastian freischalten
3. App Store Connect Metadaten vollständig befüllen
4. App Store Review einreichen

---

## Voraussetzungen (bereits erfüllt ✅)

- [x] App in ASC angelegt (ID: `6761079659`, Bundle ID: `de.hendrikgrueger.nevrlate`)
- [x] Version 1.0 in ASC angelegt (`PREPARE_FOR_SUBMISSION`)
- [x] Privacy Manifest (`PrivacyInfo.xcprivacy`) mit FileTimestamp C617.1
- [x] EN + DE Lokalisierung für `NSCalendarsUsageDescription`
- [x] App Icon in `Assets.xcassets/AppIcon.appiconset/` (alle Größen 16–1024 px)
- [x] App Store Texte in `docs/app-store-listing.md` (EN + DE)
- [x] ASC Metadata-Verzeichnis `docs/asc-metadata/` vorhanden
- [x] Setup-Script `docs/asc-setup.sh` vorhanden

---

## Phase 1: Build archivieren und hochladen

### 1.1 Distribution Certificate prüfen

```bash
# Prüfen ob ein Distribution Certificate vorhanden ist
security find-identity -v -p codesigning | grep "Apple Distribution"
```

Wenn kein `Apple Distribution`-Zertifikat erscheint → über Xcode Preferences (Account → Manage Certificates) oder via Keychain/ASC API anlegen.

### 1.2 Provisioning Profile für Distribution

```bash
# Profil für App Store Distribution erstellen via ASC API
asc profiles list 2>/dev/null | grep nevrlate
```

Falls noch keins: Xcode → Signing & Capabilities → "Automatically manage signing" stellt es automatisch bereit, oder manuell via ASC.

### 1.3 Archivieren via xcodebuild

```bash
cd "/Users/hendrik.grueger/Coding/1_privat/Apple Apps/Meeting Reminder"

xcodebuild archive \
  -project NevLate.xcodeproj \
  -scheme NevLate \
  -destination "platform=macOS" \
  -archivePath ./build/NevLate.xcarchive \
  CODE_SIGN_IDENTITY="Apple Distribution: Hendrik Grueger (CU87QNNB3N)" \
  DEVELOPMENT_TEAM=CU87QNNB3N \
  CODE_SIGN_STYLE=Manual \
  PROVISIONING_PROFILE_SPECIFIER="match AppStore de.hendrikgrueger.nevrlate"
```

> **Hinweis:** Falls Automatic Signing verwendet wird, `CODE_SIGN_STYLE=Automatic` setzen.

### 1.4 ExportOptions.plist anlegen

Datei `build/ExportOptions.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>destination</key>
    <string>upload</string>
    <key>teamID</key>
    <string>CU87QNNB3N</string>
    <key>uploadSymbols</key>
    <true/>
    <key>uploadBitcode</key>
    <false/>
</dict>
</plist>
```

### 1.5 Exportieren und hochladen

```bash
xcodebuild -exportArchive \
  -archivePath ./build/NevLate.xcarchive \
  -exportPath ./build/NevLate-export \
  -exportOptionsPlist ./build/ExportOptions.plist
```

Mit `destination: upload` wird der Build direkt zu ASC hochgeladen. Alternative: Transporter App.

### 1.6 Build in ASC prüfen

```bash
# Warten bis Build verarbeitet ist (ca. 5–15 Minuten)
asc builds list --app 6761079659 2>/dev/null | head -20
```

---

## Phase 2: TestFlight einrichten

### 2.1 Interne TestFlight-Gruppe anlegen

**Via ASC CLI oder Browser-Fallback:**

```bash
# Prüfen ob asc testflight groups create unterstützt wird
asc testflight groups create --app 6761079659 --name "Beta Tester" 2>/dev/null
```

> Falls CLI nicht funktioniert → **Cowork-Prompt:**
> Geh auf `https://appstoreconnect.apple.com/apps/6761079659/testflight/groups`.
> Klicke „+" → Name: „Beta Tester" → Save.
> Notiere die Gruppe-ID.

### 2.2 Tester hinzufügen

```bash
# Tester zur Gruppe hinzufügen
GROUP_ID="<gruppe-id-aus-schritt-2.1>"

asc testflight testers add \
  --app 6761079659 \
  --group "$GROUP_ID" \
  --email "hendrikgrueger@gmail.com" \
  --first-name "Hendrik" \
  --last-name "Grueger" \
  2>/dev/null
```

Für Sebastian wird die E-Mail-Adresse benötigt (noch unbekannt — beim Ausführen ergänzen):

```bash
asc testflight testers add \
  --app 6761079659 \
  --group "$GROUP_ID" \
  --email "sebastians-email@example.com" \
  --first-name "Sebastian" \
  --last-name "<Nachname>" \
  2>/dev/null
```

> **TODO:** Sebastians E-Mail vor Ausführung eintragen.

### 2.3 Build der TestFlight-Gruppe zuweisen

```bash
BUILD_ID="<build-id-aus-phase-1>"

asc testflight builds add \
  --group "$GROUP_ID" \
  --build "$BUILD_ID" \
  2>/dev/null
```

> Browser-Fallback: `https://appstoreconnect.apple.com/apps/6761079659/testflight` → Build auswählen → Gruppe zuweisen → "Add"

### 2.4 TestFlight-Einladungen versenden

Die Tester erhalten automatisch eine E-Mail von Apple mit dem TestFlight-Link. Auf macOS müssen sie:
1. TestFlight aus dem Mac App Store installieren
2. Einladungslink annehmen
3. Nevr Late installieren

---

## Phase 3: App Store Connect Metadaten

### 3.1 asc-setup.sh ausführen

```bash
cd "/Users/hendrik.grueger/Coding/1_privat/Apple Apps/Meeting Reminder"
APP_ID=6761079659
VERSION_ID=a3d022c1-59a6-42e2-8803-2af7c97dc929
APP_ID=$APP_ID VERSION_ID=$VERSION_ID bash docs/asc-setup.sh
```

Setzt: Kategorie (Productivity/Utilities), Age Rating (4+), Metadata aus `docs/asc-metadata/`.

### 3.2 asc-metadata prüfen / anlegen

Die Verzeichnisstruktur muss vorhanden sein:

```
docs/asc-metadata/
├── en-US/
│   ├── description.txt
│   ├── subtitle.txt
│   ├── keywords.txt
│   ├── releaseNotes.txt
│   └── whatsNew.txt
└── de-DE/
    ├── description.txt
    ├── subtitle.txt
    ├── keywords.txt
    ├── releaseNotes.txt
    └── whatsNew.txt
```

Texte sind in `docs/app-store-listing.md` vollständig vorhanden und müssen nur in die korrekten Dateien übertragen werden.

### 3.3 Screenshots hochladen

Benötigt werden **5 Screenshots** für macOS (1440×900 px empfohlen, oder 1280×800):

```bash
asc screenshots upload \
  --app 6761079659 \
  --version a3d022c1-59a6-42e2-8803-2af7c97dc929 \
  --locale en-US \
  --file docs/screenshots/screenshot_1.png \
  2>/dev/null
```

> **Demo-Overlay Screenshot:** `xcodebuild run -arguments --demo-overlay` startet die App im Demo-Modus für Screenshots.

### 3.4 Privacy Policy URL eintragen

```bash
asc privacy-policy set \
  --app 6761079659 \
  --url "https://hendrikgrueger.de/nevrlate/privacy" \
  2>/dev/null
```

> Fallback: In ASC Browser unter App Information → Privacy Policy URL eintragen.
> Die Privacy-Policy-Dateien (`docs/privacy-policy-en.html`, `docs/privacy-policy-de.html`) müssen auf `hendrikgrueger.de/nevrlate/privacy` hochgeladen werden.

### 3.5 Build mit Version verknüpfen

```bash
asc versions builds set \
  --version a3d022c1-59a6-42e2-8803-2af7c97dc929 \
  --build "$BUILD_ID" \
  2>/dev/null
```

---

## Phase 4: App Store Review einreichen

### 4.1 Review-Notizen hinzufügen (optional aber empfohlen)

```bash
asc review-notes set \
  --version a3d022c1-59a6-42e2-8803-2af7c97dc929 \
  --notes "Nevr Late is a macOS menu bar app that reminds users about upcoming calendar meetings and provides one-click join links for video conferences (Teams, Zoom, Google Meet, WebEx, GoTo, Slack, Whereby, Jitsi). Calendar access is read-only. No data leaves the device. Freemium: first 50 reminders free, then subscription required." \
  2>/dev/null
```

### 4.2 Zur Einreichung einreichen

```bash
asc submissions create \
  --version a3d022c1-59a6-42e2-8803-2af7c97dc929 \
  2>/dev/null
```

> Browser-Fallback: In ASC → App Store → Version 1.0 → "Submit for Review"

---

## Acceptance Criteria

- [ ] Build in TestFlight sichtbar (Status: `VALID`)
- [ ] `hendrikgrueger@gmail.com` erhält TestFlight-Einladung
- [ ] Sebastian erhält TestFlight-Einladung (E-Mail vorher eintragen)
- [ ] App ist auf Test-Mac installierbar und startet korrekt
- [ ] Alle Metadaten in ASC vollständig (Description EN+DE, Keywords, Subtitle, Screenshots)
- [ ] Privacy Policy URL gesetzt
- [ ] App für App Store Review eingereicht

---

## Bekannte Offene Punkte

| Punkt | Aktion |
|-------|--------|
| Sebastians E-Mail | Vor Phase 2.2 erfragen/eintragen |
| Privacy Policy Hosting | `privacy-policy-en.html` auf `hendrikgrueger.de/nevrlate/privacy` deployen (Alfahosting) |
| Screenshots | 5 Screenshots mit `--demo-overlay` erstellen |
| Subscription Group in ASC | Muss in ASC Browser angelegt werden (CLI nicht unterstützt) — Produkte: `de.hendrikgrueger.nevrlate.premium.monthly` + `...annual` |
| Sandbox-Tests | StoreKit-Käufe in Sandbox testen bevor Einreichung |

---

## Schnell-Referenz

| Ressource | Wert |
|-----------|------|
| App-ID | `6761079659` |
| Bundle ID | `de.hendrikgrueger.nevrlate` |
| Version ID | `a3d022c1-59a6-42e2-8803-2af7c97dc929` |
| Team ID | `CU87QNNB3N` |
| ASC URL | `https://appstoreconnect.apple.com/apps/6761079659` |
| Privacy Policy URL | `https://hendrikgrueger.de/nevrlate/privacy` |

---

## Sources

- `docs/app-store-listing.md` — App Store Texte EN + DE
- `docs/asc-setup.sh` — Setup-Script (Kategorie, Age Rating, Metadata)
- `docs/asc-metadata/` — Metadaten-Verzeichnis
- ASC Skills: `asc-cli/asc-testflight-orchestration`, `asc-cli/asc-release-flow`, `asc-cli/asc-build-lifecycle`

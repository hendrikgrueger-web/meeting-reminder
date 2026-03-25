---
title: "feat: App Store Submission Final — Screenshots, Age Rating, Review Submit"
type: feat
status: active
date: 2026-03-25
---

# feat: App Store Submission Final

## Overview

Alle verbleibenden Schritte um Nevr Late in den App Store zu bringen.
Build 2 (Stitch-Design in ae075a8 committed, noch nicht archiviert) → App Store Review.

**Was bereits erledigt ist:**
- Build 2 gültig in ASC, linked zu App Store Version + TestFlight
- Beta App Review: WAITING_FOR_REVIEW
- App Store Metadaten: Name, Subtitle, Description (EN+DE), Keywords, Promo Text gesetzt
- Privacy Policy: https://www.gruepi.de/nevrlate/privacy/
- Stitch Glassmorphic Redesign: committed (ae075a8), noch nicht archiviert

**Was noch fehlt (dieser Plan):**
1. Build 3 archivieren + uploaden (mit Stitch-Design)
2. Age Rating (4+) setzen via ASC API
3. What's New Text setzen via ASC API
4. 5 Mac App Store Screenshots (1440×900) generieren
5. Screenshots via ASC API hochladen
6. App Store Review einreichen

## ASC Credentials

- Key ID: `5Z59XGMLK8`
- Issuer: `f7238e45-4bb6-4cfa-b23c-57ecea233f5e`
- Key: `~/.credentials/apple-asc/AuthKey_5Z59XGMLK8.p8`
- App ID: (via API abrufen — Bundle ID `de.hendrikgrueger.nevrlate`)
- App Store Version ID: (via API abrufen)

## Implementation Units

### Unit 1 — Build 3 archivieren + uploaden

**Ziel:** Neueste Code-Version (Stitch-Design) als Build 3 in ASC

```bash
cd "/Users/hendrik.grueger/Coding/1_privat/Apple Apps/Meeting Reminder"
xcodebuild archive \
  -project NevLate.xcodeproj \
  -scheme NevLate \
  -destination "platform=macOS" \
  -archivePath ./build/NevLate.xcarchive \
  CODE_SIGN_IDENTITY="Apple Development: Hendrik Grueger (HY44A7L7D7)" \
  DEVELOPMENT_TEAM=CU87QNNB3N \
  -allowProvisioningUpdates

xcodebuild -exportArchive \
  -archivePath ./build/NevLate.xcarchive \
  -exportPath ./build/NevLate-export \
  -exportOptionsPlist ./ExportOptions.plist \
  -allowProvisioningUpdates

xcrun altool --upload-app \
  --type macos \
  --file ./build/NevLate-export/NevLate.pkg \
  --apiKey 5Z59XGMLK8 \
  --apiIssuer f7238e45-4bb6-4cfa-b23c-57ecea233f5e
```

**Verification:** Build 3 erscheint als PROCESSING in ASC.

### Unit 2 — Age Rating setzen (4+)

**Ziel:** Age Rating Declaration über ASC API

```python
PATCH /v1/ageRatingDeclarations/{id}
{
  "data": {
    "attributes": {
      "alcoholTobaccoOrDrugUseOrReferences": "NONE",
      "contests": "NONE",
      "gambling": false,
      "gamblingAndContests": false,
      "gamblingSimulated": "NONE",
      "horrorOrFearThemes": "NONE",
      "matureOrSuggestiveThemes": "NONE",
      "medicalOrTreatmentInformation": "NONE",
      "profanityOrCrudeHumor": "NONE",
      "sexualContentGraphicAndNudity": "NONE",
      "sexualContentOrNudity": "NONE",
      "unrestrictedWebAccess": false,
      "violenceCartoonOrFantasy": "NONE",
      "violenceRealistic": "NONE",
      "violenceRealisticProlongedGraphicOrSadistic": "NONE"
    }
  }
}
```

**Verification:** App Rating zeigt "4+" in ASC.

### Unit 3 — What's New Text setzen

**Ziel:** Release Notes für Version 1.0.0

```
EN: "Never miss a meeting again. Nevr Late sits in your menu bar and alerts you with a beautiful overlay before your next meeting starts."
DE: "Keine Meetings mehr verpassen. Nevr Late sitzt in der Menüleiste und erinnert dich mit einem eleganten Overlay an dein nächstes Meeting."
```

**Verification:** What's New erscheint in App Store Version Details.

### Unit 4 — Screenshots generieren (1440×900)

**Ziel:** 5 aussagekräftige Mac App Store Screenshots

Screenshots-Konzept:
1. Overlay über echtem Desktop mit Teams-Meeting
2. Countdown-Pill (orange, "beginnt in 45 Sek.")
3. LIVE Badge (rotes Overlay, Meeting läuft)
4. Menüleisten-Popover mit Tagesübersicht
5. Overlay über Kalenderhintergrund (schöner Desktop)

**Technik:** Swift ImageRenderer oder HTML→PNG via screencapture

**Verification:** 5 PNG-Dateien 1440×900 in docs/screenshots/

### Unit 5 — Screenshots hochladen

**Ziel:** Screenshots in App Store Version via ASC API

```python
# Pro Screenshot:
# 1. POST /v1/appScreenshots (Reservierung)
# 2. Upload via reservationUrl
# 3. PATCH /v1/appScreenshots/{id} (als uploaded markieren)
```

**Verification:** Screenshots erscheinen in ASC unter dem App Store Version.

### Unit 6 — App Store Review einreichen

**Ziel:** App Store Review Submission

```python
POST /v1/appStoreVersionSubmissions
{
  "data": {
    "type": "appStoreVersionSubmissions",
    "relationships": {
      "appStoreVersion": {
        "data": { "type": "appStoreVersions", "id": "{version_id}" }
      }
    }
  }
}
```

**Verification:** Status zeigt "WAITING_FOR_REVIEW" in ASC.

## Acceptance Criteria

- [ ] Build 3 (Stitch Design) in ASC als VALID
- [ ] Age Rating 4+ gesetzt
- [ ] What's New Text in EN+DE gesetzt
- [ ] 5 Screenshots (1440×900) hochgeladen
- [ ] App Store Version Status: WAITING_FOR_REVIEW

## Files Changed

| Datei | Änderung |
|-------|----------|
| `ExportOptions.plist` | Erstellen (App Store export config) |
| `docs/screenshots/*.png` | 5 generierte Screenshots |

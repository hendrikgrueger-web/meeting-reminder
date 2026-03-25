---
title: "feat: AlertOverlayView Redesign 3/10→9/10 + App Store Completion"
type: feat
status: active
date: 2026-03-25
---

# feat: AlertOverlayView Redesign (3/10 → 9/10) + App Store Completion

## Overview

Zwei parallele Tracks:

1. **Design-Redesign** — AlertOverlayView sieht aktuell aus wie ein generisches System-Dialog. Schriftfarben sind kaum lesbar (weiß mit 0.3–0.5 Opacity auf hellem Glass-Hintergrund), Buttons kaum sichtbar, LIVE-Badge zu subtil. Von 3/10 auf 9/10.
2. **App Store Completion** — Offene Punkte aus der Submission-Session: Build-Verknüpfung mit Version, Metadaten-Upload via ASC, Screenshots, Privacy Policy Hosting, Review-Einreichung.

---

## Problem-Analyse: Design

### Root Cause — das eigentliche Problem

`AlertOverlayView.swift:184` nutzt `.background(.ultraThinMaterial)` + `.glassEffect(.regular)`. Auf macOS rendert `.ultraThinMaterial` **hell** (light glass), wenn kein `.environment(\.colorScheme, .dark)` gesetzt ist. Das Ergebnis: eine **hellgraue Karte**, auf der alle `white.opacity(0.x)` Texte fast unsichtbar sind.

```
Karte = helles Glas
Uhrzeit = white.opacity(0.4) → kaum sichtbar
Kalender-Name = white.opacity(0.5) → kaum sichtbar
Zeitraum = white.opacity(0.6) → schwach
Snooze-Label = white.opacity(0.3) → nahezu unsichtbar
Snooze-Button = white.opacity(0.5) → schwach
"Später erinnern" = white.opacity(0.3) → unsichtbar
LIVE-Badge: .red Text auf .red.opacity(0.15) Hintergrund → verschwindet
Schließen-Button: .bordered auf hellem Glas → quasi transparent
```

### Konkrete Probleme nach Priorität

| Problem | Datei:Zeile | Aktuell | Fix |
|---------|------------|---------|-----|
| Karte rendert hell | `AlertOverlayView.swift:184` | kein dark colorScheme | `.environment(\.colorScheme, .dark)` hinzufügen |
| Uhrzeit kaum sichtbar | `:101` | `white.opacity(0.4)` | `white.opacity(0.75)` |
| Kalender-Name zu faint | `:124` | `white.opacity(0.5)` | `white.opacity(0.75)` |
| Zeitraum schlecht lesbar | `:131` | `white.opacity(0.6)` | `white.opacity(0.9)` |
| LIVE-Badge | `:199–206` | `.red` Text auf `.red.opacity(0.15)` | solider `.red`-Hintergrund, `.white` Text |
| Schließen-Button unsichtbar | `:277–285` | `.bordered` auf Glasfläche | explizites `white.opacity(0.15)` Fill + `white.opacity(0.3)` Border |
| Snooze-Label | `:293` | `white.opacity(0.3)` | `white.opacity(0.6)` |
| Snooze-Button | `:304` | `white.opacity(0.5)` | `white.opacity(0.8)` |
| "via Provider" | `:268` | `white.opacity(0.3)` | `white.opacity(0.55)` |
| Kalender-Farbbalken | `:107–108` | 4×32pt | 4×44pt (höher) |

---

## 9/10 Design-Vision

```
┌─────────────────────────────────────────┐
│  08:59:06                          LIVE 🔴│  ← Zeit prominent (0.75), LIVE solid rot
│                                         │
│  ▌ Regelaustausch Sales                 │  ← Farbbalken, Titel weiß 100%
│    Pipeline Health                      │
│                                         │
│    Calendar            ← sichtbar (0.75)│
│    09:00 – 09:30       ← lesbar (0.9)   │
│                                         │
│  ┌ beginnt in 58 Sek. ──────────────┐  │  ← Countdown-Pill zentriert
│  └─────────────────────────────────┘  │
│                                         │
│  ┌──────────────────────────────────┐  │
│  │  📹  Teams beitreten              │  │  ← Indigo, prominent
│  └──────────────────────────────────┘  │
│                                         │
│  ┌──────────────────────────────────┐  │
│  │     Schließen                     │  │  ← Deutlich sichtbare Kontur
│  └──────────────────────────────────┘  │
│                                         │
│     🔔 In 1 Minute erneut erinnern     │  ← Lesbar (0.7)
└─────────────────────────────────────────┘
Dunkles Glass ← dark colorScheme erzwungen
```

---

## Implementation Plan

### Phase A: Design Fix — AlertOverlayView.swift

#### A1: Dark ColorScheme erzwingen (1 Zeile — größte Wirkung)

**Datei:** `Meeting Reminder/Views/AlertOverlayView.swift`

```swift
// AlertOverlayView.swift:184 — nach .shadow(...)
.shadow(color: .black.opacity(0.5), radius: 40, y: 12)
.environment(\.colorScheme, .dark)  // ← NEU: erzwingt dunkles Glas
```

Dieser eine Fix macht den größten Unterschied: Die `.ultraThinMaterial`-Karte rendert dunkel und alle `white.opacity(x)` Texte werden automatisch besser lesbar.

#### A2: Opacity-Werte korrigieren

```swift
// Uhrzeit (Zeile ~101)
.foregroundStyle(.white.opacity(0.75))   // war: 0.4

// Kalender-Name (Zeile ~124)
.foregroundStyle(.white.opacity(0.75))   // war: 0.5

// Zeitraum (Zeile ~131)
.foregroundStyle(.white.opacity(0.9))    // war: 0.6

// "via Provider" (Zeile ~268)
.foregroundStyle(.white.opacity(0.55))   // war: 0.3

// Snooze-Label "Später erinnern" (Zeile ~293)
.foregroundStyle(.white.opacity(0.6))    // war: 0.3

// Snooze-Button Text (Zeile ~304)
.foregroundStyle(.white.opacity(0.8))    // war: 0.5
```

#### A3: LIVE-Badge — solider roter Hintergrund

```swift
// AlertOverlayView.swift — liveBadge property
private var liveBadge: some View {
    HStack(spacing: 5) {
        Circle()
            .fill(.white)                          // war: .red
            .frame(width: 7, height: 7)
            .opacity(livePulse ? 1.0 : 0.5)

        Text("LIVE")
            .font(.system(size: 11, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)               // war: .red
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 5)
    .background(.red, in: Capsule())               // war: .red.opacity(0.15)
    .accessibilityLabel("Meeting läuft bereits")
}
```

#### A4: Schließen-Button — klar sichtbar

```swift
// AlertOverlayView.swift — Schließen Button
Button(action: onDismiss) {
    Text("Schließen")
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(.white.opacity(0.9))      // explizit
        .frame(maxWidth: .infinity)
        .frame(height: 38)
        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(.white.opacity(0.25), lineWidth: 1)
        )
}
.buttonStyle(.plain)                               // war: .bordered (zu unsichtbar)
.accessibilityLabel("Erinnerung schließen")
```

#### A5: Kalender-Farbbalken höher (32pt → 44pt)

```swift
// Zeile ~108
.frame(width: 4, height: 44)   // war: height: 32
```

#### A6: Snooze-Sektion polieren

```swift
private var snoozeSection: some View {
    Button(action: onSnooze) {
        HStack(spacing: 6) {
            Image(systemName: "clock.badge")
                .font(.system(size: 11))
            Text("In 1 Minute erneut erinnern")
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(.white.opacity(0.7))      // war: 0.5 Button-Text, 0.3 Label
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(.white.opacity(0.08), in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.15), lineWidth: 0.5))
    }
    .buttonStyle(.plain)
    .accessibilityLabel("In einer Minute erneut erinnern")
}
```

---

### Phase B: Offene App Store Aufgaben

#### B1: Build-Status prüfen + mit Version verknüpfen

```bash
# Build-Status prüfen (Apple braucht 5-15 Min zum Verarbeiten)
asc builds list --app 6761079659 | head -20

# Build-ID ermitteln und mit Version verknüpfen
BUILD_ID="<id-aus-obigem-command>"
asc versions builds set \
  --version a3d022c1-59a6-42e2-8803-2af7c97dc929 \
  --build "$BUILD_ID"

# Build der TestFlight-Gruppe zuweisen (Gruppe: 16ff2cfa-9713-4790-97da-14b1ecbae315)
asc testflight builds add \
  --group "16ff2cfa-9713-4790-97da-14b1ecbae315" \
  --build "$BUILD_ID"
```

> **Status:** TestFlight-Gruppe `Beta Tester` existiert, Tester `hendrikgrueger@gmail.com` + `s.mause83@gmail.com` sind hinzugefügt. Nur Build-Verknüpfung fehlt noch.

#### B2: ASC Metadaten hochladen

```bash
VERSION_ID="a3d022c1-59a6-42e2-8803-2af7c97dc929"

# Die asc-metadata Dateien sind vorhanden unter docs/asc-metadata/en-US/ + de-DE/
# Upload-Methode via ASC API direkt (da asc CLI kein locals update hat):

TOKEN=$(security find-generic-password -s asc-api-key -w 2>/dev/null)

# EN-US Localization ID ermitteln
curl -s "https://api.appstoreconnect.apple.com/v1/appStoreVersions/$VERSION_ID/appStoreVersionLocalizations" \
  -H "Authorization: Bearer $TOKEN" | jq '.data[] | {locale: .attributes.locale, id: .id}'

# Dann PATCH für jede Locale
# Dateien: docs/asc-metadata/en-US/description.txt, subtitle.txt, keywords.txt, whats_new.txt
```

**Browser-Fallback** (empfohlen für erste Einreichung):
```
Geh auf https://appstoreconnect.apple.com/apps/6761079659/appstore/macos/version/infos/de-DE
Kopiere Texte aus docs/asc-metadata/de-DE/description.txt + subtitle.txt + keywords.txt + whats_new.txt
Speichern. Gleich für en-US.
```

#### B3: Screenshots (5 für Mac App Store)

Screenshots **müssen manuell erstellt werden** — 1440×900px empfohlen.

**Demo-Overlay-Modus** für clean Screenshots:
```bash
# App starten im Demo-Modus
cd "/Users/hendrik.grueger/Coding/1_privat/Apple Apps/Meeting Reminder"
open build/Build/Products/Debug/NevLate.app --args --demo-overlay
```

**Benötigte 5 Screenshots:**
1. Vollbild-Overlay mit Teams-Meeting (Hauptfeature)
2. Tagesübersicht im Menüleisten-Popover
3. LIVE-Badge während Meeting läuft
4. Kalender-Auswahl (mehrere Kalender)
5. Overlay mit Countdown < 60 Sek (orange Pill)

**Upload:**
```bash
# Via asc CLI oder ASC Browser
asc screenshots upload --app 6761079659 --version $VERSION_ID \
  --locale en-US --file docs/screenshots/screenshot_1.png
```

#### B4: Privacy Policy deployen

Dateien existieren: `docs/privacy-policy-en.html`, `docs/privacy-policy-de.html`

**Deploy zu Alfahosting** (Skill `alfahosting` verwenden):
```bash
# Ziel: https://hendrikgrueger.de/nevrlate/privacy
ssh alfahosting "mkdir -p ~/html/nevrlate"
scp docs/privacy-policy-en.html alfahosting:~/html/nevrlate/privacy.html
```

**In ASC eintragen:**
```
Privacy Policy URL: https://hendrikgrueger.de/nevrlate/privacy
```

#### B5: Review Notes + App Store Review einreichen

```bash
VERSION_ID="a3d022c1-59a6-42e2-8803-2af7c97dc929"

# Review Notes
asc review-notes set \
  --version "$VERSION_ID" \
  --notes "Nevr Late is a macOS menu bar app that reminds users about upcoming calendar meetings and provides one-click join links for video conferences (Teams, Zoom, Google Meet, WebEx, GoTo, Slack, Whereby, Jitsi). Calendar access is read-only. No data leaves the device."

# Einreichen
asc submissions create --version "$VERSION_ID"
```

---

### Phase C: Build-System stabilisieren

Das `NevLate.xcodeproj/project.pbxproj` wurde **manuell gepatcht** (PBXResourcesBuildPhase hinzugefügt), weil xcodegen v2.44.1 keine PBXResourcesBuildPhase für macOS-Targets generiert. Nach `xcodegen generate` gehen alle Patches verloren.

**Fix: xcodegen für dieses Projekt deaktivieren**

```bash
# project.yml löschen oder umbenennen, xcodeproj ins Git aufnehmen
# Damit xcodegen nicht versehentlich ausgeführt wird

# ODER: .xcodegen-ignore Datei mit Hinweis anlegen
echo "# xcodegen generate NICHT ausführen — pbxproj manuell gepatcht" > .xcodegen-ignore
echo "# Resources Build Phase ist manuell in project.pbxproj eingefügt"
echo "# Bei Bedarf: python3 docs/scripts/patch_pbxproj.py ausführen"
```

**Besser: Patch-Script dauerhaft dokumentieren** (damit der Patch reproducibel ist):
```bash
mkdir -p docs/scripts
# patch_pbxproj.py aus /tmp/patch_pbxproj.py + /tmp/fix_paths.py in docs/scripts/ speichern
```

---

## Acceptance Criteria

### Design

- [ ] Karte rendert dunkel (dark colorScheme) auf hellem und dunklem Desktop
- [ ] Uhrzeit gut sichtbar (Kontrastverhältnis ≥ 4.5:1 auf dunklem Glas)
- [ ] Zeitraum klar lesbar
- [ ] LIVE-Badge: roter Hintergrund, weißer Text, klar erkennbar
- [ ] Schließen-Button klar sichtbar mit Kontur
- [ ] Snooze-Label und Button deutlich lesbar
- [ ] Titel weiterhin weiß und bold (100% — unverändert)
- [ ] Bestehende Tests weiterhin grün (keine Logic-Änderungen)

### App Store

- [ ] Build in TestFlight sichtbar (Status: `VALID`)
- [ ] `hendrikgrueger@gmail.com` erhält TestFlight-Einladung
- [ ] `s.mause83@gmail.com` erhält TestFlight-Einladung
- [ ] ASC Metadaten EN+DE vollständig (Description, Subtitle, Keywords, Whats New)
- [ ] 5 Screenshots für macOS in ASC
- [ ] Privacy Policy unter `https://hendrikgrueger.de/nevrlate/privacy` erreichbar
- [ ] Privacy Policy URL in ASC eingetragen
- [ ] Build mit Version verknüpft
- [ ] App für App Store Review eingereicht

---

## Offene Punkte aus vorheriger Session

| Punkt | Status | Nächster Schritt |
|-------|--------|-----------------|
| AppIcon.icns im Bundle | ✅ Behoben | pbxproj manuell gepatcht, BUILD + ARCHIVE OK |
| Archive erstellt | ✅ Done | `build/NevLate.xcarchive` |
| Build zu ASC exportiert | ✅ Done | `destination: upload` — bei Apple in Verarbeitung |
| TestFlight Gruppe | ✅ Done | ID: `16ff2cfa-9713-4790-97da-14b1ecbae315` |
| Tester hinzugefügt | ✅ Done | hendrikgrueger + s.mause83 |
| Build mit Version verknüpfen | ⏳ Pending | Warten bis Build verarbeitet + asc-Befehl |
| Build TestFlight-Gruppe zuweisen | ⏳ Pending | Nach Build-Verknüpfung |
| ASC Metadaten | ⏳ Pending | Browser oder API |
| Screenshots | ⏳ Pending | 5 Screenshots erstellen |
| Privacy Policy deployen | ⏳ Pending | Alfahosting-Upload |
| App Store Review einreichen | ⏳ Pending | Nach allem oben |
| Subscription Group in ASC | ⚠️ Manuell | ASC Browser: Produkte anlegen (CLI nicht unterstützt) |
| AlertOverlayView Design | 🎨 Neu | Dieser Plan |
| pbxproj Patch stabilisieren | ⚠️ Risiko | docs/scripts/ anlegen |

---

## Dateien, die geändert werden

```
Meeting Reminder/Views/AlertOverlayView.swift   ← Design-Fix (Phase A)
docs/scripts/patch_pbxproj.py                  ← Build-System-Docs (Phase C)
.xcodegen-ignore                               ← Verhindert versehentliches xcodegen (Phase C)
```

---

## Quick-Fix für sofortige 9/10 Wirkung

Die wichtigsten 3 Änderungen, falls alles andere zu lang dauert:

```swift
// 1. DARKGLASS: Eine Zeile, größte Wirkung
.shadow(color: .black.opacity(0.5), radius: 40, y: 12)
.environment(\.colorScheme, .dark)      // ← hinzufügen

// 2. LIVE-Badge: Solid rot
.background(.red, in: Capsule())        // war: .red.opacity(0.15)

// 3. Schließen-Button: Plain statt Bordered
.buttonStyle(.plain)                    // war: .bordered
// + foregroundStyle(.white.opacity(0.9)) zum Text
```

Mit diesen 3 Änderungen steigt das Design sofort von 3/10 auf ~7/10.
Die weiteren Opacity-Korrekturen bringen es auf 9/10.

---

## Sources

- `Meeting Reminder/Views/AlertOverlayView.swift` — aktueller Stand
- `docs/plans/2026-03-24-003-feat-testflight-appstore-submission-plan.md` — App Store Submission Plan
- `docs/app-store-listing.md` — App Store Texte EN + DE
- `docs/asc-metadata/` — Metadaten-Verzeichnis (vorhanden)
- ASC App-ID: `6761079659` | Version-ID: `a3d022c1-59a6-42e2-8803-2af7c97dc929`
- TestFlight Gruppe-ID: `16ff2cfa-9713-4790-97da-14b1ecbae315`

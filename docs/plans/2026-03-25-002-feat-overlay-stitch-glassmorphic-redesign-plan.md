---
title: "feat: Overlay Redesign nach Stitch Glassmorphic Variant 1"
type: feat
status: active
date: 2026-03-25
---

# feat: Overlay Redesign nach Stitch Glassmorphic Variant 1

## Overview

Das bestehende Vollbild-Overlay (`AlertOverlayView.swift`) wird an das Stitch-Design **"Glassmorphic Meeting Reminder Variant 1"** (Projekt ID: `4711719281172504768`, Screen ID: `8aa5d78f61644ca5bf289a4b44894a18`) angepasst.

Das Stitch-Design zeigt ein **helles Glassmorphic-Design** (weißes Frosted-Glass, dunkler Text) im Gegensatz zur aktuellen dunklen Variante. Das Design wurde mit dem realen Overlay-Screenshot validiert — die aktuelle Implementierung ist bereits gut, aber das Stitch-Konzept ist klarer und moderner.

**Stitch Design Screenshot:** `docs/stitch/glassmorphic-variant-1.png`
**Stitch Project:** QuickJoin — Meeting Reminder Overlay Redesign

---

## Stitch Design vs. Aktuelle Implementierung

| Element | Stitch Design | Aktuell |
|---------|--------------|---------|
| **Farbschema** | Hell (weiß/frosted), dunkler Text | Dunkel (`.environment(\.colorScheme, .dark)`, weißer Text) |
| **Uhrzeit oben** | Nicht vorhanden | `13:59:09` monospaced |
| **Kalender-Farbbalken** | Nicht vorhanden | 4pt × 44pt blauer Balken links vom Titel |
| **Titel** | Groß (~30pt), dunkel, volle Breite | 28pt bold, weiß, mit Farbbalken links |
| **Zeitformat** | `14:00 – 17:15 (10.03.)` mit Datum | `14:00 – 17:15` ohne Datum |
| **Countdown** | Orange Dot + "beginnt in 50 Sek." | Pill mit dynamischer Farbe (cyan/orange/rot/grün) |
| **Provider-Info** | MS Teams Icon + "MS Teams" Text zwischen Countdown und Button | "via Teams" klein unter dem Join-Button |
| **Join-Button** | Solid Blau (#3B82F6 ähnlich), weiß Text, kein Glass | Indigo `.borderedProminent` + `.glassEffect()` |
| **Schließen-Button** | Weiß/transparent Outline, dunkler Text, kein Glass | Plain white mit `0.1` Background |
| **Snooze** | Zwei kleine Text-Elemente nebeneinander: "Später erinnern" | "In 1 Minute" | Vertikale Sektion mit Label + Capsule-Button |
| **LIVE Badge** | Nicht gezeigt (inaktiv im Design) | Roter Capsule oben rechts |
| **Hintergrund** | Leichtes Frosted-Blur | `.black.opacity(0.65)` + `.ultraThinMaterial` |

---

## Problem Statement

Das aktuelle Design ist funktional (wurde von 3/10 auf ~7/10 verbessert), aber das Stitch-Konzept bietet eine klarere visuelle Hierarchie und ein leichteres, moderneres Erscheinungsbild. Das helle Glassmorphic-Design:

1. **Bessere Lesbarkeit** bei hellen Desktop-Hintergründen
2. **Klarere Hierarchie** — Titel dominiert, keine ablenkende Uhrzeit oben
3. **Kompakter** — Snooze als horizontale Text-Buttons statt eigener Sektion
4. **System-konformer** — macOS Glassmorphic ist standardmäßig hell

---

## Proposed Solution

Refaktorierung von `AlertOverlayView.swift` in 3 Implementierungs-Einheiten:

### Phase A — Farb- und Theme-Wechsel
- Entferne `.environment(\.colorScheme, .dark)` vom Card-Container
- Card nutzt systemseitigen Glaseffekt (hell)
- Hintergrund-Dimm anpassen: weniger schwarz (`.black.opacity(0.4)` statt 0.65)

### Phase B — Layout-Änderungen
- **Entferne** Uhrzeit-Block oben
- **Entferne** Kalender-Farbbalken (4pt × 44pt bar)
- **Titel** → full-width, dunkle Textfarbe (primary), größer (30pt bold)
- **Zeitformat** → Datum hinzufügen: `"HH:mm – HH:mm (DD.MM.)"`
- **Provider-Info** → Zwischen Countdown und Join-Button verschieben

### Phase C — Button und Snooze Redesign
- **Join-Button** → Solid Blau (`Color(red: 0.23, green: 0.51, blue: 0.96)` = #3B82F6), kein `.glassEffect()`
- **Schließen-Button** → Outline mit `.strokeBorder`, dunkler Text (`.primary`)
- **Snooze** → Horizontales `HStack` mit zwei `Button`s als Text-Links

---

## Implementation Units

### Unit A1 — Theme & Background

**Datei:** `Meeting Reminder/Views/AlertOverlayView.swift`

**Änderungen:**
```swift
// ENTFERNEN: .environment(\.colorScheme, .dark)

// ÄNDERN: Hintergrund-Dimm
Rectangle()
    .fill(.black.opacity(0.4))  // war 0.65
    .overlay(
        Rectangle()
            .fill(.ultraThinMaterial)
            .opacity(0.6)  // war 0.5
    )
```

**Verification:** App zeigt helles Glas-Overlay bei hellem Desktop-Hintergrund. Dunkle Textfarben lesbar.

---

### Unit A2 — Uhrzeit und Farbbalken entfernen

**Datei:** `Meeting Reminder/Views/AlertOverlayView.swift`

**Entfernen:**
- Gesamter Uhrzeit-Block (Text mit `.dateTime.hour...second...`, `.padding(.bottom, 28)`)
- Kalender-Farbbalken (`RoundedRectangle(cornerRadius: 2).fill(event.calendarColor).frame(width: 4, height: 44)`)
- Timer-State `@State private var now: Date = .now` NICHT entfernen (noch für Countdown nötig)

**Titel-Anpassung:**
```swift
// ÄNDERN: Titel ohne HStack (kein Farbbalken mehr)
Text(event.title)
    .font(.system(size: 30, weight: .bold, design: .default))
    .foregroundStyle(.primary)  // war .white
    .lineLimit(2)
    .multilineTextAlignment(.center)
    .frame(maxWidth: .infinity)
    .padding(.bottom, 4)
```

**Verification:** Kein Uhrzeit-Block oben, kein Farbbalken links. Titel läuft full-width.

---

### Unit B1 — Zeitformat mit Datum

**Datei:** `Meeting Reminder/Views/AlertOverlayView.swift`

**Änderung in `timeRange`:**
```swift
private var timeRange: String {
    let timeFmt = DateFormatter()
    timeFmt.dateFormat = "HH:mm"
    let dateFmt = DateFormatter()
    dateFmt.dateFormat = "dd.MM."
    return "\(timeFmt.string(from: event.startDate)) – \(timeFmt.string(from: event.endDate)) (\(dateFmt.string(from: event.startDate)))"
}
```

**Verification:** Zeitraum zeigt `"14:00 – 17:15 (25.03.)"`.

---

### Unit B2 — Provider-Info-Verschiebung

**Datei:** `Meeting Reminder/Views/AlertOverlayView.swift`

Provider-Anzeige wird **zwischen Countdown-Pill und Join-Button** platziert (war: klein unter dem Button):

```swift
// Nach countdownPill, vor actionButtons:
if let meetingLink = event.meetingLink {
    HStack(spacing: 6) {
        Image(systemName: meetingLink.provider.iconName)
            .font(.system(size: 13))
        Text(meetingLink.provider.rawValue)
            .font(.system(size: 13, weight: .medium))
    }
    .foregroundStyle(.secondary)
    .padding(.bottom, 16)
}
```

Der `"via Provider"` Hint unter dem Join-Button entfällt.

**Verification:** "MS Teams" Icon + Name steht zentriert zwischen Countdown und Button.

---

### Unit C1 — Join-Button Redesign

**Datei:** `Meeting Reminder/Views/AlertOverlayView.swift`

```swift
// Join Button (war: .borderedProminent + .tint(.indigo) + .glassEffect())
Button(action: onJoin) {
    HStack(spacing: 8) {
        Image(systemName: meetingLink.provider.iconName)
            .font(.system(size: 14, weight: .semibold))
        Text(meetingLink.provider.joinLabel)
            .font(.system(size: 16, weight: .semibold))
    }
    .foregroundStyle(.white)
    .frame(maxWidth: .infinity)
    .frame(height: 44)
    .background(Color(red: 0.23, green: 0.51, blue: 0.96), in: RoundedRectangle(cornerRadius: 12))
}
.buttonStyle(.plain)
.accessibilityLabel(meetingLink.provider.accessibilityJoinLabel)
```

**Verification:** Solid-blauer Button, kein Glass-Overlay. Weißer Text gut lesbar.

---

### Unit C2 — Schließen-Button Redesign

**Datei:** `Meeting Reminder/Views/AlertOverlayView.swift`

```swift
// Schließen (war: .white.opacity(0.1) + .white.opacity(0.3) border)
Button(action: onDismiss) {
    Text("Schließen")
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(.primary)  // dunkler Text
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(.clear, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.secondary.opacity(0.4), lineWidth: 1)
        )
}
.buttonStyle(.plain)
.accessibilityLabel("Erinnerung schließen")
```

---

### Unit C3 — Snooze Redesign (Horizontal)

**Datei:** `Meeting Reminder/Views/AlertOverlayView.swift`

```swift
private var snoozeSection: some View {
    HStack(spacing: 16) {
        Button(action: onDismiss) {
            Text("Später erinnern")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)

        Text("|")
            .font(.system(size: 12))
            .foregroundStyle(.tertiary)

        Button(action: onSnooze) {
            Text("In 1 Minute erneut erinnern")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("In einer Minute erneut erinnern")
    }
    .padding(.bottom, 4)
}
```

**Verification:** Zwei Text-Buttons in einer Zeile, kein Capsule-Hintergrund.

---

## Files Changed

| Datei | Änderung |
|-------|----------|
| `Meeting Reminder/Views/AlertOverlayView.swift` | Hauptdatei — alle oben beschriebenen Änderungen |

Keine weiteren Dateien betroffen. Alle anderen Views (PaywallView, SettingsView, etc.) bleiben unverändert.

---

## Acceptance Criteria

- [ ] Card erscheint als helles Glassmorphic (weißes/frosted Glas) über dem Desktophintergrund
- [ ] Keine Uhrzeit mehr im Header
- [ ] Kein Kalender-Farbbalken links vom Titel
- [ ] Titel ist dunkel (`.primary`) und läuft full-width
- [ ] Zeitraum enthält Datum: `"14:00 – 17:15 (25.03.)"`
- [ ] Provider-Name (Icon + Text) steht zentriert zwischen Countdown und Join-Button
- [ ] Join-Button ist solid blau (#3B82F6 ähnlich), weißer Text, kein Glaseffekt
- [ ] Schließen-Button hat outline mit dunklem Text
- [ ] Snooze-Sektion ist horizontal: "Später erinnern | In 1 Minute erneut erinnern"
- [ ] LIVE Badge funktioniert weiterhin (bleibt oben rechts, rote Kapsel)
- [ ] Countdown-Pill funktioniert weiterhin (Farb-Eskalation bei Dringlichkeit)
- [ ] Reduce Motion respektiert
- [ ] Accessibility-Labels korrekt
- [ ] Alle bestehenden Tests (153) laufen weiterhin grün

## Non-Goals (Nicht-Ziele)

- **Kein** Entfernen der LIVE Badge Funktionalität
- **Kein** Entfernen des Countdown-Farbsystems
- **Keine** Änderung an OverlayPanel, OverlayController, SettingsView
- **Keine** Änderung an PaywallView
- **Kein** Redesign des Menüleisten-Popovers

---

## Dependencies & Risks

| Risiko | Wahrscheinlichkeit | Mitigation |
|--------|--------------------|------------|
| Helles Glass schlechter lesbar bei hellem Desktop | Mittel | Stitch-Design validiert an MS-Teams-Screenshot — sieht gut aus |
| `countdownPill` Farben (orange/red) auf hellem Glass weniger kontrastreich | Mittel | Opacity erhöhen oder Hintergrund-Tint anpassen (test nötig) |
| LIVE Badge (weiß auf rot) auf hellem Glass anders aussehend | Gering | Badge hat eigenen roten Hintergrund — unbeeinflusst |

---

## Sources & References

- **Stitch Design:** `docs/stitch/glassmorphic-variant-1.png` (1376×768px)
- **Stitch Project ID:** `4711719281172504768`
- **Stitch Screen ID:** `8aa5d78f61644ca5bf289a4b44894a18`
- **Aktueller Code:** `Meeting Reminder/Views/AlertOverlayView.swift`
- **Screenshot aktuell:** `docs/screenshots/02_current_state.png`
- **Referenz-Screenshot (Teams-Overlay):** User-Screenshot 2026-03-25 13:59:09

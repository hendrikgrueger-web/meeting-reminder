# App Store Launch — Nevr Late (Freemium)

> Erstellt: 2026-03-22

## Überblick

Meeting Reminder (intern "QuickJoin") wird unter dem Namen **"Nevr Late — Meeting Reminder"** im Mac App Store veröffentlicht. Freemium-Modell: erste 50 Meeting-Reminders kostenlos, danach Abo-Pflicht.

---

## 1. Rebranding

| Feld | Alt | Neu |
|------|-----|-----|
| App-Name | QuickJoin | Nevr Late |
| Bundle-ID | de.hendrikgrueger.quickjoin | de.hendrikgrueger.nevrlate |
| Product-ID (monatlich) | de.gruepi.quickjoin.premium.monthly | de.hendrikgrueger.nevrlate.premium.monthly |
| Product-ID (jährlich) | de.gruepi.quickjoin.premium.annual | de.hendrikgrueger.nevrlate.premium.annual |
| App Store Name | — | "Nevr Late — Meeting Reminder" (28/30) |

Betroffen: `project.yml`, `MeetingReminderApp.swift`, Usage Descriptions in Info.plist, Landing Page, Privacy Policy, App Store Texte.
LICENSE-Datei entfernen (CC BY-NC 4.0 → Apple Standard-EULA).

---

## 2. Freemium-Architektur

### Zählung

- Jedes **unique Meeting** zählt einmal (zusammengesetzter Key: `eventIdentifier + startDate`)
- Snooze = kein erneutes Zählen
- Counter ist **lifetime** (wird bei Abo-Kündigung nicht zurückgesetzt)
- Free Tier: **50 Reminders**

### Entscheidungslogik

```
pendingEvent vorhanden
  └─ ReminderCounter.canShow(event)?
       ├─ JA (< 50 oder bekanntes Event oder aktives Abo)
       │    → AlertOverlayView anzeigen, Counter erhöhen
       └─ NEIN (≥ 50 unique Events, kein Abo)
            → PaywallView anzeigen
```

### Neue Dateien

| Datei | Zweck |
|-------|-------|
| `Services/ReminderCounter.swift` | Lifetime-Counter mit UserDefaults-Persistenz |
| `Services/StoreKitService.swift` | Subscription-Management via StoreKit 2 |
| `Views/PaywallView.swift` | Vollbild-Paywall als NSPanel-Overlay |

---

## 3. ReminderCounter

- `shownEventIDs: Set<String>` → in UserDefaults gespeichert
- `canShow(event:)` → event.id ∈ shownEventIDs OR count < 50 OR StoreKitService.shared.hasActiveSubscription
- `record(event:)` → fügt event.id ein (nur wenn neu)
- `count` → shownEventIDs.count

---

## 4. StoreKitService

- Singleton, `@MainActor`
- `@Published var hasActiveSubscription: Bool`
- `products: [Product]` (monthly + annual)
- `startListening()` → `Transaction.updates` Task beim App-Start
- `purchase(_ product:) async throws`
- `restorePurchases() async throws` → `AppStore.sync()`
- `checkEntitlements() async` → iteriert `Transaction.currentEntitlements`

---

## 5. PaywallView

Vollbild-Overlay (identisches NSPanel wie AlertOverlayView):
- Hintergrund: gleicher Blur wie reguläres Overlay
- Karte (`.glassEffect()`):
  - Meeting-Titel + Uhrzeit (ausgegraut — zeigt was fehlt)
  - Trennlinie
  - "Nevr Late Premium" Heading
  - "Du hast 50 Meeting-Erinnerungen verbraucht."
  - Jahresplan-Button: "7,99 €/Jahr" + "Spare 33%" Badge (primär)
  - Monatsplan-Button: "0,99 €/Monat" (sekundär)
  - "Käufe wiederherstellen" Link (Apple Review-Pflicht)
- Escape → schließt Paywall (Event gilt als dismissed)

---

## 6. App Store Texte

- App Store Name: "Nevr Late — Meeting Reminder" (28/30)
- Subtitle EN: "Join Teams, Zoom & Meet Fast" (28/30)
- Subtitle DE: "Für Teams, Zoom & Google Meet" (29/30)
- Keywords: 100 Zeichen vollständig ausgeschöpft (EN + DE)
- Subscription Legal Copy obligatorisch in Descriptions

---

## 7. App Store Connect Setup

- Bundle-ID registrieren: `de.hendrikgrueger.nevrlate`
- Subscription Group: "Nevr Late Premium"
- Produkte: monthly (0,99 €) + annual (7,99 €)
- Xcode Cloud: Push main → TestFlight
- Kategorie: Productivity / Utilities
- Alter: 4+
- macOS 26+

---

## Bewertungssystem Screenshots (max. 20 Punkte je Screenshot)

| Kriterium | Punkte |
|-----------|--------|
| Overlay/Feature klar erkennbar | 0–5 |
| Professionelles, attraktives UI | 0–4 |
| Lesbarkeit auf Thumbnail | 0–4 |
| Marketing-Botschaft transportiert | 0–4 |
| Keine Clutter / Ablenkungen | 0–3 |

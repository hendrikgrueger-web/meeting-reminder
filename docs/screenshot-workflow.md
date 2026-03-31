# App-Store-Screenshot-Workflow

> Gilt für alle Apple-Apps in diesem Workspace.

## Technik

Screenshots werden als **self-contained HTML-Dateien** erstellt und mit **Playwright** (Chromium) auf exakt **1440×900 px** (Mac App Store) bzw. **1290×2796 px** (iPhone 16 Pro) gerendert.

### Render-Befehl (Mac, 1440×900)

```bash
SDIR="<app>/docs/screenshots"
for i in 1 2 3 4 5; do
  HTML=$(ls "$SDIR/screenshot_${i}_"*.html | head -1)
  npx playwright screenshot --viewport-size="1440,900" --wait-for-timeout=600 \
    "file://$HTML" "$SDIR/appstore_${i}.png"
done
```

### Einmalige Installation

```bash
npx playwright install chromium
```

### HTML-Datei-Konvention

```
docs/screenshots/
├── screenshot_1_hero.html        # Quellcode (versioniert)
├── screenshot_2_overlay.html
├── screenshot_3_provider.html
├── screenshot_4_today.html
├── screenshot_5_settings.html
├── appstore_1.png                # Gerendertes Bild (für ASC)
├── appstore_2.png
├── ...
├── en/                           # Englische Versionen
│   ├── screenshot_1_hero.html
│   └── appstore_1.png
└── de/                           # Deutsche Versionen (falls Hauptordner = EN)
```

### HTML-Anforderungen

- `<meta name="viewport" content="width=1440">`
- `body { width: 1440px; height: 900px; overflow: hidden; }`
- Self-contained: kein externes CSS/JS/Fonts
- Keine `backdrop-filter`-Abhängigkeiten von externen Bildern
- Glassmorphism: `background: rgba(255,255,255,0.90–0.95)` für helle Karten auf dunklem BG

---

## Bewertungsmatrix (20 Punkte)

Jeder Screenshot muss **≥ 17/20** erreichen bevor er in ASC hochgeladen wird.

| Kriterium | Max | Leitfragen |
|---|---|---|
| **Botschaftsklarheit** | 4 | Versteht man in 2 Sek. was die App macht? |
| **Visueller Wow-Faktor** | 4 | Fällt es im Store-Grid positiv auf? |
| **Design-Qualität** | 4 | Typografie, Spacing, Kontrast, Hierarchie stimmig? |
| **Apple/Mac-Feel** | 3 | Wirkt es nativ und Apple-würdig? |
| **Textstärke** | 3 | Trifft die Headline den Nerv? Ist der Nutzen sofort klar? |
| **Inhaltliche Ehrlichkeit** | 2 | Nur Features zeigen, die wirklich existieren |

### Typische Abzüge

- Emoji statt echter Icons: −1 bis −2 Wow-Faktor
- Generischer Gradient ohne Tiefe: −1 Design
- Monetarisierung/Pricing in Screenshots: −2 Ehrlichkeit
- Karte zu dunkel / zu wenig Kontrast zur BG: −1 bis −2
- Schwache Caption: −1 Textstärke

---

## Iteration bis ≥ 17/20

1. HTML schreiben → rendern → als Bild begutachten
2. Bewertungsmatrix ausfüllen
3. Kriterien unter 3/4 oder unter 2/3 fixen
4. Erneut rendern — wiederholen bis alle Screens ≥ 17/20

---

## Sprachen

**Screenshots mit Text müssen in ALLEN App-Sprachen erstellt werden.**

Aktuell unterstützte Locales (Meeting Reminder / Nevr Late):
- `de-DE` — Deutsch (primär)
- `en-US` — Englisch

Workflow:
1. Deutsche HTML-Dateien: `docs/screenshots/screenshot_N_*.html`
2. Englische HTML-Dateien: `docs/screenshots/en/screenshot_N_*.html`
3. Render-Befehl für jede Sprache separat ausführen
4. In ASC: Screenshots per Locale zuweisen (`de-DE` → deutsche PNGs, `en-US` → englische PNGs)

### ASC Upload

```bash
# Einzelner Screenshot hochladen (DE)
asc screenshots upload \
  --app APP_ID \
  --version-id VERSION_ID \
  --locale de-DE \
  --display-type APP_DESKTOP \
  --file docs/screenshots/appstore_1.png

# Bulk via Loop
for i in 1 2 3 4 5; do
  asc screenshots upload --app APP_ID --version-id VERSION_ID \
    --locale de-DE --display-type APP_DESKTOP \
    --file "docs/screenshots/appstore_${i}.png"
done
```

---

## Meeting Reminder / Nevr Late — Screenshot-Konzepte

| # | Datei | Botschaft | Kerninhalt |
|---|---|---|---|
| 1 | `screenshot_1_hero` | "Nie wieder ein Meeting verpassen." | App-Badge + Headline + Features + floating Card |
| 2 | `screenshot_2_overlay` | Das Overlay in Aktion | Vollbild-Overlay mit LIVE-Badge, großer Zeit, Beitreten-Button |
| 3 | `screenshot_3_provider` | "Ein Klick. Jedes Meeting." | Triptychon: 3 Karten mit Teams/Zoom/Meet-Buttons + Provider-Chips |
| 4 | `screenshot_4_today` | "Dein Tag im Blick." | Menüleisten-Popover mit Tagesübersicht |
| 5 | `screenshot_5_settings` | "Deine Kalender, deine Regeln." | Einstellungs-Popover mit Kalender-Toggles |

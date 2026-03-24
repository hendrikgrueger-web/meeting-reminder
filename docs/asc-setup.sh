#!/bin/bash
# asc-setup.sh — Nevr Late App Store Connect Setup
# Ausführen NACH App-Erstellung im Browser (Schritt 1 des Cowork-Prompts)
# Usage: APP_ID=<deine-app-id> VERSION_ID=<deine-version-id> bash docs/asc-setup.sh

set -e

APP_ID="${APP_ID:?APP_ID muss gesetzt sein (z.B. APP_ID=1234567890)}"
VERSION_ID="${VERSION_ID:?VERSION_ID muss gesetzt sein — asc versions list --app $APP_ID}"

echo "=== Nevr Late — App Store Connect Setup ==="
echo "App ID: $APP_ID"
echo "Version ID: $VERSION_ID"
echo ""

# 1. Kategorie: Productivity (primär) + Utilities (sekundär)
echo "--- [1/4] Kategorie setzen..."
asc categories set --app "$APP_ID" --primary PRODUCTIVITY --secondary UTILITIES

# 2. Age Rating: 4+ (keine bedenklichen Inhalte)
echo "--- [2/4] Age Rating 4+ setzen..."
asc age-rating set --app "$APP_ID" \
  --gambling false \
  --alcohol false \
  --tobacco false \
  --violence-cartoon false \
  --violence-realistic false \
  --sexual-content false \
  --nudity false \
  --horror false \
  --profanity false \
  --contests false \
  --social-networking false \
  --user-generated-content false \
  --unrestricted-web-access false

# 3. Metadata pushen (Descriptions, Keywords, Subtitles)
# Erwartet: docs/asc-metadata/ mit en-US/ und de-DE/ Unterordnern
echo "--- [3/4] Metadata hochladen..."
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
asc metadata push \
  --app "$APP_ID" \
  --version "$VERSION_ID" \
  --dir "$SCRIPT_DIR/asc-metadata"

# 4. Pricing: Free, alle Länder
echo "--- [4/4] Pricing: Free, weltweit..."
# Free = kein Price Schedule nötig — App ist standardmäßig kostenlos bei 0-Preis
# Availability auf alle Länder prüfen:
asc pricing availability get --app "$APP_ID"

echo ""
echo "✓ Setup abgeschlossen!"
echo ""
echo "Nächste Schritte (manuell):"
echo "  1. App Icon hochladen (1024x1024 PNG) in App Store Connect"
echo "  2. Screenshots hochladen (5 Stück, 1440x900 oder 1280x800)"
echo "  3. Privacy Policy URL eintragen: https://hendrikgrueger.de/nevrlate/privacy"
echo "  4. Support URL eintragen: https://github.com/hendrikgrueger-web/meeting-reminder/issues"
echo "  5. Xcode Cloud Pipeline einrichten (in Xcode → Integrations)"
echo "  6. Ersten Build archivieren + hochladen"

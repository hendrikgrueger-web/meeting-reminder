#!/bin/bash
# ci_post_clone.sh — Xcode Cloud Post-Clone Script
# Wird nach dem Git-Clone ausgeführt, vor dem Build.

set -e

echo "🔧 [Nevr Late] Post-Clone: XcodeGen installieren + Projekt generieren..."

# XcodeGen installieren (falls nicht vorhanden)
if ! command -v xcodegen &> /dev/null; then
    echo "📦 XcodeGen via Homebrew installieren..."
    brew install xcodegen
fi

# Xcode-Projekt aus project.yml generieren
echo "⚙️ XcodeGen: Projekt generieren..."
cd "$CI_PRIMARY_REPOSITORY_PATH"
xcodegen generate

echo "✅ [Nevr Late] Post-Clone abgeschlossen."

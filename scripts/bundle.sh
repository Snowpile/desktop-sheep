#!/bin/bash
# Builds a release binary and wraps it into "Desktop Sheep.app" (ad-hoc signed).
# Usage: scripts/bundle.sh [output-dir]   (default: ./dist)
set -euo pipefail

cd "$(dirname "$0")/.."
OUT_DIR="${1:-dist}"
APP="$OUT_DIR/Desktop Sheep.app"
VERSION="${VERSION:-0.1.0}"

swift build -c release
BIN="$(swift build -c release --show-bin-path)/DesktopSheep"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/DesktopSheep"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Desktop Sheep</string>
    <key>CFBundleDisplayName</key><string>Desktop Sheep</string>
    <key>CFBundleIdentifier</key><string>com.snowpile.desktop-sheep</string>
    <key>CFBundleExecutable</key><string>DesktopSheep</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSHumanReadableCopyright</key><string>Copyright © 2026 Erik Forsman. MIT License.</string>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"
codesign --verify "$APP"
echo "Built $APP"

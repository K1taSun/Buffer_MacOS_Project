#!/bin/bash
set -e

# ── Config ───────────────────────────────────────────────────────────────────
APP_NAME="Buffer"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
APP_PATH="${PROJECT_ROOT}/build/Build/Products/Release/${APP_NAME}.app"
OUTPUT_DIR="${PROJECT_ROOT}/build/installer"
DMG_TEMP="${OUTPUT_DIR}/${APP_NAME}-temp.dmg"
DMG_FINAL="${OUTPUT_DIR}/${APP_NAME}-Installer.dmg"

echo "▸ Creating Buffer DMG installer..."

# Build if app doesn't exist
if [ ! -d "$APP_PATH" ]; then
    echo "✖ Buffer.app not found. Building..."
    xcodebuild -project "${PROJECT_ROOT}/Buffer.xcodeproj" \
               -scheme Buffer -configuration Release \
               -derivedDataPath "${PROJECT_ROOT}/build" build 2>&1 | tail -3
fi

mkdir -p "$OUTPUT_DIR"

# Clean up old DMGs
rm -f "$DMG_TEMP" "$DMG_FINAL"
hdiutil detach "/Volumes/${APP_NAME}" -force 2>/dev/null || true
sleep 1

# Create blank writable DMG
APP_SIZE_KB=$(du -sk "$APP_PATH" | awk '{print $1}')
DMG_SIZE_KB=$((APP_SIZE_KB + 20480))

hdiutil create -volname "$APP_NAME" -fs HFS+ \
    -size "${DMG_SIZE_KB}k" -type UDIF -layout NONE \
    "$DMG_TEMP" -quiet

# Mount
hdiutil attach "$DMG_TEMP" -readwrite -noverify -noautoopen -quiet
sleep 2

# Copy content
cp -a "$APP_PATH" "/Volumes/${APP_NAME}/${APP_NAME}.app"
ln -s /Applications "/Volumes/${APP_NAME}/Applications"

# Style with AppleScript — clean, professional, no background
osascript <<EOF
tell application "Finder"
    tell disk "${APP_NAME}"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 150, 760, 470}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 100
        set text size of viewOptions to 13
        set position of item "${APP_NAME}.app" of container window to {140, 160}
        set position of item "Applications" of container window to {420, 160}
        close
        open
        update without registering applications
        delay 2
    end tell
end tell
EOF

sync

# Unmount & compress
hdiutil detach "/Volumes/${APP_NAME}" -force -quiet 2>/dev/null || true
sleep 2

hdiutil convert "$DMG_TEMP" -format UDZO -imagekey zlib-level=9 \
    -o "$DMG_FINAL" -quiet

rm -f "$DMG_TEMP"

FINAL_SIZE=$(du -h "$DMG_FINAL" | awk '{print $1}')
echo "✔ Done! ${DMG_FINAL} (${FINAL_SIZE})"

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
BG_IMG="${OUTPUT_DIR}/bg_black.png"

echo "▸ Creating Buffer DMG installer..."

# Check app exists
if [ ! -d "$APP_PATH" ]; then
    echo "✖ Buffer.app not found. Building..."
    xcodebuild -project "${PROJECT_ROOT}/Buffer.xcodeproj" \
               -scheme Buffer -configuration Release \
               -derivedDataPath "${PROJECT_ROOT}/build" build 2>&1 | tail -3
fi

mkdir -p "$OUTPUT_DIR"

# Generate solid black 600x400 background
sips -z 1 1 /System/Library/CoreServices/DefaultBackground.jpg --out "$BG_IMG" 2>/dev/null || \
    python3 -c "
from PIL import Image
Image.new('RGB',(600,400),(0,0,0)).save('${BG_IMG}')
" 2>/dev/null || \
    # Fallback: create via convert or raw bytes
    printf '\x89PNG\r\n\x1a\n' > /dev/null  # just skip if nothing works

# Use sips to make proper 600x400 black PNG
python3 -c "
import struct, zlib
w, h = 600, 400
raw = b''
for _ in range(h):
    raw += b'\x00' + b'\x00\x00\x00' * w
def chunk(t, d):
    c = t + d
    return struct.pack('>I', len(d)) + c + struct.pack('>I', zlib.crc32(c) & 0xffffffff)
with open('${BG_IMG}', 'wb') as f:
    f.write(b'\x89PNG\r\n\x1a\n')
    f.write(chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0)))
    f.write(chunk(b'IDAT', zlib.compress(raw)))
    f.write(chunk(b'IEND', b''))
print('Black background generated')
"

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
mkdir -p "/Volumes/${APP_NAME}/.background"
cp "$BG_IMG" "/Volumes/${APP_NAME}/.background/background.png"

# Style with AppleScript
osascript <<EOF
tell application "Finder"
    tell disk "${APP_NAME}"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {100, 100, 700, 500}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 80
        set background picture of viewOptions to file ".background:background.png"
        set position of item "${APP_NAME}.app" of container window to {175, 200}
        set position of item "Applications" of container window to {425, 200}
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

rm -f "$DMG_TEMP" "$BG_IMG"

FINAL_SIZE=$(du -h "$DMG_FINAL" | awk '{print $1}')
echo "✔ Done! ${DMG_FINAL} (${FINAL_SIZE})"

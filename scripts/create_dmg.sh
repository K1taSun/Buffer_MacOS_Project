#!/bin/bash

# Buffer DMG Creation Script
# This script builds the Buffer app in Release mode and packages it into a styled DMG.

set -e

# --- Configuration ---
APP_NAME="Buffer"
PROJECT_NAME="Buffer"
SCHEME="Buffer"
dmg_background_path="assets/dmg_background.png"
dmg_temp_dir="build/dmg_temp"
dmg_output_name="Buffer.dmg"
final_dmg="Buffer_Installer.dmg"

echo "🚀 Starting DMG creation process for ${APP_NAME}..."

# 1. Clean and Build
echo "🧹 Cleaning and building ${APP_NAME} in Release mode..."
rm -rf build/
rm -f "${dmg_output_name}" "${final_dmg}"

xcodebuild -project "${PROJECT_NAME}.xcodeproj" \
           -scheme "${SCHEME}" \
           -configuration Release \
           -derivedDataPath build \
           build

APP_PATH="build/Build/Products/Release/${APP_NAME}.app"

if [ ! -d "${APP_PATH}" ]; then
    echo "❌ Error: App bundle not found at ${APP_PATH}"
    exit 1
fi

echo "✅ Build successful."

# 2. Prepare staging directory
echo "📁 Preparing staging directory..."
mkdir -p "${dmg_temp_dir}"
cp -R "${APP_PATH}" "${dmg_temp_dir}/"
ln -s /Applications "${dmg_temp_dir}/Applications"

# Add background
mkdir -p "${dmg_temp_dir}/.background"
cp "${dmg_background_path}" "${dmg_temp_dir}/.background/background.png"

# 3. Create temporary writable DMG
echo "💿 Creating temporary writable DMG..."
hdiutil create -srcfolder "${dmg_temp_dir}" -volname "${APP_NAME}" -fs HFS+ \
        -fsargs "-c c=64,a=16,e=16" -format UDRW -size 300m temp.dmg

echo "📂 Mounting DMG for styling..."
device=$(hdiutil attach -readwrite -noverify "temp.dmg" | egrep '^/dev/' | sed 1q | awk '{print $1}')
sleep 2 # Wait for mount

# 4. Style with AppleScript
echo "🎨 Applying styles via AppleScript..."
osascript <<EOT
tell application "Finder"
    tell disk "${APP_NAME}"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {400, 100, 1000, 700}
        set viewOptions to the icon view options of container window
        set icon size of viewOptions to 120
        set arrangement of viewOptions to not arranged
        set background picture of viewOptions to file ".background:background.png"
        
        # Position icons
        # {x, y} relative to window
        set position of item "${APP_NAME}.app" to {180, 420}
        set position of item "Applications" to {420, 420}
        
        close
        open
        delay 1
    end tell
end tell
EOT

echo "🔒 Finalizing DMG..."
chmod -Rf go-w /Volumes/"${APP_NAME}" || true
sync
hdiutil detach "${device}"

# 5. Convert to read-only compressed format
echo "📦 Converting to final compressed format..."
hdiutil convert "temp.dmg" -format UDZO -imagekey zlib-level=9 -o "${final_dmg}"
rm "temp.dmg"
rm -rf "${dmg_temp_dir}"

echo "✨ DMG created successfully: ${final_dmg}"

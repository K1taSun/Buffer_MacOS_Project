#!/bin/bash

# Buffer macOS Project Build Script
# This script helps build and test the Buffer clipboard manager

set -e

echo "🔧 Building Buffer macOS Project..."

# Check if Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ Xcode is not installed or not in PATH"
    echo "Please install Xcode from the App Store"
    exit 1
fi

# Check if we're in the right directory
if [ ! -f "Buffer.xcodeproj/project.pbxproj" ]; then
    echo "❌ Not in the correct directory. Please run this script from the project root."
    exit 1
fi

# Clean previous builds
echo "🧹 Cleaning previous builds..."
rm -rf build/
rm -rf DerivedData/

# Build the project
echo "🏗️  Building project..."
xcodebuild -project Buffer.xcodeproj \
           -scheme Buffer \
           -configuration Debug \
           -derivedDataPath build \
           build

if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    echo "📱 App built at: build/Build/Products/Debug/Buffer.app"
    
    # Optional: Open the app
    read -p "🚀 Would you like to open the app? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        open build/Build/Products/Debug/Buffer.app
    fi
else
    echo "❌ Build failed!"
    exit 1
fi 
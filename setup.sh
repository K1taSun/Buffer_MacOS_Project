#!/bin/bash

# Setup script for Buffer macOS app development

echo "Setting up Buffer macOS app development environment..."

# Check if we're in the right directory
if [ ! -f "Buffer.xcodeproj/project.pbxproj" ]; then
    echo "Error: Please run this script from the project root directory."
    exit 1
fi

# Check if Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    echo "Warning: xcodebuild not found. Please install Xcode for full development support."
    echo "You can still view and edit the code, but building will require Xcode."
fi

# Check if Swift is available
if command -v swift &> /dev/null; then
    echo "✓ Swift compiler found"
    
    # Test compilation of Swift files
    echo "Testing Swift compilation..."
    swiftc -parse Buffer/Models/ClipboardItem.swift Buffer/Managers/ClipboardManager.swift Buffer/Managers/WindowManager.swift Buffer/Views/ClipboardView.swift Buffer/Helpers/ClipboardItemNameHelper.swift Buffer/BufferApp.swift
    
    if [ $? -eq 0 ]; then
        echo "✓ All Swift files compile successfully"
    else
        echo "✗ Some Swift files have compilation errors"
    fi
else
    echo "✗ Swift compiler not found"
fi

# Check project structure
echo "Checking project structure..."
required_files=(
    "Buffer/BufferApp.swift"
    "Buffer/Models/ClipboardItem.swift"
    "Buffer/Managers/ClipboardManager.swift"
    "Buffer/Managers/WindowManager.swift"
    "Buffer/Views/ClipboardView.swift"
    "Buffer/Helpers/ClipboardItemNameHelper.swift"
    "Buffer/Info.plist"
    "Buffer/Buffer.entitlements"
)

for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        echo "✓ $file"
    else
        echo "✗ Missing: $file"
    fi
done

echo ""
echo "Setup complete!"
echo ""
echo "Next steps:"
echo "1. Open Buffer.xcodeproj in Xcode"
echo "2. Select your target device/simulator"
echo "3. Build and run the project (Cmd+R)"
echo ""
echo "Or use: ./build.sh to build from command line" 
#!/bin/bash

# Build script for Buffer macOS app

echo "Building Buffer macOS app..."

# Check if Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    echo "Error: xcodebuild not found. Please install Xcode."
    exit 1
fi

# Clean build directory
echo "Cleaning build directory..."
rm -rf build/

# Build the project
echo "Building project..."
xcodebuild -project Buffer.xcodeproj -scheme Buffer -configuration Debug build

if [ $? -eq 0 ]; then
    echo "Build successful!"
    echo "You can now run the app from Xcode or find it in the build directory."
else
    echo "Build failed!"
    exit 1
fi 
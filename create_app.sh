#!/bin/bash
# Script to create a macOS app bundle for WindowSwitcher

set -e

APP_NAME="WindowSwitcher"

echo "Building ${APP_NAME}..."
echo ""

# Run SwiftLint if available
if command -v swiftlint &> /dev/null; then
    echo "🔍 Running SwiftLint..."
    swiftlint
    echo "✅ SwiftLint passed"
    echo ""
else
    echo "⚠️  SwiftLint not found - skipping code quality checks"
    echo "   Install with: brew install swiftlint"
    echo ""
fi

# Build release version using Swift Package Manager
echo "Building release version..."
swift build -c release

# Create app bundle structure
APP_BUNDLE="${APP_NAME}.app"
APP_DIR="$APP_BUNDLE/Contents"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_DIR/MacOS"
mkdir -p "$APP_DIR/Resources"

# Copy executable
echo "Creating app bundle..."
cp .build/release/$APP_NAME "$APP_DIR/MacOS/"

# Copy Info.plist
cp Sources/WindowSwitcher/Info.plist "$APP_DIR/"

# Copy entitlements if needed (for reference, not used in unsigned builds)
if [ -f "Sources/WindowSwitcher/WindowSwitcher.entitlements" ]; then
    cp Sources/WindowSwitcher/WindowSwitcher.entitlements "$APP_DIR/Resources/"
fi

# Clear quarantine attributes to avoid "damaged" warnings
xattr -cr "$APP_BUNDLE"

# Code sign the app (ad-hoc signature)
echo "Code signing app..."
codesign --force --deep --sign - "$APP_BUNDLE"

echo ""
echo "✅ App bundle created: $APP_BUNDLE"
echo ""
echo "To install:"
echo "  1. Open $APP_BUNDLE to test"
echo "  2. Grant Accessibility permissions when prompted"
echo "  3. Copy to Applications: cp -r $APP_BUNDLE /Applications/"
echo "  4. Add to Login Items in System Settings > General > Login Items"
echo ""
echo "Note: First launch may require right-click > Open due to code signing"
echo ""

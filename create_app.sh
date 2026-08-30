#!/bin/bash
# Script to create a macOS app bundle for WindowSwitcher

set -e

APP_NAME="WindowSwitcher"
INSTALL_DIR="${INSTALL_DIR:-/Applications}"

# Installing to /Applications is part of a normal build. Skip it with either:
#   ./create_app.sh --no-install
#   SKIP_INSTALL=1 ./create_app.sh
if [ "${1:-}" = "--no-install" ]; then
    SKIP_INSTALL=1
fi

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

# Copy app icon
if [ -f "Sources/WindowSwitcher/AppIcon.icns" ]; then
    echo "Copying app icon..."
    cp Sources/WindowSwitcher/AppIcon.icns "$APP_DIR/Resources/"
fi

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

# ---------------------------------------------------------------------------
# Install to /Applications
# ---------------------------------------------------------------------------

INSTALLED_APP="$INSTALL_DIR/$APP_BUNDLE"

if [ "${SKIP_INSTALL:-0}" = "1" ]; then
    echo "⏭️  Skipping install (--no-install). Copy manually with:"
    echo "     ditto $APP_BUNDLE $INSTALLED_APP"
    echo ""
    exit 0
fi

if [ ! -w "$INSTALL_DIR" ]; then
    echo "⚠️  $INSTALL_DIR is not writable — leaving the bundle in place."
    echo "   Install it yourself with:"
    echo "     sudo ditto $APP_BUNDLE $INSTALLED_APP"
    echo ""
    exit 0
fi

# Refuse to replace an app that isn't ours, rather than clobbering a name collision.
if [ -d "$INSTALLED_APP" ]; then
    EXISTING_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" \
        "$INSTALLED_APP/Contents/Info.plist" 2>/dev/null || echo "")
    OUR_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" \
        "$APP_BUNDLE/Contents/Info.plist")
    if [ -n "$EXISTING_ID" ] && [ "$EXISTING_ID" != "$OUR_ID" ]; then
        echo "⚠️  $INSTALLED_APP already exists and is a different app ($EXISTING_ID)."
        echo "   Not replacing it. Move it aside first, or use --no-install."
        echo ""
        exit 1
    fi
fi

# A running bundle cannot be replaced safely, and the old process would keep running
# the old code. Quit every copy, and note whether one was running so it can come back.
WAS_RUNNING=0
if pgrep -f "$APP_BUNDLE/Contents/MacOS/$APP_NAME" > /dev/null 2>&1; then
    WAS_RUNNING=1
    echo "Quitting running ${APP_NAME}..."
    pkill -f "$APP_BUNDLE/Contents/MacOS/$APP_NAME" || true
    # Give it a moment to exit before the bundle is swapped underneath it.
    for _ in 1 2 3 4 5 6 7 8 9 10; do
        pgrep -f "$APP_BUNDLE/Contents/MacOS/$APP_NAME" > /dev/null 2>&1 || break
        sleep 0.3
    done
fi

# Stage alongside the target and swap, so a failed copy cannot leave a half-written
# app where the old working one used to be. ditto (not cp -r) preserves the bundle's
# extended attributes and code signature.
STAGING="$INSTALL_DIR/.${APP_BUNDLE}.staging.$$"
cleanup_staging() { rm -rf "$STAGING"; }
trap cleanup_staging EXIT

echo "Installing to $INSTALLED_APP..."
rm -rf "$STAGING"
ditto "$APP_BUNDLE" "$STAGING"
rm -rf "$INSTALLED_APP"
mv "$STAGING" "$INSTALLED_APP"
trap - EXIT

xattr -cr "$INSTALLED_APP"

echo "✅ Installed: $INSTALLED_APP"
echo ""

if [ "$WAS_RUNNING" = "1" ]; then
    echo "Relaunching ${APP_NAME}..."
    open "$INSTALLED_APP"
    echo ""
fi

echo "⚠️  Accessibility permission must be re-granted after every build."
echo "   The ad-hoc signature changes whenever the code does, so macOS treats each"
echo "   build as a new app and drops its existing grant. Until you re-approve it in"
echo "   System Settings > Privacy & Security > Accessibility, Cmd+Tab will do nothing."
echo "   The app's Permissions tab shows the current state."
echo ""
echo "To start it automatically, enable \"Launch at login\" in the app's General settings."
echo ""

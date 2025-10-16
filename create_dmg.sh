#!/bin/bash
# Create a DMG installer for WindowSwitcher distribution

set -e

APP_NAME="WindowSwitcher"
VERSION="1.0"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
VOLUME_NAME="${APP_NAME} ${VERSION}"
SOURCE_APP="${APP_NAME}.app"

# Make sure app exists
if [ ! -d "$SOURCE_APP" ]; then
    echo "Error: ${SOURCE_APP} not found. Run ./create_app.sh first."
    exit 1
fi

# Remove any existing DMG
rm -f "$DMG_NAME"

# Create temporary directory
TMP_DIR=$(mktemp -d)
echo "Creating DMG in temporary directory: $TMP_DIR"

# Copy app to temp directory
cp -R "$SOURCE_APP" "$TMP_DIR/"

# Clear quarantine attributes to avoid "damaged" warnings
xattr -cr "$TMP_DIR/$SOURCE_APP"

# Create README if it doesn't exist
if [ ! -f "DMG_README.txt" ]; then
    cat > "$TMP_DIR/README.txt" << 'EOF'
WindowSwitcher - Windows-style Alt-Tab for macOS
================================================

INSTALLATION:
1. Drag WindowSwitcher.app to the Applications folder
2. Open WindowSwitcher from Applications
3. Grant Accessibility permissions when prompted:
   - Open System Settings > Privacy & Security > Accessibility
   - Enable WindowSwitcher
4. (Optional) Add to Login Items for auto-start:
   - Open System Settings > General > Login Items
   - Click "+" and add WindowSwitcher

USAGE:
- Press Cmd+Tab to open the window switcher
- Keep holding Cmd and press Tab to cycle forward
- Press Shift+Tab while holding Cmd to cycle backward
- Release Cmd to activate the selected window

REQUIREMENTS:
- macOS 13.0 or later
- Accessibility permissions

For issues or feedback, visit:
https://github.com/yourusername/WindowSwitcher
EOF
else
    cp DMG_README.txt "$TMP_DIR/README.txt"
fi

# Create symbolic link to Applications folder
ln -s /Applications "$TMP_DIR/Applications"

# Create DMG
echo "Creating DMG..."
hdiutil create -volname "$VOLUME_NAME" \
    -srcfolder "$TMP_DIR" \
    -ov -format UDZO \
    "$DMG_NAME"

# Clear quarantine attribute from the DMG itself
xattr -cr "$DMG_NAME"

# Cleanup
rm -rf "$TMP_DIR"

echo ""
echo "✅ DMG created: $DMG_NAME"
echo ""
echo "To distribute:"
echo "  1. Upload ${DMG_NAME} to GitHub releases or file sharing"
echo "  2. Users download and open the DMG"
echo "  3. Users drag ${APP_NAME}.app to Applications folder"
echo "  4. Users grant Accessibility permissions on first launch"
echo ""
echo "Note: For distribution outside the Mac App Store, consider:"
echo "  - Getting a Developer ID certificate for proper code signing"
echo "  - Notarizing the app with Apple"
echo ""

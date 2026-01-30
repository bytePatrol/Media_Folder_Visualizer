#!/bin/bash

# Video Analyzer DMG Build Script
# Usage: ./build-dmg.sh [--notarize]

set -e

APP_NAME="Video Analyzer"
BUNDLE_ID="com.videoanalyzer.app"
BUILD_DIR="build"
ARCHIVE_PATH="$BUILD_DIR/VideoAnalyzer.xcarchive"
EXPORT_PATH="$BUILD_DIR/export"
DMG_NAME="VideoAnalyzer"
DMG_PATH="$BUILD_DIR/$DMG_NAME.dmg"

NOTARIZE=false
if [[ "$1" == "--notarize" ]]; then
    NOTARIZE=true
fi

echo "=== Building Video Analyzer ==="

# Clean previous build
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Build archive
echo "Building archive..."
xcodebuild archive \
    -project VideoAnalyzer.xcodeproj \
    -scheme VideoAnalyzer \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    CODE_SIGN_STYLE=Manual \
    DEVELOPMENT_TEAM="" \
    CODE_SIGN_IDENTITY="-" \
    | xcbeautify || xcodebuild archive \
    -project VideoAnalyzer.xcodeproj \
    -scheme VideoAnalyzer \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    CODE_SIGN_STYLE=Manual \
    DEVELOPMENT_TEAM="" \
    CODE_SIGN_IDENTITY="-"

# Export archive
echo "Exporting archive..."
cat > "$BUILD_DIR/ExportOptions.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>destination</key>
    <string>export</string>
    <key>signingStyle</key>
    <string>manual</string>
</dict>
</plist>
EOF

xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$BUILD_DIR/ExportOptions.plist" \
    || cp -R "$ARCHIVE_PATH/Products/Applications/$APP_NAME.app" "$EXPORT_PATH/"

# Create DMG
echo "Creating DMG..."

# Check if create-dmg is available
if command -v create-dmg &> /dev/null; then
    create-dmg \
        --volname "$APP_NAME" \
        --volicon "$EXPORT_PATH/$APP_NAME.app/Contents/Resources/AppIcon.icns" \
        --window-pos 200 120 \
        --window-size 600 400 \
        --icon-size 100 \
        --icon "$APP_NAME.app" 150 190 \
        --hide-extension "$APP_NAME.app" \
        --app-drop-link 450 185 \
        "$DMG_PATH" \
        "$EXPORT_PATH/$APP_NAME.app"
else
    # Fallback to hdiutil
    echo "create-dmg not found, using hdiutil..."

    TEMP_DMG="$BUILD_DIR/temp.dmg"
    MOUNT_POINT="/Volumes/$APP_NAME"

    # Create temp DMG
    hdiutil create -size 200m -fs HFS+ -volname "$APP_NAME" "$TEMP_DMG"

    # Mount it
    hdiutil attach "$TEMP_DMG" -mountpoint "$MOUNT_POINT"

    # Copy app
    cp -R "$EXPORT_PATH/$APP_NAME.app" "$MOUNT_POINT/"

    # Create Applications symlink
    ln -s /Applications "$MOUNT_POINT/Applications"

    # Unmount
    hdiutil detach "$MOUNT_POINT"

    # Convert to compressed DMG
    hdiutil convert "$TEMP_DMG" -format UDZO -o "$DMG_PATH"

    rm "$TEMP_DMG"
fi

echo "DMG created at: $DMG_PATH"

# Notarize if requested
if [ "$NOTARIZE" = true ]; then
    echo "=== Notarizing ==="

    if [ -z "$APPLE_ID" ] || [ -z "$APPLE_ID_PASSWORD" ] || [ -z "$TEAM_ID" ]; then
        echo "Error: Set APPLE_ID, APPLE_ID_PASSWORD, and TEAM_ID environment variables"
        exit 1
    fi

    # Submit for notarization
    echo "Submitting for notarization..."
    xcrun notarytool submit "$DMG_PATH" \
        --apple-id "$APPLE_ID" \
        --password "$APPLE_ID_PASSWORD" \
        --team-id "$TEAM_ID" \
        --wait

    # Staple the ticket
    echo "Stapling ticket..."
    xcrun stapler staple "$DMG_PATH"

    echo "Notarization complete!"
fi

echo "=== Build Complete ==="
echo "Output: $DMG_PATH"

# Calculate checksums
echo ""
echo "Checksums:"
shasum -a 256 "$DMG_PATH"

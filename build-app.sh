#!/bin/bash
set -e

APP_NAME="Stardew Mod Manager"
BUNDLE_ID="com.stardewmodmanager.app"
BUILD_DIR="$(pwd)/.build/release"
APP_DIR="$(pwd)/build/${APP_NAME}.app"
ICON_SRC="$HOME/Desktop/Stardew Valley Modded.app/Contents/Resources/AppIcon.icns"

echo "Building release..."
swift build -c release

echo "Creating app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# Copy binary
cp "${BUILD_DIR}/StardewModManager" "$APP_DIR/Contents/MacOS/"

# Copy icon
if [ -f "$ICON_SRC" ]; then
    cp "$ICON_SRC" "$APP_DIR/Contents/Resources/AppIcon.icns"
    echo "App icon copied."
else
    echo "Warning: App icon not found at $ICON_SRC"
fi

# Create Info.plist
cat > "$APP_DIR/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>Stardew Mod Manager</string>
    <key>CFBundleDisplayName</key>
    <string>Stardew Mod Manager</string>
    <key>CFBundleIdentifier</key>
    <string>com.stardewmodmanager.app</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleExecutable</key>
    <string>StardewModManager</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticTermination</key>
    <false/>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <true/>
    </dict>
</dict>
</plist>
PLIST

echo ""
echo "Build complete: $APP_DIR"
echo "You can now double-click it to launch, or drag it to /Applications."

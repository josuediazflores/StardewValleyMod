#!/bin/bash
set -e

APP_NAME="Stardew Mod Manager"
BUNDLE_ID="com.stardewmodmanager.app"
BUILD_DIR="$(pwd)/.build/release"
APP_DIR="$(pwd)/build/${APP_NAME}.app"
ICON_SRC="$(pwd)/StardewModManager/Resources/AppIcon.icns"

# Get version from git tag (e.g. v1.0.0 -> 1.0.0)
GIT_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0-dev")
APP_VERSION="${GIT_TAG#v}"
echo "Version: $APP_VERSION (from tag $GIT_TAG)"

echo "Building release..."
swift build -c release

echo "Creating app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# Copy binary
cp "${BUILD_DIR}/StardewModManager" "$APP_DIR/Contents/MacOS/"

# Copy bundled resources (font, etc.)
# Must be in Contents/MacOS/ because SPM's Bundle.module looks relative to the binary
RESOURCE_BUNDLE="${BUILD_DIR}/StardewModManager_StardewModManager.bundle"
if [ -d "$RESOURCE_BUNDLE" ]; then
    cp -R "$RESOURCE_BUNDLE" "$APP_DIR/Contents/MacOS/"
    echo "Resource bundle copied."
fi

# Copy icon
if [ -f "$ICON_SRC" ]; then
    cp "$ICON_SRC" "$APP_DIR/Contents/Resources/AppIcon.icns"
    echo "App icon copied."
else
    echo "Warning: App icon not found at $ICON_SRC"
fi

# Create Info.plist
cat > "$APP_DIR/Contents/Info.plist" << PLIST
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
    <string>${APP_VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${APP_VERSION}</string>
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
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key>
            <string>NXM Protocol</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>nxm</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
PLIST

echo ""
echo "Build complete: $APP_DIR"
echo "You can now double-click it to launch, or drag it to /Applications."

# Create GitHub Release if --release flag is passed
if [ "$1" = "--release" ]; then
    echo ""
    echo "Creating GitHub Release v${APP_VERSION}..."
    ZIP_PATH="$(pwd)/build/Stardew Mod Manager.zip"
    rm -f "$ZIP_PATH"
    cd "$(pwd)/build" && zip -r "Stardew Mod Manager.zip" "Stardew Mod Manager.app" && cd ..
    gh release create "v${APP_VERSION}" "$ZIP_PATH" \
        --title "v${APP_VERSION}" \
        --notes "Release v${APP_VERSION}" \
        --latest
    echo "Release v${APP_VERSION} published to GitHub."
fi

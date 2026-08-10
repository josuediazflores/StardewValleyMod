#!/bin/bash
set -e

APP_NAME="Stardew Mod Manager"
BUNDLE_ID="com.stardewmodmanager.app"
BUILD_DIR="$(pwd)/.build/release"
APP_DIR="$(pwd)/build/${APP_NAME}.app"
ICON_SRC="$(pwd)/StardewModManager/Resources/AppIcon.icns"

# Get version from git tag (e.g. v1.0.0 -> 1.0.0)
# If HEAD is tagged, use that. Otherwise use latest tag + commit info.
HEAD_TAG=$(git tag --points-at HEAD 2>/dev/null | head -1)
if [ -n "$HEAD_TAG" ]; then
    GIT_TAG="$HEAD_TAG"
else
    GIT_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0-dev")
    echo "⚠️  HEAD is not tagged. Using latest tag $GIT_TAG."
    echo "   To set a new version: git tag v1.X.0 && git push --tags"
fi
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
        <!-- All API/CDN endpoints are HTTPS; only the embedded Nexus web view may load mixed content -->
        <key>NSAllowsArbitraryLoadsInWebContent</key>
        <true/>
    </dict>
    <key>NSLocalNetworkUsageDescription</key>
    <string>Stardew Mod Manager uses local network to sync modpacks with nearby players.</string>
    <key>NSBonjourServices</key>
    <array>
        <string>_smm-sync._tcp</string>
    </array>
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

# ---------------------------------------------------------------------------
# Code signing & notarization
#
# Environment variables (all optional; unset = ad-hoc local build):
#   SMM_SIGN_IDENTITY   Developer ID Application identity to sign with, e.g.
#                       "Developer ID Application: Jane Doe (TEAMID1234)".
#                       Unset -> ad-hoc signing (-s -), which trips Gatekeeper
#                       on other machines (users would need `xattr -cr`).
#   SMM_NOTARY_PROFILE  Name of a notarytool keychain profile used to submit the
#                       build to Apple's notary service during --release.
#   ALLOW_UNNOTARIZED   Set to 1 to publish a --release WITHOUT notarization
#                       (escape hatch only; a real release must be notarized).
#
# One-time setup for a real, notarized release:
#   1. Install your "Developer ID Application" certificate in the login keychain
#      (Xcode > Settings > Accounts > Manage Certificates, or import the .p12).
#   2. Create a notarytool keychain profile from an app-specific password
#      (appleid.apple.com > Sign-In and Security > App-Specific Passwords):
#        xcrun notarytool store-credentials "SMM_NOTARY" \
#            --apple-id "you@example.com" \
#            --team-id "TEAMID1234" \
#            --password "abcd-efgh-ijkl-mnop"
#   3. Export both env vars, then run `bash build-app.sh --release`:
#        export SMM_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID1234)"
#        export SMM_NOTARY_PROFILE="SMM_NOTARY"
# ---------------------------------------------------------------------------
SIGN_IDENTITY="${SMM_SIGN_IDENTITY:-}"
ENTITLEMENTS="$(pwd)/StardewModManager.entitlements"

if [ -z "$SIGN_IDENTITY" ]; then
    echo "⚠️  No SMM_SIGN_IDENTITY set — signing ad-hoc (-s -)."
    echo "   This build is UN-NOTARIZED and will trip Gatekeeper on other Macs."
    echo "   Users would need 'xattr -cr' to open it. Set SMM_SIGN_IDENTITY for a real release."
    codesign --force --deep -s - "$APP_DIR"
else
    if [ ! -f "$ENTITLEMENTS" ]; then
        echo "❌ Entitlements file not found at $ENTITLEMENTS"
        exit 1
    fi
    echo "Signing with Developer ID: $SIGN_IDENTITY"
    codesign --force --options runtime --entitlements "$ENTITLEMENTS" -s "$SIGN_IDENTITY" "$APP_DIR"
fi

# Verify the signature sealed correctly.
echo "Verifying code signature..."
if [ -n "$SIGN_IDENTITY" ]; then
    # Real identity: the signature itself must verify, or fail the build.
    codesign --verify --deep --strict "$APP_DIR"
    # Gatekeeper acceptance (spctl) can't pass until the app is notarized + stapled, which
    # happens in the --release step below. Run it here only for visibility (non-fatal); the
    # authoritative, build-failing spctl gate runs after stapling.
    echo "Checking Gatekeeper policy (spctl, pre-notarization)..."
    spctl -a -t exec -vv "$APP_DIR" || echo "   (Not yet accepted — expected until notarization + stapling completes.)"
else
    # Ad-hoc: verify for sanity but don't hard-fail a local build.
    codesign --verify --deep --strict "$APP_DIR" || echo "⚠️  Ad-hoc signature verification reported issues (expected for ad-hoc builds)."
fi

echo ""
echo "Build complete: $APP_DIR"
echo "You can now double-click it to launch, or drag it to /Applications."

# Create GitHub Release if --release flag is passed
if [ "$1" = "--release" ]; then
    echo ""

    # A real release must come from a tagged commit, not a floating dev build.
    if [ -z "$HEAD_TAG" ]; then
        echo "❌ Refusing to release: HEAD is not tagged."
        echo "   Tag the release commit first:  git tag v${APP_VERSION} && git push --tags"
        exit 1
    fi

    NOTARY_PROFILE="${SMM_NOTARY_PROFILE:-}"

    # A real release must be notarized unless explicitly overridden.
    if [ -z "$NOTARY_PROFILE" ] && [ "${ALLOW_UNNOTARIZED:-}" != "1" ]; then
        echo "❌ Refusing to publish an un-notarized release."
        echo "   Set SMM_NOTARY_PROFILE to a notarytool keychain profile, or set"
        echo "   ALLOW_UNNOTARIZED=1 to override (not recommended — Gatekeeper will warn)."
        exit 1
    fi

    # Notarization requires a real Developer ID signature; ad-hoc can't be notarized.
    if [ -n "$NOTARY_PROFILE" ] && [ -z "$SIGN_IDENTITY" ]; then
        echo "❌ Cannot notarize an ad-hoc build."
        echo "   Set SMM_SIGN_IDENTITY to your 'Developer ID Application' identity and re-run."
        exit 1
    fi

    echo "Creating GitHub Release v${APP_VERSION}..."
    ZIP_PATH="$(pwd)/build/Stardew Mod Manager.zip"

    # Zip with ditto (Apple-recommended for notarization; preserves signatures/symlinks and
    # pairs with the in-app updater's `ditto -xk` extraction). --keepParent keeps the .app
    # as the archive's top-level entry, which the updater looks for.
    rm -f "$ZIP_PATH"
    ditto -c -k --keepParent "$APP_DIR" "$ZIP_PATH"

    if [ -n "$NOTARY_PROFILE" ]; then
        echo "Submitting to Apple notary service (profile: $NOTARY_PROFILE)... this can take a few minutes."
        xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$NOTARY_PROFILE" --wait

        echo "Stapling notarization ticket to the app..."
        xcrun stapler staple "$APP_DIR"

        # Authoritative Gatekeeper gate: the stapled app must be accepted, or fail the release.
        echo "Verifying Gatekeeper acceptance (spctl)..."
        spctl -a -t exec -vv "$APP_DIR"

        # Re-zip so the published archive contains the stapled app.
        echo "Re-zipping stapled app..."
        rm -f "$ZIP_PATH"
        ditto -c -k --keepParent "$APP_DIR" "$ZIP_PATH"
    else
        echo "⚠️  Publishing WITHOUT notarization (ALLOW_UNNOTARIZED=1). Gatekeeper will warn users."
    fi

    gh release create "v${APP_VERSION}" "$ZIP_PATH" \
        --title "v${APP_VERSION}" \
        --notes "Release v${APP_VERSION}" \
        --latest
    echo "Release v${APP_VERSION} published to GitHub."
fi

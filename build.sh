#!/bin/bash
set -euo pipefail

# SlapBack Build & Sign Script
# Usage: ./build.sh [release|debug]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$SCRIPT_DIR/SlapBack.xcodeproj"
SCHEME="SlapBack"
CONFIG="${1:-debug}"
BUILD_DIR="$SCRIPT_DIR/build"

case "$CONFIG" in
    release|Release) CONFIG="Release" ;;
    debug|Debug)     CONFIG="Debug" ;;
    *) echo "Usage: $0 [release|debug]"; exit 1 ;;
esac

echo "=== SlapBack Build Script ==="
echo "Configuration: $CONFIG"
echo ""

mkdir -p "$BUILD_DIR"

# Build using Xcode's default DerivedData (don't override it)
echo "→ Building ($CONFIG)..."
xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIG" \
    CODE_SIGN_STYLE=Automatic \
    build 2>&1 | tail -3

# Find the built app
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -path "*/SlapBack-*/Build/Products/$CONFIG/SlapBack.app" -type d 2>/dev/null | head -1)
if [ -z "$APP_PATH" ]; then
    echo "ERROR: SlapBack.app not found in DerivedData"
    exit 1
fi

echo "→ Copying to $BUILD_DIR/SlapBack.app..."
rm -rf "$BUILD_DIR/SlapBack.app"
ditto "$APP_PATH" "$BUILD_DIR/SlapBack.app"

# Verify signing
echo "→ Code signature:"
codesign -dvv "$BUILD_DIR/SlapBack.app" 2>&1 | grep -E "(Authority|TeamIdentifier|Identifier)" || echo "  (unsigned — sign in Xcode or use codesign manually)"

# If release, create a DMG
if [ "$CONFIG" = "Release" ]; then
    echo "→ Creating DMG..."
    DMG_PATH="$BUILD_DIR/SlapBack.dmg"
    DMG_STAGING="$BUILD_DIR/dmg_staging"
    rm -rf "$DMG_STAGING" "$DMG_PATH"
    mkdir -p "$DMG_STAGING"
    ditto "$BUILD_DIR/SlapBack.app" "$DMG_STAGING/SlapBack.app"
    ln -s /Applications "$DMG_STAGING/Applications"
    hdiutil create -volname "SlapBack" -srcfolder "$DMG_STAGING" -ov -format UDZO "$DMG_PATH" 2>/dev/null
    rm -rf "$DMG_STAGING"
    echo "  DMG: $DMG_PATH"
fi

echo ""
echo "=== Done ==="
echo "Run: open $BUILD_DIR/SlapBack.app"

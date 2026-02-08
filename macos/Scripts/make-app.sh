#!/bin/bash
# Build Gloss.app bundle from Swift Package
# Usage: ./Scripts/make-app.sh [--release]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

CONFIG="debug"
if [[ "${1:-}" == "--release" ]]; then
    CONFIG="release"
    swift build -c release
else
    swift build
fi

APP_NAME="Gloss"
APP_DIR="$PROJECT_DIR/$APP_NAME.app"
BUILD_DIR="$PROJECT_DIR/.build/$CONFIG"

# Clean previous bundle
rm -rf "$APP_DIR"

# Create .app structure
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# Copy executable
cp "$BUILD_DIR/$APP_NAME" "$APP_DIR/Contents/MacOS/"

# Copy resource bundle where Bundle.module expects it:
# SPM checks Bundle.main.bundleURL/Gloss_Gloss.bundle (= Gloss.app/Gloss_Gloss.bundle)
# and also Bundle.main.bundleURL/Contents/Resources/Gloss_Gloss.bundle
if [ -d "$BUILD_DIR/Gloss_Gloss.bundle" ]; then
    cp -R "$BUILD_DIR/Gloss_Gloss.bundle" "$APP_DIR/"
    cp -R "$BUILD_DIR/Gloss_Gloss.bundle" "$APP_DIR/Contents/Resources/"
fi

# Copy icon to Resources (for Finder/Dock via Info.plist CFBundleIconFile)
cp "Sources/Gloss/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/"

# Copy Info.plist
cp "$SCRIPT_DIR/Info.plist" "$APP_DIR/Contents/"

echo "Built $APP_DIR"
echo "Run with: open $APP_DIR"

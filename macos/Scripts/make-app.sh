#!/bin/bash
# DEPRECATED: This script is replaced by the Xcode project for Phase 3+.
# Use Xcode to build Gloss.app with the embedded Quick Look extension.
# Kept for reference and rapid SPM-only iteration without QL extension.
#
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

# Copy resource bundles where Bundle.module expects them:
# SPM checks Bundle.main.bundleURL/<name>.bundle and Contents/Resources/<name>.bundle
for BUNDLE_NAME in Gloss_Gloss Gloss_GlossKit; do
    if [ -d "$BUILD_DIR/$BUNDLE_NAME.bundle" ]; then
        cp -R "$BUILD_DIR/$BUNDLE_NAME.bundle" "$APP_DIR/"
        cp -R "$BUILD_DIR/$BUNDLE_NAME.bundle" "$APP_DIR/Contents/Resources/"
    fi
done

# Copy icon to Resources (for Finder/Dock via Info.plist CFBundleIconFile)
cp "Sources/Gloss/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/"

# Copy Info.plist
cp "$SCRIPT_DIR/Info.plist" "$APP_DIR/Contents/"

echo "Built $APP_DIR"
echo "Run with: open $APP_DIR"

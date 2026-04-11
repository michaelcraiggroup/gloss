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

# Copy resource bundles into Contents/Resources (the standard, signable location).
# Note: previous versions of this script also copied bundles to the .app root,
# but that violates Apple's bundle layout and breaks codesign. Bundle.module finds
# them under Contents/Resources via Bundle.main lookup.
for BUNDLE_NAME in Gloss_Gloss Gloss_GlossKit; do
    if [ -d "$BUILD_DIR/$BUNDLE_NAME.bundle" ]; then
        cp -R "$BUILD_DIR/$BUNDLE_NAME.bundle" "$APP_DIR/Contents/Resources/"
    fi
done

# Copy icon to Resources (for Finder/Dock via Info.plist CFBundleIconFile)
cp "Sources/Gloss/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/"

# Copy Info.plist
cp "$SCRIPT_DIR/Info.plist" "$APP_DIR/Contents/"

# Ad-hoc sign so Gatekeeper allows the bundle to launch from /Applications.
# Without this, macOS shows "may be damaged or incomplete" on copies.
codesign --force --deep --sign - "$APP_DIR" >/dev/null 2>&1 || {
    echo "Warning: ad-hoc signing failed" >&2
}

echo "Built $APP_DIR"
echo "Run with: open $APP_DIR"

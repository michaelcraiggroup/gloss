#!/bin/bash
# TestFlight archive + export for GlossiOS.
#
# Usage:
#   Scripts/testflight-archive.sh --build N [--upload]
#
# Run from macos/ on a Mac signed into the team's Apple Account in Xcode.
#
# BUILD NUMBERS: project.yml keeps CURRENT_PROJECT_VERSION untouched (repo
# convention — the marketing version is the release lever). App Store Connect
# requires a UNIQUE CFBundleVersion per upload, so this script takes the
# number as an argument and passes it as an xcodebuild override — nothing in
# the repo changes. Pick the next integer after the last upload (ledger in
# docs/TESTFLIGHT.md).
#
# SIGNING: App Store distribution needs an Apple Distribution certificate and
# an App Store provisioning profile. The FIRST archive is easiest through
# Xcode Organizer (Product > Archive, then Distribute App) — one click mints
# both. After that, this script's -allowProvisioningUpdates reuses them
# headlessly. If it fails with "No Accounts", do the one-time GUI run first
# (same lesson as the Developer ID profile: downloads don't install
# themselves, and headless xcodebuild has no account session until Xcode has
# minted what it needs).
#
# --upload asks xcodebuild to hand the build to App Store Connect directly
# (exportOptions destination=upload). Without it you get an .ipa in
# .release/testflight/ for Transporter.app or Organizer.

set -euo pipefail
cd "$(dirname "$0")/.."

BUILD_NUMBER=""
UPLOAD=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --build) BUILD_NUMBER="$2"; shift 2 ;;
    --upload) UPLOAD=true; shift ;;
    *) echo "unknown argument: $1"; exit 64 ;;
  esac
done

if [[ -z "$BUILD_NUMBER" ]]; then
  echo "error: --build N is required (unique per App Store Connect upload;"
  echo "       ledger in docs/TESTFLIGHT.md — repo files stay untouched)."
  exit 64
fi

echo "== Preflight =="
test -f Gloss.xcodeproj/project.pbxproj || { echo "run xcodegen generate first"; exit 1; }
test -f GlossiOS/PrivacyInfo.xcprivacy || { echo "privacy manifest missing"; exit 1; }
test -f GlossiOS/Assets.xcassets/AppIcon.appiconset/AppIcon1024.png || { echo "app icon missing"; exit 1; }
MARKETING=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Scripts/Info.plist)
echo "marketing $MARKETING, build $BUILD_NUMBER"

ARCHIVE=".release/testflight/GlossiOS-$MARKETING-$BUILD_NUMBER.xcarchive"
EXPORT_DIR=".release/testflight/export-$MARKETING-$BUILD_NUMBER"
mkdir -p .release/testflight

echo "== Archive =="
xcodebuild -project Gloss.xcodeproj -scheme GlossiOS \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  -allowProvisioningUpdates \
  archive

echo "== Post-archive checks =="
APP="$ARCHIVE/Products/Applications/Gloss.app"
test -f "$APP/PrivacyInfo.xcprivacy" || { echo "manifest missing from bundle"; exit 1; }
BUILT_BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$APP/Info.plist")
[[ "$BUILT_BUILD" == "$BUILD_NUMBER" ]] || { echo "build-number override failed ($BUILT_BUILD)"; exit 1; }
codesign -d --entitlements :- "$APP" 2>/dev/null | grep -q "iCloud.group.michaelcraig.gloss" \
  || { echo "iCloud entitlement missing from archive"; exit 1; }
echo "bundle ok: build $BUILT_BUILD, iCloud entitled, manifest embedded"

echo "== Export =="
DESTINATION=$([[ "$UPLOAD" == true ]] && echo "upload" || echo "export")
cat > .release/testflight/exportOptions.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>app-store-connect</string>
	<key>destination</key>
	<string>$DESTINATION</string>
	<key>teamID</key>
	<string>JTL9F365FN</string>
	<key>signingStyle</key>
	<string>automatic</string>
	<key>manageAppVersionAndBuildNumber</key>
	<false/>
</dict>
</plist>
PLIST
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist .release/testflight/exportOptions.plist \
  -allowProvisioningUpdates

if [[ "$UPLOAD" == true ]]; then
  echo "== DONE: uploaded to App Store Connect (processing takes a few minutes) =="
else
  echo "== DONE: $EXPORT_DIR/Gloss.ipa — upload via Transporter.app or Xcode Organizer =="
fi

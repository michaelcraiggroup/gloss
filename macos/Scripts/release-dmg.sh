#!/bin/bash
#
# release-dmg.sh — build a SIGNED + NOTARIZED Gloss.dmg for direct
# (outside–App-Store) distribution. The result is drag-to-Applications and
# opens with no Gatekeeper warning on any Mac.
#
# ── One-time prerequisites (only you can do these) ─────────────────────────
#
# 1. Developer ID Application certificate  (needs paid Apple Developer Program)
#      Xcode ▸ Settings ▸ Accounts ▸ (your team) ▸ Manage Certificates…
#      ▸ + ▸ "Developer ID Application".  Verify with:
#        security find-identity -v -p codesigning | grep "Developer ID Application"
#
# 2. A stored notarization credential profile. Create an app-specific password
#    at https://account.apple.com ▸ Sign-In & Security ▸ App-Specific Passwords,
#    then (once) store it under the profile name this script expects:
#        xcrun notarytool store-credentials "gloss-notary" \
#          --apple-id "you@example.com" --team-id "JTL9F365FN"
#      (paste the app-specific password when prompted)
#
# ── Usage ──────────────────────────────────────────────────────────────────
#      cd gloss/macos
#      ./Scripts/release-dmg.sh
#
# Override defaults via env vars if needed:
#      TEAM_ID=JTL9F365FN NOTARY_PROFILE=gloss-notary ./Scripts/release-dmg.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MACOS_DIR="$(dirname "$SCRIPT_DIR")"
cd "$MACOS_DIR"

# ── Config ──
SCHEME="Gloss"
CONFIG="Release"
TEAM_ID="${TEAM_ID:-JTL9F365FN}"                       # team that owns the Developer ID cert
DEV_ID_IDENTITY="${DEV_ID_IDENTITY:-Developer ID Application}"
NOTARY_PROFILE="${NOTARY_PROFILE:-gloss-notary}"
BUILD="$MACOS_DIR/.release"
ARCHIVE="$BUILD/Gloss.xcarchive"
EXPORT_DIR="$BUILD/export"
DMG_STAGE="$BUILD/dmg-src"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Scripts/Info.plist)"
DMG="$MACOS_DIR/Gloss-$VERSION.dmg"

step() { printf '\n\033[1;34m==>\033[0m %s\n' "$1"; }
die()  { printf '\n\033[1;31mError:\033[0m %s\n' "$1" >&2; exit 1; }

# ── Preflight: fail early with actionable messages ──
step "Preflight"
security find-identity -v -p codesigning | grep -q "Developer ID Application" \
  || die $'No "Developer ID Application" certificate found in the keychain.\n       See prerequisite #1 at the top of this script.'
xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1 \
  || die "Notarization profile \"$NOTARY_PROFILE\" not found. See prerequisite #2 at the top of this script."
command -v create-dmg >/dev/null 2>&1 || die "create-dmg not installed — run: brew install create-dmg"
# iCloud is a RESTRICTED entitlement: the Developer ID archive must embed the
# profile named in project.yml's Release config. Fail before the 5-minute
# archive, with the fix. (Xcode 16 installs profiles under UserData; older
# flows used MobileDevice — accept either.)
PROFILE_NAME="Gloss Developer ID iCloud"
FOUND_PROFILE=""
for d in "$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles" \
         "$HOME/Library/MobileDevice/Provisioning Profiles"; do
  if [ -d "$d" ] && grep -rlsa "$PROFILE_NAME" "$d" >/dev/null 2>&1; then
    FOUND_PROFILE="$d"; break
  fi
done
[ -n "$FOUND_PROFILE" ] || die $'Provisioning profile "Gloss Developer ID iCloud" is not installed.\n       iCloud is a restricted entitlement — Developer ID archives must embed it.\n       Portal: Profiles ▸ + ▸ Distribution ▸ Developer ID ▸ App ID\n       group.michaelcraig.gloss ▸ name it EXACTLY "Gloss Developer ID iCloud"\n       ▸ download ▸ double-click to install. Details: docs/ICLOUD_SETUP.md'
echo "Developer ID cert + notary profile \"$NOTARY_PROFILE\" + iCloud profile present. Building Gloss $VERSION."

rm -rf "$BUILD"; mkdir -p "$BUILD"

step "Regenerating Xcode project"
xcodegen generate
# xcodegen regenerates both Info.plists from project.yml. Since gloss#35 the
# CFBundleShortVersionString values there are kept current with
# MARKETING_VERSION (formerly stale — gloss#25); this re-stamp stays as a
# belt-and-suspenders so a forgotten project.yml bump can't ship mislabeled.
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" Scripts/Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" GlossQLExtension/Info.plist

step "Archiving ($CONFIG) — Developer ID (manual, per-target in project.yml)"
# Signing is defined per-target in project.yml's Release configs: the app
# signs Developer ID with the embedded "Gloss Developer ID iCloud" profile
# (iCloud is a restricted entitlement — Developer ID now REQUIRES an embedded
# profile), while the Quick Look appex has no restricted entitlements and
# signs profile-free. Signing must NOT be passed on this command line: CLI
# build settings apply to every target, and the appex can't use the app's
# profile. All nested code (appex, GRDB / GlossKit frameworks) is still
# hardened + secure-timestamped in one pass — exactly what notarization needs.
xcodebuild -project Gloss.xcodeproj -scheme "$SCHEME" -configuration "$CONFIG" \
  -archivePath "$ARCHIVE" archive \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  ENABLE_HARDENED_RUNTIME=YES \
  OTHER_CODE_SIGN_FLAGS="--timestamp"

step "Collecting the signed .app from the archive"
mkdir -p "$EXPORT_DIR"
cp -R "$ARCHIVE/Products/Applications/Gloss.app" "$EXPORT_DIR/"
APP="$EXPORT_DIR/Gloss.app"
[ -d "$APP" ] || die "Archive did not produce Gloss.app at $APP"

step "Verifying the app is Developer ID signed + hardened"
codesign --verify --deep --strict --verbose=2 "$APP"
codesign -dv --verbose=4 "$APP" 2>&1 | grep -E "Authority=Developer ID|flags=.*runtime" || true

step "Verifying iCloud entitlements + embedded profile"
# A silently-dropped entitlement or missing profile would surface as a
# Gatekeeper/runtime failure on user machines — catch it before notarization.
[ -f "$APP/Contents/embedded.provisionprofile" ] \
  || die "No embedded.provisionprofile in Gloss.app — the iCloud entitlement requires one (project.yml Release signing)."
codesign -d --entitlements - "$APP" 2>&1 | grep -q "icloud-container-identifiers" \
  || die "Signed app is missing the iCloud entitlements — check Gloss.entitlements / project.yml."
security cms -D -i "$APP/Contents/embedded.provisionprofile" 2>/dev/null | grep -q "$PROFILE_NAME" \
  || echo "Warning: embedded profile is not named \"$PROFILE_NAME\" — continuing, but check which profile matched."

step "Building the DMG"
rm -f "$DMG"
mkdir -p "$DMG_STAGE"
cp -R "$APP" "$DMG_STAGE/"
if ! create-dmg \
  --volname "Gloss $VERSION" \
  --window-pos 200 120 \
  --window-size 540 380 \
  --icon-size 100 \
  --icon "Gloss.app" 150 190 \
  --app-drop-link 390 190 \
  --hdiutil-quiet \
  "$DMG" "$DMG_STAGE"; then
  # create-dmg drives Finder via AppleScript and hdiutil-create mounts a
  # scratch volume — both fail in headless/resumed login sessions ("Operation
  # not permitted"). makehybrid writes the image straight from the folder with
  # no Finder and no scratch mount. Cosmetic difference only: no custom icon
  # layout in the DMG window.
  step "create-dmg failed (no GUI Finder session) — falling back to hdiutil makehybrid"
  hdiutil detach "/Volumes/Gloss $VERSION" -force >/dev/null 2>&1 || true
  ln -shf /Applications "$DMG_STAGE/Applications"
  RAW="$BUILD/raw-hybrid.dmg"
  rm -f "$RAW"
  hdiutil makehybrid -hfs -hfs-volume-name "Gloss $VERSION" -o "$RAW" "$DMG_STAGE"
  hdiutil convert "$RAW" -format UDZO -o "$DMG"
  rm -f "$RAW"
fi
[ -f "$DMG" ] || die "DMG was not produced."

step "Signing the DMG"
codesign --force --sign "$DEV_ID_IDENTITY" --timestamp "$DMG"

step "Notarizing (uploads to Apple; typically 1–5 min)"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait

step "Stapling the ticket"
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"

step "Final Gatekeeper assessment"
spctl -a -t open --context context:primary-signature -vv "$DMG" || true

printf '\n\033[1;32mDone:\033[0m %s\n' "$DMG"
echo "Drag it anywhere — it opens with no warning on any Mac."

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
echo "Developer ID cert + notary profile \"$NOTARY_PROFILE\" present. Building Gloss $VERSION."

rm -rf "$BUILD"; mkdir -p "$BUILD"

step "Regenerating Xcode project"
xcodegen generate
# xcodegen rewrites Scripts/Info.plist from project.yml, which still carries a
# stale CFBundleShortVersionString fallback (tracked as gloss#25) — re-apply the
# real version so the archived app is stamped correctly.
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" Scripts/Info.plist

step "Archiving ($CONFIG) — signed directly with Developer ID (manual)"
# Manual signing with the Developer ID cert. A Developer ID Mac app needs no
# development cert and no provisioning profile (Gloss has no profile-requiring
# entitlements), which sidesteps the automatic-signing conflict and the fact
# that the only development cert here belongs to a different team. All nested
# code (Quick Look appex, GRDB / GlossKit frameworks) is signed + hardened +
# secure-timestamped in the same pass — exactly what notarization requires.
xcodebuild -project Gloss.xcodeproj -scheme "$SCHEME" -configuration "$CONFIG" \
  -archivePath "$ARCHIVE" archive \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="$DEV_ID_IDENTITY" \
  PROVISIONING_PROFILE_SPECIFIER="" \
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

step "Building the DMG"
rm -f "$DMG"
mkdir -p "$DMG_STAGE"
cp -R "$APP" "$DMG_STAGE/"
create-dmg \
  --volname "Gloss $VERSION" \
  --window-pos 200 120 \
  --window-size 540 380 \
  --icon-size 100 \
  --icon "Gloss.app" 150 190 \
  --app-drop-link 390 190 \
  --hdiutil-quiet \
  "$DMG" "$DMG_STAGE" \
  || die "create-dmg failed (it drives Finder via AppleScript — run this in a normal GUI login session, not over plain SSH)."

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

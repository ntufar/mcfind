#!/bin/bash
# Build, sign (Developer ID), notarize and package McFind for distribution.
#
# Produces build/release/McFind.dmg and build/release/McFind.pkg, both signed,
# notarized and stapled.
#
# Notarization credentials (one of):
#   - NOTARY_PROFILE: a keychain profile created with
#       xcrun notarytool store-credentials <name> --apple-id <id> --team-id 6CT959RWB8
#     (defaults to "mcfind-notary")
#   - NOTARY_KEY_PATH, NOTARY_KEY_ID, NOTARY_ISSUER: App Store Connect API key (used in CI)
#
# Set SKIP_NOTARIZE=1 to produce signed but un-notarized artifacts.
set -euo pipefail

TEAM_ID="6CT959RWB8"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/build/release"
ARCHIVE="$OUT/McFind.xcarchive"
APP="$OUT/export/McFind.app"
DMG="$OUT/McFind.dmg"
PKG="$OUT/McFind.pkg"

notarize() {
  if [[ "${SKIP_NOTARIZE:-0}" == "1" ]]; then
    echo "Skipping notarization of $1"
    return
  fi
  echo "Notarizing $1..."
  if [[ -n "${NOTARY_KEY_PATH:-}" ]]; then
    xcrun notarytool submit "$1" --wait \
      --key "$NOTARY_KEY_PATH" --key-id "$NOTARY_KEY_ID" --issuer "$NOTARY_ISSUER"
  else
    xcrun notarytool submit "$1" --wait --keychain-profile "${NOTARY_PROFILE:-mcfind-notary}"
  fi
}

staple() {
  [[ "${SKIP_NOTARIZE:-0}" == "1" ]] || xcrun stapler staple "$1"
}

# Pass App Store Connect API key to xcodebuild too, so CI can use cloud-managed signing.
AUTH_ARGS=()
if [[ -n "${NOTARY_KEY_PATH:-}" ]]; then
  AUTH_ARGS=(-authenticationKeyPath "$NOTARY_KEY_PATH"
             -authenticationKeyID "$NOTARY_KEY_ID"
             -authenticationKeyIssuerID "$NOTARY_ISSUER")
fi

rm -rf "$OUT"
mkdir -p "$OUT"

echo "Archiving..."
xcodebuild archive \
  -project "$ROOT/McFind.xcodeproj" \
  -scheme McFind \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates "${AUTH_ARGS[@]+"${AUTH_ARGS[@]}"}"

echo "Exporting with Developer ID..."
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportOptionsPlist "$ROOT/scripts/ExportOptions.plist" \
  -exportPath "$OUT/export" \
  -allowProvisioningUpdates "${AUTH_ARGS[@]+"${AUTH_ARGS[@]}"}"

codesign --verify --deep --strict --verbose=2 "$APP"
codesign -dvv "$APP" 2>&1 | grep -E "Authority|TeamIdentifier|Runtime|flags"

# Notarize the app itself so the stapled ticket travels inside both DMG and PKG.
ditto -c -k --keepParent "$APP" "$OUT/McFind.zip"
notarize "$OUT/McFind.zip"
rm "$OUT/McFind.zip"
staple "$APP"

echo "Creating DMG..."
"$ROOT/scripts/create-dmg.sh" "$APP" "$DMG"
DEV_ID_APP=$(security find-identity -v -p codesigning | grep -m1 "Developer ID Application: .*($TEAM_ID)" | sed -E 's/.*"(.*)"/\1/' || true)
if [[ -n "$DEV_ID_APP" ]]; then
  codesign --force --sign "$DEV_ID_APP" --timestamp "$DMG"
else
  echo "No local Developer ID Application identity; DMG left unsigned (app inside is signed)."
fi
notarize "$DMG"
staple "$DMG"

echo "Creating PKG..."
VERSION=$(defaults read "$APP/Contents/Info.plist" CFBundleShortVersionString)
DEV_ID_INSTALLER=$(security find-identity -v | grep -m1 "Developer ID Installer: .*($TEAM_ID)" | sed -E 's/.*"(.*)"/\1/' || true)
PKG_SIGN_ARGS=()
if [[ -n "$DEV_ID_INSTALLER" ]]; then
  PKG_SIGN_ARGS=(--sign "$DEV_ID_INSTALLER" --timestamp)
fi
pkgbuild --component "$APP" --identifier com.mcfind.McFind --version "$VERSION" \
  --install-location /Applications "${PKG_SIGN_ARGS[@]+"${PKG_SIGN_ARGS[@]}"}" "$PKG"
if [[ -n "$DEV_ID_INSTALLER" ]]; then
  notarize "$PKG"
  staple "$PKG"
else
  echo "No Developer ID Installer identity; PKG left unsigned."
fi

echo
echo "Gatekeeper assessment:"
spctl --assess --type execute --verbose=2 "$APP" || true
spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG" || true
[[ -n "$DEV_ID_INSTALLER" ]] && { spctl --assess --type install --verbose=2 "$PKG" || true; }
echo
echo "Artifacts in $OUT:"
ls -la "$DMG" "$PKG"

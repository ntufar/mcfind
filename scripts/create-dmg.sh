#!/bin/bash
set -e

APP_PATH="$1"
DMG_NAME="${2:-McFind.dmg}"
VOLUME_NAME="${3:-McFind}"

STAGING_DIR=$(mktemp -d)

echo "Setting up DMG staging..."

cp -R "$APP_PATH" "$STAGING_DIR/McFind.app"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Creating DMG..."
create-dmg \
  --volname "$VOLUME_NAME" \
  --window-pos 420 250 \
  --window-size 660 422 \
  --icon-size 160 \
  --icon "McFind.app" 180 170 \
  --app-drop-link 480 170 \
  --background "$SCRIPT_DIR/assets/dmg-background.tiff" \
  "$DMG_NAME" \
  "$STAGING_DIR"

rm -rf "$STAGING_DIR"
echo "Done: $DMG_NAME"

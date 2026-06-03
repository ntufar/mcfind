#!/bin/bash
set -e

APP_PATH="$1"
DMG_NAME="${2:-McFind.dmg}"
VOLUME_NAME="${3:-McFind}"

STAGING_DIR=$(mktemp -d)

echo "Setting up DMG staging..."

cp -R "$APP_PATH" "$STAGING_DIR/McFind.app"
mkdir -p "$STAGING_DIR/.background"

echo "Generating background image..."
python3 << PYEOF
from PIL import Image, ImageDraw

W, H = 600, 400
img = Image.new('RGBA', (W, H), (255, 255, 255, 0))
draw = ImageDraw.Draw(img)

gray = (140, 140, 140, 255)
arrow_y = 200

draw.line([(215, arrow_y), (375, arrow_y)], fill=gray, width=3)
draw.polygon([(375, arrow_y - 14), (400, arrow_y), (375, arrow_y + 14)], fill=gray)

img.save("$STAGING_DIR/.background/background.png")
PYEOF

echo "Creating DMG..."
create-dmg \
  --volname "$VOLUME_NAME" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 128 \
  --icon "McFind.app" 150 190 \
  --app-drop-link 450 190 \
  --background "$STAGING_DIR/.background/background.png" \
  "$DMG_NAME" \
  "$STAGING_DIR"

rm -rf "$STAGING_DIR"
echo "Done: $DMG_NAME"

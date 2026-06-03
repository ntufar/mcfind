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

color = (30, 30, 30, 255)
cx, cy = 300, 200
h = 40    # half-height of chevron arms
depth = 28  # horizontal span
t = 20    # stroke thickness

# Draw ">" chevron as two thick strokes meeting at the tip
draw.line([(cx - depth, cy - h), (cx, cy)], fill=color, width=t)
draw.line([(cx, cy), (cx - depth, cy + h)], fill=color, width=t)

# Fill the joint at the tip for a clean miter
r = t // 2
draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=color)

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

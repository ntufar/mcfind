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

W, H = 660, 422
S = 4  # supersampling for antialiasing

img = Image.new('RGBA', (W * S, H * S), (235, 235, 235, 255))
draw = ImageDraw.Draw(img)

color = (50, 50, 50, 255)
cx  = 330 * S  # horizontal center of window
cy  = 170 * S  # matches icon y position (top-down from content area)
h   = 38 * S
dep = 26 * S
t   = 15 * S

draw.line([(cx - dep, cy - h), (cx, cy)], fill=color, width=t)
draw.line([(cx, cy), (cx - dep, cy + h)], fill=color, width=t)
r = t // 2
for ex, ey in [(cx, cy), (cx - dep, cy - h), (cx - dep, cy + h)]:
    draw.ellipse([ex - r, ey - r, ex + r, ey + r], fill=color)

img = img.resize((W, H), Image.LANCZOS)
img.save("$STAGING_DIR/.background/background.png")
PYEOF

echo "Creating DMG..."
create-dmg \
  --volname "$VOLUME_NAME" \
  --window-pos 420 250 \
  --window-size 660 422 \
  --icon-size 160 \
  --icon "McFind.app" 180 170 \
  --app-drop-link 480 170 \
  --background "$STAGING_DIR/.background/background.png" \
  "$DMG_NAME" \
  "$STAGING_DIR"

rm -rf "$STAGING_DIR"
echo "Done: $DMG_NAME"

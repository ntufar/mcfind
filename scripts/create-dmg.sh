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
S = 4  # supersampling factor — draw at 4x then downsample for antialiasing

img = Image.new('RGBA', (W * S, H * S), (235, 235, 235, 255))
draw = ImageDraw.Draw(img)

color = (50, 50, 50, 255)
cx  = 300 * S
cy  = 200 * S
h   = 38 * S
dep = 26 * S
t   = 15 * S

draw.line([(cx - dep, cy - h), (cx, cy)], fill=color, width=t)
draw.line([(cx, cy), (cx - dep, cy + h)], fill=color, width=t)
# Round all three endpoints: tip + two open ends
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
  --window-size 600 400 \
  --icon-size 128 \
  --icon "McFind.app" 150 190 \
  --app-drop-link 450 190 \
  --background "$STAGING_DIR/.background/background.png" \
  "$DMG_NAME" \
  "$STAGING_DIR"

rm -rf "$STAGING_DIR"
echo "Done: $DMG_NAME"

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

color = (170, 170, 170, 255)
cy = H // 2  # 200

# Shaft geometry
sx1, sx2 = 225, 362
sh = 3  # half-shaft height (total 6px)

# Arrowhead geometry
hx1, hx2 = 358, 392
hh = 14  # half-head height (total 28px)

# Draw unified arrow polygon (chevron-style head taller than shaft)
arrow = [
    (sx1, cy - sh),
    (hx1, cy - sh),
    (hx1, cy - hh),
    (hx2, cy),
    (hx1, cy + hh),
    (hx1, cy + sh),
    (sx1, cy + sh),
]
draw.polygon(arrow, fill=color)

# Rounded left cap
draw.ellipse([sx1 - sh, cy - sh, sx1 + sh, cy + sh], fill=color)

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

#!/usr/bin/env python3
"""
Generate macOS app icons without cairosvg.
Creates a simple programmatic icon using PIL/Pillow.
Requires: pip install pillow
"""

import os
import sys
import json
from pathlib import Path

try:
    from PIL import Image, ImageDraw
except ImportError:
    print("ERROR: Missing required package")
    print("Please install: pip install pillow")
    sys.exit(1)

# Define required icon sizes for macOS
ICON_SIZES = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

def create_icon(size):
    """Create a magnifying glass icon programmatically."""
    # Create image with gradient background
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Scale factor for all elements
    s = size / 512

    # Draw rounded rectangle background with blue gradient
    # (PIL doesn't support gradients easily, so we'll use solid color)
    corner_radius = int(115 * s)
    draw.rounded_rectangle(
        [(0, 0), (size, size)],
        radius=corner_radius,
        fill=(0, 122, 255, 255)  # #007AFF
    )

    # Magnifying glass circle (glass part)
    glass_center = (int(200 * s), int(200 * s))
    glass_radius = int(130 * s)

    # White circle for the glass
    draw.ellipse(
        [
            glass_center[0] - glass_radius,
            glass_center[1] - glass_radius,
            glass_center[0] + glass_radius,
            glass_center[1] + glass_radius
        ],
        fill=(255, 255, 255, 240),
        outline=(255, 255, 255, 255),
        width=int(20 * s)
    )

    # Inner circle outline
    inner_radius = int(110 * s)
    draw.ellipse(
        [
            glass_center[0] - inner_radius,
            glass_center[1] - inner_radius,
            glass_center[0] + inner_radius,
            glass_center[1] + inner_radius
        ],
        fill=None,
        outline=(0, 81, 213, 76),  # #0051D5 with opacity
        width=int(8 * s)
    )

    # Draw handle
    handle_width = int(45 * s)
    draw.line(
        [(int(295 * s), int(295 * s)), (int(420 * s), int(420 * s))],
        fill=(255, 255, 255, 255),
        width=handle_width,
    )

    # Handle cap
    cap_width = int(50 * s)
    draw.line(
        [(int(420 * s), int(420 * s)), (int(440 * s), int(440 * s))],
        fill=(255, 255, 255, 255),
        width=cap_width,
    )

    # Draw search lines inside the glass
    line_width = int(12 * s)
    lines = [
        (int(160 * s), int(165 * s), int(240 * s), int(165 * s)),
        (int(160 * s), int(200 * s), int(240 * s), int(200 * s)),
        (int(160 * s), int(235 * s), int(210 * s), int(235 * s)),
    ]

    for x1, y1, x2, y2 in lines:
        draw.line([(x1, y1), (x2, y2)], fill=(0, 122, 255, 153), width=line_width)

    # Add sparkle effects (small circles)
    sparkles = [
        (int(140 * s), int(140 * s), int(8 * s)),
        (int(260 * s), int(160 * s), int(6 * s)),
        (int(385 * s), int(385 * s), int(10 * s)),
    ]

    for x, y, r in sparkles:
        draw.ellipse(
            [x - r, y - r, x + r, y + r],
            fill=(255, 255, 255, 230)
        )

    return img

def generate_icon(output_path, size):
    """Generate icon at specified size."""
    print(f"Generating {output_path.name} ({size}x{size})...")

    img = create_icon(size)
    img.save(output_path, "PNG", optimize=True)

def update_contents_json(icon_dir):
    """Update Contents.json with proper filenames."""
    contents = {
        "images": [
            {"filename": "icon_16x16.png", "idiom": "mac", "scale": "1x", "size": "16x16"},
            {"filename": "icon_16x16@2x.png", "idiom": "mac", "scale": "2x", "size": "16x16"},
            {"filename": "icon_32x32.png", "idiom": "mac", "scale": "1x", "size": "32x32"},
            {"filename": "icon_32x32@2x.png", "idiom": "mac", "scale": "2x", "size": "32x32"},
            {"filename": "icon_128x128.png", "idiom": "mac", "scale": "1x", "size": "128x128"},
            {"filename": "icon_128x128@2x.png", "idiom": "mac", "scale": "2x", "size": "128x128"},
            {"filename": "icon_256x256.png", "idiom": "mac", "scale": "1x", "size": "256x256"},
            {"filename": "icon_256x256@2x.png", "idiom": "mac", "scale": "2x", "size": "256x256"},
            {"filename": "icon_512x512.png", "idiom": "mac", "scale": "1x", "size": "512x512"},
            {"filename": "icon_512x512@2x.png", "idiom": "mac", "scale": "2x", "size": "512x512"},
        ],
        "info": {"author": "xcode", "version": 1}
    }

    contents_path = icon_dir / "Contents.json"
    with open(contents_path, 'w') as f:
        json.dump(contents, f, indent=2)
    print(f"Updated {contents_path}")

def main():
    # Paths
    script_dir = Path(__file__).parent
    icon_dir = script_dir / "McFind" / "Assets.xcassets" / "AppIcon.appiconset"

    # Validate path
    if not icon_dir.exists():
        print(f"ERROR: AppIcon.appiconset directory not found at {icon_dir}")
        sys.exit(1)

    print("Generating programmatic icons")
    print(f"Output directory: {icon_dir}")
    print()

    # Generate all icon sizes
    for filename, size in ICON_SIZES:
        output_path = icon_dir / filename
        try:
            generate_icon(output_path, size)
        except Exception as e:
            print(f"ERROR generating {filename}: {e}")
            import traceback
            traceback.print_exc()
            sys.exit(1)

    # Update Contents.json
    update_contents_json(icon_dir)

    print()
    print("✓ All icons generated successfully!")
    print(f"✓ {len(ICON_SIZES)} PNG files created")
    print("✓ Contents.json updated")
    print()
    print("Next steps:")
    print("1. Open McFind.xcodeproj in Xcode")
    print("2. The new app icon should appear automatically")
    print("3. Build and run to see the new icon")

if __name__ == "__main__":
    main()

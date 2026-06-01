#!/usr/bin/env python3
"""
Generate macOS app icons from SVG source.
Requires: pip install cairosvg pillow
"""

import os
import sys
from pathlib import Path

try:
    import cairosvg
    from PIL import Image
    import io
except ImportError:
    print("ERROR: Missing required packages")
    print("Please install: pip install cairosvg pillow")
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

def generate_png_from_svg(svg_path, output_path, size):
    """Convert SVG to PNG at specified size."""
    print(f"Generating {output_path.name} ({size}x{size})...")

    # Convert SVG to PNG using cairosvg
    png_data = cairosvg.svg2png(
        url=str(svg_path),
        output_width=size,
        output_height=size
    )

    # Open with PIL and save with optimization
    img = Image.open(io.BytesIO(png_data))
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

    import json
    contents_path = icon_dir / "Contents.json"
    with open(contents_path, 'w') as f:
        json.dump(contents, f, indent=2)
    print(f"Updated {contents_path}")

def main():
    # Paths
    script_dir = Path(__file__).parent
    svg_path = script_dir / "docs" / "icon.svg"
    icon_dir = script_dir / "McFind" / "Assets.xcassets" / "AppIcon.appiconset"

    # Validate paths
    if not svg_path.exists():
        print(f"ERROR: SVG file not found at {svg_path}")
        sys.exit(1)

    if not icon_dir.exists():
        print(f"ERROR: AppIcon.appiconset directory not found at {icon_dir}")
        sys.exit(1)

    print(f"Generating icons from {svg_path}")
    print(f"Output directory: {icon_dir}")
    print()

    # Generate all icon sizes
    for filename, size in ICON_SIZES:
        output_path = icon_dir / filename
        try:
            generate_png_from_svg(svg_path, output_path, size)
        except Exception as e:
            print(f"ERROR generating {filename}: {e}")
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

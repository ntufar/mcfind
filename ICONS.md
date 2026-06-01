# Icon Generation Guide

This document explains how to generate the macOS app icons from the SVG source.

## Icon Design

The McFind icon features:
- **Magnifying glass**: Represents search/find functionality
- **Document lines**: Shows it's for file searching
- **Blue gradient**: macOS-native color scheme (#007AFF)
- **Clean, modern design**: Matches macOS Big Sur and later design language

## Files

- `docs/icon.svg` - Source SVG icon (512x512)
- `generate_icons.py` - Python script to generate all required PNG sizes
- `McFind/Assets.xcassets/AppIcon.appiconset/` - Output directory for app icons

## Generating Icons

### Prerequisites

Install required Python packages:

```bash
pip install cairosvg pillow
```

### Generate All Sizes

Run the icon generation script:

```bash
python3 generate_icons.py
```

This will generate all required PNG sizes for macOS:
- 16x16 (1x and 2x)
- 32x32 (1x and 2x)
- 128x128 (1x and 2x)
- 256x256 (1x and 2x)
- 512x512 (1x and 2x)

The script also updates `Contents.json` with the correct filenames.

## Icon Sizes Reference

| Size | Filename | Usage |
|------|----------|-------|
| 16x16 | icon_16x16.png | Menu bar, lists |
| 32x32 | icon_16x16@2x.png | Menu bar @2x |
| 32x32 | icon_32x32.png | Lists, toolbars |
| 64x64 | icon_32x32@2x.png | Lists @2x |
| 128x128 | icon_128x128.png | Finder icon |
| 256x256 | icon_128x128@2x.png | Finder @2x |
| 256x256 | icon_256x256.png | Dock |
| 512x512 | icon_256x256@2x.png | Dock @2x |
| 512x512 | icon_512x512.png | App Store |
| 1024x1024 | icon_512x512@2x.png | App Store @2x |

## Manual Icon Update

If you need to update the icon design:

1. Edit `docs/icon.svg` with your preferred SVG editor
2. Run `python3 generate_icons.py`
3. Open `McFind.xcodeproj` in Xcode
4. Build the project to see the new icon

## Website Icon

The website (`docs/index.html`) uses the SVG icon directly for:
- Favicon
- Apple touch icon
- Header logo

No additional processing needed for the website icon.

## Troubleshooting

### Missing Python Packages

If you get import errors:
```bash
pip3 install --user cairosvg pillow
```

### Cairo Library Issues (macOS)

If cairosvg fails to install, install cairo via Homebrew:
```bash
brew install cairo
pip3 install cairosvg
```

### Permission Denied

Make sure the script is executable:
```bash
chmod +x generate_icons.py
```

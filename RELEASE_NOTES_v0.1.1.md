# McFind v0.1.1 - Performance Fix

Patch release with performance improvements for large databases.

## 🐛 Bug Fixes

- **Performance improvements for large database initialization**
  - Database file existence check before showing loading spinner
  - File count loads in background without blocking UI
  - App now shows immediately even with 1M+ files indexed
  - Resolves "Loading index..." hang issue

## 🔧 Technical Changes

- Made `dbPath` public in IndexDatabase for file existence checks
- Optimized loadIndexFromDisk() to show UI immediately when database exists
- Background file count loading doesn't block main thread

## 📦 Installation

### DMG Installer (Recommended)
1. Download `McFind.dmg`
2. Open the DMG
3. Drag McFind to Applications folder
4. Launch and enjoy!

### PKG Installer
1. Download `McFind.pkg`
2. Double-click to install
3. Follow the installer prompts

## 📝 What This Fixes

If you had a large database (hundreds of thousands of files), previous versions would show "Loading index..." indefinitely. This release fixes that by:

1. Checking if database exists before showing spinner
2. Loading the UI immediately
3. Counting files in the background

The app is now responsive immediately, even with very large indexes.

---

**Full Changelog**: https://github.com/ntufar/mcfind/compare/v0.1.0...v0.1.1

# McFind v0.1.0 - Hierarchical Settings & Search Improvements

Major feature release with fine-grained indexing control and enhanced search capabilities.

## 🎉 New Features

### Hierarchical Settings
Control exactly what gets indexed with three-level folder hierarchy:

- **Library folder** (OFF by default) - excludes system caches and logs
- **Library → CloudStorage** (ON by default) - indexes OneDrive, SharePoint, Google Drive, Dropbox
- **Library → iCloud Drive** (ON by default) - indexes iCloud documents

This gives you the best of both worlds: search your cloud documents without indexing system junk!

### Enhanced Search
- Search now includes **full file paths**, not just filenames
- Find files by typing part of their path: "projects/epap" finds `/Users/you/projects/epap/`
- Better ranking: exact match → prefix match → contains → path match

### Settings UI
- Press **Cmd+,** to open Settings
- Visual hierarchy with indented subfolders
- Toggle any folder on/off independently
- Changes apply after re-indexing

### Re-index Command
- Press **Cmd+Shift+R** to re-index all files
- Or use menu: McFind → Re-index Files
- Progress shown in status bar

### Documentation
- Comprehensive user guide in `docs/SETUP.md`
- Developer guide in `docs/DEVELOPMENT.md`
- Settings explained in `docs/HIERARCHICAL_SETTINGS.md`
- Full changelog in `CHANGELOG.md`

## 🐛 Bug Fixes

- **Fixed infinite loop** when selecting items in table view
- **Fixed SwiftUI warnings** about publishing changes during view updates
- **Fixed Settings conflict** - renamed internal class to avoid SwiftUI.Settings clash
- **Fixed "Loading index..." hang** with large databases (1M+ files) - UI now shows immediately
- **Improved stability** with better state management in table selection

## 🔧 Technical Changes

- Minimum macOS version: **13.0 (Ventura)** for Settings API
- Search query: `name LIKE ? OR path LIKE ?` for path matching
- Enhanced skip list: now excludes more system folders
- Better thread safety in table view coordinator

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

## 🚀 Getting Started

1. **First launch** - App will index your home directory (may take 1-5 minutes)
2. **Configure settings** (optional) - Press Cmd+, to customize indexed folders
3. **Search** - Type in the search box to find files instantly
4. **Navigate** - Use arrow keys, Enter to open files

## 📝 Default Settings

Out of the box, McFind indexes:
- ✅ Desktop, Documents, Downloads
- ✅ Movies, Music, Pictures
- ✅ Library/CloudStorage (OneDrive, SharePoint, Google Drive)
- ✅ Library/Mobile Documents (iCloud Drive)
- ❌ Library (main folder - caches and system data)

You can change these in Settings (Cmd+,).

## 🔍 What Gets Indexed

**Always indexed** (if folder is enabled):
- User documents and files
- Cloud storage locations

**Always skipped** (regardless of settings):
- node_modules, .git, build artifacts
- Caches, Logs, temporary files
- Browser data (Chrome, Firefox)
- Xcode DerivedData
- Package bundles (.app, .xcodeproj)

## 📚 Documentation

- **User Guide**: See `docs/SETUP.md` in repository
- **Troubleshooting**: Check `docs/SETUP.md` → Troubleshooting section
- **Feature List**: See `docs/FEATURES.md`
- **Changelog**: See `CHANGELOG.md`

## 🙏 Feedback

Found a bug or have a suggestion? Please open an issue on GitHub!

---

**Full Changelog**: https://github.com/ntufar/mcfind/compare/v0.0.3...v0.1.0

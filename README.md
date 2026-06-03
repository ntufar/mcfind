# McFind - macOS File Search Utility

[![macOS Build](https://github.com/ntufar/mcfind/actions/workflows/macos.yml/badge.svg)](https://github.com/ntufar/mcfind/actions/workflows/macos.yml)
[![Release](https://github.com/ntufar/mcfind/actions/workflows/release.yml/badge.svg)](https://github.com/ntufar/mcfind/actions/workflows/release.yml)
[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![macOS](https://img.shields.io/badge/macOS-14.0+-blue.svg)](https://www.apple.com/macos)
[![Xcode](https://img.shields.io/badge/Xcode-15.0+-blue.svg)](https://developer.apple.com/xcode)
[![Homebrew](https://img.shields.io/badge/Homebrew-ntufar%2Ftap-orange?logo=homebrew)](https://github.com/ntufar/homebrew-tap)
[![License](https://img.shields.io/badge/License-Open%20Source-green.svg)](https://github.com/ntufar/mcfind)
[![Website](https://img.shields.io/badge/Website-ntufar.github.io%2Fmcfind-blue)](https://ntufar.github.io/mcfind/)

A fast, modern macOS application for searching files in your home directory, inspired by Everything on Windows. [Visit website →](https://ntufar.github.io/mcfind/)

![McFind Screenshot](docs/McFind-blurred.png)

## Features

- **Lightning-fast search**: Indexes your home directory for instant file searching
- **Path and name search**: Search by filename or full path
- **Modern UI**: Clean, native macOS interface with SwiftUI
- **Smart filtering**: Intelligent search with exact matches prioritized
- **Hierarchical settings**: Control indexing per folder, including cloud storage
- **Cloud integration**: Index SharePoint, OneDrive, Google Drive, iCloud Drive by default
- **Keyboard navigation**: Use arrow keys to navigate, Enter to open files
- **File metadata**: Shows file size, modification date, and file type icons
- **Real-time monitoring**: Automatically detects file system changes
- **Background indexing**: Non-blocking file indexing with progress indicator

## Download

### Option 1: Homebrew (recommended)

Easy install and updates with `brew upgrade`:

```bash
brew tap ntufar/tap
brew install --cask mcfind
```

### Option 2: Direct download (v0.2.6)

- **DMG Installer**: [Download McFind.dmg](https://github.com/ntufar/mcfind/releases/latest/download/McFind.dmg) — drag-and-drop installation
- **PKG Installer**: [Download McFind.pkg](https://github.com/ntufar/mcfind/releases/latest/download/McFind.pkg) — automated installer

### First launch: Gatekeeper warning

Because McFind is not notarized with Apple, macOS blocks the first launch regardless of how you installed it. You'll see:

> *"McFind" cannot be opened because Apple cannot verify it is free of malware.*

**One-time fix — pick either option:**

**Option A — Terminal (fastest):**
```bash
xattr -dr com.apple.quarantine /Applications/McFind.app
```

**Option B — Finder:** Right-click `McFind.app` → **Open** → click **Open** in the dialog.

After doing this once, McFind opens normally every time.

### All Releases
View all available releases and download previous versions: [Releases Page](https://github.com/ntufar/mcfind/releases)

## Requirements

- macOS 14.0 or later (Sonoma+)
- Xcode 15.0 or later (for building from source)

## Building from Source

See [docs/SETUP.md](docs/SETUP.md) for detailed build instructions.

## Usage

1. **Launch the app**: The application will automatically start indexing your home directory
2. **Configure settings** (optional): Press `Cmd+,` to customize which folders to index
3. **Search**: Type in the search bar to find files instantly
4. **Navigate**: Use arrow keys to navigate through results
5. **Open files**: Press Enter or double-click to open the selected file

## Keyboard Shortcuts

- `Cmd+,`: Open Settings
- `Cmd+Shift+R`: Re-index all files
- `↑` / `↓`: Navigate through search results
- `Enter`: Open the selected file
- `Escape`: Clear search or close window

## Settings

McFind offers fine-grained control over what gets indexed:

- **Top-level folders**: Desktop, Documents, Downloads, Movies, Music, etc.
- **Library folder**: Excluded by default (contains system caches)
- **Cloud Storage**: Library/CloudStorage is ON by default (OneDrive, SharePoint, Google Drive)
- **iCloud Drive**: Library/Mobile Documents is ON by default

See [docs/HIERARCHICAL_SETTINGS.md](docs/HIERARCHICAL_SETTINGS.md) for details.

## Documentation

- **[Setup Guide](docs/SETUP.md)** - Installation and configuration
- **[Development Guide](docs/DEVELOPMENT.md)** - Architecture and development
- **[Hierarchical Settings](docs/HIERARCHICAL_SETTINGS.md)** - Settings feature details
- **[Features](docs/FEATURES.md)** - Complete feature list

## Privacy & Security

The app requests minimal file system permissions through sandboxing:
- Read-only access to user-selected files
- Read-only access to common directories (Downloads, Pictures, Music, Movies)
- Read-only access to home directory files

## Performance

- SQLite-based indexing for instant search results
- Background indexing with real-time file system monitoring
- Smart exclusions: automatically skips caches, logs, build artifacts
- Typical index size: 50-100MB for ~100k files
- Search latency: <50ms for most queries

## Author

Created by **Nicolai Tufar** — [github.com/ntufar](https://github.com/ntufar) — ntufar@gmail.com

## License

This project is open source. Feel free to modify and distribute according to your needs.

# McFind - macOS File Search Utility

[![macOS Build](https://github.com/ntufar/mcfind/actions/workflows/macos.yml/badge.svg)](https://github.com/ntufar/mcfind/actions/workflows/macos.yml)
[![Release](https://github.com/ntufar/mcfind/actions/workflows/release.yml/badge.svg)](https://github.com/ntufar/mcfind/actions/workflows/release.yml)
[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![macOS](https://img.shields.io/badge/macOS-14.0+-blue.svg)](https://www.apple.com/macos)
[![Xcode](https://img.shields.io/badge/Xcode-15.0+-blue.svg)](https://developer.apple.com/xcode)
[![License](https://img.shields.io/badge/License-Open%20Source-green.svg)](https://github.com/ntufar/mcfind)

A fast, modern macOS application for searching files in your home directory, inspired by Everything on Windows.

## Features

- **Lightning-fast search**: Indexes your home directory for instant file searching
- **Modern UI**: Clean, native macOS interface with SwiftUI
- **Smart filtering**: Intelligent search with exact matches prioritized
- **Keyboard navigation**: Use arrow keys to navigate, Enter to open files
- **File metadata**: Shows file size, modification date, and file type icons
- **Context menu**: Right-click for additional options like "Reveal in Finder"
- **Background indexing**: Non-blocking file indexing with progress indicator

## Download

### Latest Release (v0.0.3)
- **DMG Installer**: [Download McFind.dmg](https://github.com/ntufar/mcfind/releases/latest/download/McFind.dmg) - Easy drag-and-drop installation
- **PKG Installer**: [Download McFind.pkg](https://github.com/ntufar/mcfind/releases/latest/download/McFind.pkg) - Professional installer package

### Installation Instructions
1. **DMG**: Download the DMG file, open it, and drag McFind.app to your Applications folder
2. **PKG**: Download the PKG file and double-click to run the installer

### All Releases
View all available releases and download previous versions: [Releases Page](https://github.com/ntufar/mcfind/releases)

## Requirements

- macOS 14.0 or later
- Xcode 15.0 or later (for building from source)

## Building the Application

1. Open `McFind.xcodeproj` in Xcode
2. Select your target device/simulator
3. Press `Cmd+R` to build and run

## Usage

1. **Launch the app**: The application will automatically start indexing your home directory
2. **Search**: Type in the search bar to find files instantly
3. **Navigate**: Use arrow keys to navigate through results
4. **Open files**: Press Enter or double-click to open the selected file
5. **Reveal in Finder**: Right-click and select "Reveal in Finder" to show the file location

## Keyboard Shortcuts

- `↑` / `↓`: Navigate through search results
- `Enter`: Open the selected file
- `Escape`: Clear search (when search bar is focused)

## Architecture

The application is built with SwiftUI and follows MVVM architecture:

- **McFindApp**: Main app entry point
- **ContentView**: Main UI view with search bar and results list
- **FileItem**: Model representing file metadata
- **FileIndexer**: Handles file system indexing and search
- **SearchViewModel**: Manages search state and user interactions

## Privacy & Security

The app requests minimal file system permissions through sandboxing:
- Read-only access to user-selected files
- Read-only access to common directories (Downloads, Pictures, Music, Movies)
- Read-only access to home directory files

## Performance

- Indexing runs in background to avoid blocking the UI
- Search results are filtered and sorted in real-time
- File system access is optimized to skip unnecessary directories (caches, logs, etc.)

## License

This project is open source. Feel free to modify and distribute according to your needs.

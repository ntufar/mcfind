# McFind Development Guide

## Overview

McFind is a fast, local file search utility for macOS written in SwiftUI. It indexes your home directory in a SQLite database for instant search results.

## Architecture

### Core Components

1. **IndexDatabase.swift** - SQLite database layer
   - Stores file paths, names, sizes, and modification dates
   - Full-text search on both filename and path
   - Thread-safe queue-based access

2. **FileIndexer.swift** - File system indexing
   - Scans home directory on first launch
   - Real-time monitoring via FSEvents
   - Smart skipping of caches, logs, and build artifacts
   - Respects user exclusion settings

3. **IndexSettings.swift** - User preferences
   - Hierarchical path exclusions
   - Singleton pattern with UserDefaults persistence
   - Default: Library excluded, but CloudStorage and iCloud included

4. **SearchViewModel.swift** - Search logic and state
   - Debounced search input (150ms)
   - Background search queue
   - Publishes results to UI

5. **ContentView.swift** + **TableView.swift** - UI
   - NSTableView wrapped in SwiftUI for performance
   - Custom event handling for keyboard navigation
   - Fixed infinite loop issues with proper state management

6. **SettingsView.swift** - Settings interface
   - Hierarchical folder display
   - Toggle switches for each path
   - Re-index button

## Key Features

### Hierarchical Settings

Users can control indexing at three levels for Library:
- **Library** (OFF by default) - excludes system junk
- **Library/CloudStorage** (ON by default) - OneDrive, SharePoint, Google Drive
- **Library/Mobile Documents** (ON by default) - iCloud Drive

### Smart Indexing

Automatically skips:
- Build artifacts (node_modules, DerivedData, .next, target, etc.)
- Caches and logs
- Browser data
- Package bundles (.app, .xcodeproj, .framework, etc.)

### Fast Search

- Searches both filename and full path
- Ranking: exact match > prefix match > contains match > path match
- Limit 1000 results for performance
- SQLite indexes on name and path (case-insensitive)

## Bug Fixes Applied

### 1. Infinite Loop Fix (TableView)
**Problem:** SwiftUI bindings created feedback loop between table selection and view updates.

**Solution:**
- Removed `@Binding` from Coordinator's files array (read-only)
- Added `isProgrammaticSelection` flag
- Added `lastKnownSelection` to track processed updates
- Prevents both file-list and selection-change loops

### 2. Search Improvements
**Problem:** Only searched filename, not full path.

**Solution:**
- Updated SQL query to search both `name LIKE ? OR path LIKE ?`
- Added path-based ranking in ORDER BY

### 3. Settings Scene Conflict
**Problem:** Custom `Settings` class conflicted with SwiftUI `Settings` scene.

**Solution:**
- Renamed class to `IndexSettings`
- Used SwiftUI's `Settings {}` scene builder properly

## Building

### Requirements
- Xcode 14.0+
- macOS 13.0+ (Ventura) for Settings API
- Swift 5.7+

### First Build
1. Open `McFind.xcodeproj` in Xcode
2. Add new files to project if needed:
   - `IndexSettings.swift`
   - `SettingsView.swift`
3. Build (Cmd+B)
4. Run (Cmd+R)

### Clean Build
If you encounter issues:
1. Clean Build Folder (Cmd+Shift+K)
2. Quit Xcode
3. Delete `~/Library/Developer/Xcode/DerivedData/McFind-*`
4. Reopen and build

## Database

**Location:** `~/Library/Application Support/McFind/index.db`

**Schema:**
```sql
CREATE TABLE files (
    path TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    is_directory INTEGER NOT NULL,
    size INTEGER NOT NULL,
    modified_date REAL NOT NULL
);
CREATE INDEX idx_name ON files(name COLLATE NOCASE);
CREATE INDEX idx_path ON files(path COLLATE NOCASE);
```

**Debugging:**
```bash
sqlite3 ~/Library/Application\ Support/McFind/index.db "SELECT COUNT(*) FROM files;"
sqlite3 ~/Library/Application\ Support/McFind/index.db "SELECT * FROM files WHERE name LIKE '%search%' LIMIT 10;"
```

## Common Issues

### Files Not Found in Search
1. Check if folder is excluded in Settings (Cmd+,)
2. Trigger re-index (Cmd+Shift+R)
3. Check database: `sqlite3 ~/Library/.../index.db "SELECT path FROM files WHERE path LIKE '%keyword%';"`

### Slow Initial Index
- Normal for large home directories (100k+ files)
- Progress shown in status bar
- Can cancel and adjust exclusions in Settings

### App Hangs
- Should be fixed with infinite loop patches
- If persists, check Console.app for error messages
- Look for "Publishing changes from within view updates" warnings

## Testing

### Manual Testing Checklist
- [ ] Search finds files by name
- [ ] Search finds files by path
- [ ] Up/Down arrows navigate results
- [ ] Enter/Double-click opens file
- [ ] Settings window opens (Cmd+,)
- [ ] Toggle folders on/off works
- [ ] Re-index completes successfully
- [ ] File system changes are detected
- [ ] No infinite loops or hangs

### Performance Testing
```bash
# Measure index time
time sqlite3 ~/Library/Application\ Support/McFind/index.db "SELECT COUNT(*) FROM files;"

# Check database size
du -sh ~/Library/Application\ Support/McFind/index.db
```

## Future Improvements

Potential enhancements:
- [ ] Add file content search (requires indexing file contents)
- [ ] Support multiple index locations
- [ ] Export/import settings
- [ ] Smart folders / saved searches
- [ ] Keyboard shortcuts customization
- [ ] Dark mode support
- [ ] Preview pane
- [ ] Quick Look integration

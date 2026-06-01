# McFind Setup Guide

## Quick Start

1. **Open Project**
   ```bash
   cd /path/to/mcfind
   open McFind.xcodeproj
   ```

2. **Add New Files** (if not already in project)
   - Right-click "McFind" folder in Project Navigator
   - Select "Add Files to 'McFind'..."
   - Choose: `IndexSettings.swift` and `SettingsView.swift`
   - **Uncheck** "Copy items if needed"
   - **Check** "McFind" target
   - Click "Add"

3. **Build and Run**
   - Build: Cmd+B
   - Run: Cmd+R

4. **First Launch**
   - App will start indexing your home directory
   - Progress shown in status bar
   - Initial indexing may take 1-5 minutes depending on file count

5. **Configure Settings**
   - Open Settings: Cmd+, (or Menu → McFind → Settings)
   - Review folder inclusions/exclusions
   - Default: Library excluded, but CloudStorage and iCloud included
   - Click "Re-index Now" if you change settings

## Settings Explained

### Default Configuration

**Included by default:**
- Desktop, Documents, Downloads
- Movies, Music, Pictures
- Public, Applications
- Library/CloudStorage (OneDrive, SharePoint, Google Drive)
- Library/Mobile Documents (iCloud Drive)

**Excluded by default:**
- Library (main folder) - contains system caches and logs

**Always skipped** (regardless of settings):
- node_modules, .git, .svn
- Caches, Logs, DerivedData
- Browser data (Chrome, Firefox)
- Package bundles (.app, .xcodeproj, etc.)

### Customizing

You can toggle any folder on or off:

```
📁 Desktop                           [ON]
📁 Documents                         [ON]
📁 Library                           [OFF]
   ↳ CloudStorage                    [ON]  ← Your SharePoint, OneDrive
   ↳ iCloud Drive                    [ON]  ← Your iCloud documents
📁 Movies                            [ON]
```

**Recommendations:**
- Keep CloudStorage and iCloud ON to search cloud files
- Turn OFF Movies/Music if you don't need to search media
- Keep Library OFF to avoid indexing system junk

## Usage

### Search
- Type in search box (focus is automatic)
- Results appear instantly as you type
- Searches both filename and path

### Navigate Results
- **Up/Down arrows** - Navigate through results
- **Enter** - Open selected file
- **Double-click** - Open file
- **Escape** - Clear search or close window

### Keyboard Shortcuts
- **Cmd+,** - Open Settings
- **Cmd+Shift+R** - Re-index all files
- **Cmd+W** - Close window
- **Escape** - Clear search

## Troubleshooting

### Files Not Found

**Check 1:** Is the folder indexed?
1. Open Settings (Cmd+,)
2. Verify the folder toggle is ON
3. If you changed it, click "Re-index Now"

**Check 2:** Is the file actually there?
```bash
ls -la ~/path/to/file
```

**Check 3:** Check database
```bash
sqlite3 ~/Library/Application\ Support/McFind/index.db \
  "SELECT path FROM files WHERE path LIKE '%filename%';"
```

### Slow Performance

**Symptoms:** Search takes >1 second

**Solutions:**
1. Reduce indexed folders in Settings
2. Exclude large media folders (Movies, Music)
3. Check database size: `du -sh ~/Library/Application\ Support/McFind/index.db`
4. If >500MB, consider excluding more folders

### App Hangs or Freezes

**Should be fixed** - but if it happens:
1. Force quit (Cmd+Option+Esc)
2. Check Console.app for errors
3. Delete database and re-index:
   ```bash
   rm ~/Library/Application\ Support/McFind/index.db
   ```
4. Restart app (will re-index from scratch)

### Build Errors

**Error:** "Settings initializer is inaccessible"
- **Fix:** Renamed to `IndexSettings` - clean build (Cmd+Shift+K)

**Error:** "Cannot find SettingsView in scope"
- **Fix:** Add `SettingsView.swift` to project (see Setup step 2)

**Error:** "Extra trailing closure"
- **Fix:** Check SwiftUI syntax, likely in McFindApp.swift

## Advanced

### Custom Index Location

Edit `IndexDatabase.swift` line 16:
```swift
dbPath = appFolder.appendingPathComponent("index.db").path
```

### Add Custom Skip Patterns

Edit `FileIndexer.swift` around line 218:
```swift
let skipDirectoryNames = [
    "node_modules",
    "your_custom_folder"  // Add here
]
```

### Debug Logging

Check Xcode console for:
- `📁 Database path: ...` - Database location
- `📊 Loaded X files from disk` - Index size
- `🔍 IndexDatabase.search() called with: 'query'` - Search debugging
- `⚠️ Empty query, returning []` - Empty search

### Reset Everything

```bash
# Delete database
rm ~/Library/Application\ Support/McFind/index.db

# Delete settings
defaults delete com.mcfind.McFind

# Restart app - will re-initialize
```

## Support

For issues:
1. Check Console.app for error messages
2. Verify file permissions on home directory
3. Try clean build and re-index
4. Check GitHub issues (if project is public)

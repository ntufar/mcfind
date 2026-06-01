# Hierarchical Settings Feature

## Overview

McFind now supports fine-grained control over what gets indexed, with special handling for the Library folder and its important subfolders.

## Settings Structure

### Three-Level Hierarchy for Library:

1. **Library** (Top-level folder)
   - ❌ OFF by default
   - Controls indexing of Library folder *except* for explicitly enabled subfolders

2. **Library → CloudStorage** (Subfolder)
   - ✅ ON by default
   - Contains: OneDrive, SharePoint, Google Drive, Dropbox
   - Can be toggled independently of Library

3. **Library → iCloud Drive** (Subfolder)
   - ✅ ON by default  
   - Path: `Library/Mobile Documents`
   - Contains: iCloud Drive documents
   - Can be toggled independently of Library

### Other Top-Level Folders:

- Desktop ✅ ON by default
- Documents ✅ ON by default
- Downloads ✅ ON by default
- Movies ✅ ON by default
- Music ✅ ON by default
- Pictures ✅ ON by default
- Public ✅ ON by default
- Applications ✅ ON by default
- (any other folders found in home directory)

## How It Works

### Path Resolution Priority

The indexer uses **most-specific-path-first** logic:

1. Check if the specific path (e.g., `Library/CloudStorage`) is enabled
2. If enabled, index it regardless of parent folder setting
3. If disabled, skip it
4. For paths not explicitly listed, fall back to parent folder setting

### Example Scenarios:

**Scenario 1: Default Settings**
- Library: ❌ OFF
- Library/CloudStorage: ✅ ON
- Library/Mobile Documents: ✅ ON

Result:
- ✅ `~/Library/CloudStorage/OneDrive/` → Indexed (explicitly enabled)
- ✅ `~/Library/Mobile Documents/` → Indexed (explicitly enabled)
- ❌ `~/Library/Caches/` → NOT indexed (Library is OFF, no explicit override)
- ❌ `~/Library/Mail/` → NOT indexed (Library is OFF, no explicit override)

**Scenario 2: User Enables All Library**
- Library: ✅ ON
- Library/CloudStorage: ✅ ON (still)
- Library/Mobile Documents: ✅ ON (still)

Result:
- ✅ Everything in Library is indexed
- Including CloudStorage and iCloud Drive
- Except auto-skipped system folders (Caches, Logs, etc.)

**Scenario 3: User Disables Cloud Storage**
- Library: ❌ OFF
- Library/CloudStorage: ❌ OFF
- Library/Mobile Documents: ✅ ON

Result:
- ❌ CloudStorage NOT indexed (explicitly disabled)
- ✅ iCloud Drive still indexed (explicitly enabled)
- ❌ Rest of Library NOT indexed (Library is OFF)

## Automatic Skip List

These Library subfolders are **always skipped** regardless of settings:

- `Library/Caches` - Temporary cache files
- `Library/Logs` - System and application logs
- `Library/Mail` - Mail database (privacy + large size)
- `Library/Containers` - Sandboxed app data
- `Library/Application Support/Google/Chrome` - Browser cache/profiles
- `Library/Application Support/Firefox` - Browser cache/profiles
- `Library/Application Support/com.apple.*` - System app data
- `Library/Developer/Xcode/DerivedData` - Build artifacts
- `Library/Developer/CoreSimulator` - iOS Simulator data
- `Library/Saved Application State` - App state restoration

## UI Design

### Visual Hierarchy:

```
📁 Desktop                           ✅ ON
📁 Documents                         ✅ ON
📁 Downloads                         ✅ ON
📁 Library                           ❌ OFF
   ↳ Library → CloudStorage         ✅ ON
   ↳ Library → iCloud Drive         ✅ ON
📁 Movies                            ✅ ON
📁 Music                             ✅ ON
```

- Top-level folders show folder icon
- Subfolders show arrow icon and are indented
- Smaller font for subfolders
- Lighter background for subfolders

## Benefits

1. **Access Cloud Storage by Default**
   - SharePoint, OneDrive, Google Drive, Dropbox all indexed out of the box
   - No manual configuration needed

2. **Avoid Library Bloat**
   - Most of Library (caches, logs, system data) is excluded
   - Only user-relevant cloud storage is included

3. **User Control**
   - Can enable all Library if needed
   - Can disable specific cloud providers
   - Fine-grained per-path control

4. **Performance**
   - Smaller index size (exclude Library bloat)
   - Faster searches
   - But still find important cloud documents

## Migration

Existing installations:
- Will migrate from `excludedFolders` (old) to `excludedPaths` (new)
- Default setting: Library OFF, CloudStorage ON, iCloud ON
- Users can adjust as needed

## Technical Implementation

### IndexSettings Class

- Changed from `Set<String> excludedFolders` to `Set<String> excludedPaths`
- Supports hierarchical paths: "Library", "Library/CloudStorage", etc.
- `shouldIndexPath()` checks most-specific path first

### SettingsView

- Shows `IndexPath` objects with display names
- Indents sub-paths visually
- Sorts to show hierarchy clearly

### FileIndexer

- Calls `settings.shouldIndexPath()` for each file/folder
- Respects hierarchical rules
- Still skips known junk folders automatically

## Future Enhancements

Possible additions:
- Add more cloud provider paths as discovered
- Allow users to add custom paths
- Import/export settings profiles
- Show estimated index size per path

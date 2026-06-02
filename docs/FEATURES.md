# McFind Features

## Current Features ✅

### Instant Search
- Search across your entire home directory instantly
- Results appear as you type (150ms debounce)
- Search matches both file names and paths
- Case-insensitive search
- Smart ranking (exact matches first, then prefix matches)

### Persistent Index
- Index is saved to disk using SQLite
- Survives app restarts
- No need to re-index every launch
- Database location: `~/Library/Application Support/McFind/index.db`

### Real-time Updates
- Automatically detects file system changes
- Updates index when files are created, deleted, or renamed
- Uses macOS FSEvents API for efficient monitoring
- 1-second latency for event aggregation

### Smart Indexing
- Indexes directories themselves (searchable)
- Skips traversing large irrelevant directories:
  - `node_modules`, `__pycache__`, `.venv`
  - `.git`, `.svn`
  - System caches and logs
  - Application bundles (`.app`, `.framework`)
- Background indexing (non-blocking UI)
- Batch processing for performance

### Keyboard Shortcuts
- **↑/↓**: Navigate results (auto-focuses result list)
- **Enter**: Rename selected file (when result list is focused)
- **Enter**: Commit rename (during inline editing)
- **Escape**: Cancel rename (during inline editing)
- **Space**: Quick Look preview of selected file
- **Escape**: Clear search (or deselect if search is empty)
- **⌘⇧R**: Re-index files (menu command)

### Context Menu Actions
- Open in Default App
- Reveal in Finder
- Copy Path
- Copy File
- Share (via macOS Share Sheet)
- Rename (inline editing)
- Move to Trash

### Drag & Drop
- Drag files from result list to any drag destination (Finder, other apps, etc.)

### Quick Look
- Press Space to preview selected file
- Uses macOS QLPreviewPanel

### Size Filters
- Filter results by file size: <100KB, <1MB, <10MB, <100MB, >100MB, >1GB
- Combines with text search

### Visual Feedback
- Progress bar during initial indexing
- File count display
- Total indexed files shown
- Loading indicator when loading from disk
- File icons for each result
- File size and modification date

## Comparison with "Everything" (Windows)

| Feature | Everything | McFind | Status |
|---------|-----------|---------|--------|
| Instant search | ✅ | ✅ | ✅ Implemented |
| Persistent index | ✅ | ✅ | ✅ Implemented |
| Real-time monitoring | ✅ | ✅ | ✅ Implemented |
| Background indexing | ✅ | ✅ | ✅ Implemented |
| Size filters | ✅ | ✅ | ✅ Implemented |
| Quick Look preview | ✅ | ✅ | ✅ Implemented |
| Regex search | ✅ | ✅ | ✅ Implemented |
| Multiple drives | ✅ | ❌ | Home directory only |
| Advanced filters | ✅ | ❌ | Future enhancement |
| HTTP server | ✅ | ❌ | Not planned |
| Network shares | ✅ | ❌ | Not planned |

## Future Enhancements 🚀

### Short Term
- [x] Advanced search syntax (wildcards, regex)
- [x] Quick Look / file preview on selection (Space key)
- [x] Size filters (file size ranges)
- [x] Move to Trash from context menu
- [ ] File type filters (show only: images, documents, etc.)
- [ ] Date filters (modified in last week, month, etc.)
- [ ] Exclude patterns (user-configurable skip list)
- [ ] Launch at login option
- [ ] Menu bar icon with quick search popup

### Medium Term
- [ ] Multiple directory support (not just home)
- [ ] Index statistics dashboard
- [ ] Search history
- [ ] Bookmarks/favorites
- [ ] Duplicate file finder
- [ ] Empty folder detection

### Long Term
- [ ] iCloud Drive support
- [ ] Network drive support
- [ ] Incremental indexing (only scan changed directories)
- [ ] Export search results
- [ ] Plugins/extensions API
- [ ] Cloud sync of index

## Known Limitations

1. **Home Directory Only**: Currently only indexes user's home directory
2. **macOS Only**: Uses macOS-specific APIs (FSEvents, SQLite)
3. **No Full Disk Access by Default**: User must manually grant in System Settings
4. **Result Limit**: Search results capped at 1000 for UI performance
5. **No Network Drives**: Only local file systems supported
6. **No Content Search**: Only searches file/directory names and paths, not file contents

## Performance Characteristics

### Indexing
- Speed: 10,000-20,000 files/second (SSD)
- Memory: ~100-200 MB during indexing
- Disk: ~50-100 bytes per file in database
- Example: 500,000 files = ~50MB database

### Searching
- Latency: < 50ms for most queries
- Result limit: 1000 files (for UI responsiveness)
- Debounce: 150ms after last keystroke
- Background execution: Non-blocking UI

### Monitoring
- Event latency: 1 second aggregation
- Memory overhead: Minimal (~5-10 MB)
- CPU usage: < 1% idle, spikes briefly on file changes

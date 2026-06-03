# McFind Specification

> Living document tracking implemented and planned features.

## Search Engine

- [x] Instant search across home directory
- [x] 150ms debounce on keystrokes
- [x] Search both filename and full path
- [x] SQLite `LIKE`-based pattern matching
- [x] Smart ranking: exact match > prefix match > substring match > path match
- [x] Unicode-aware case-insensitive search (Greek, Romanian, Russian, etc.)
- [x] Normalized columns (`name_normalized`, `path_normalized`) with Swift `lowercased()`
- [x] SQLite indexes on normalized columns for performance
- [x] 1000 result limit for UI responsiveness
- [x] Background search queue (`com.mcfind.search`)
- [x] Advanced search syntax (wildcards, regex)
- [ ] File type filters (images, documents, etc.)
- [x] Size filters (>1GB, <100KB, etc.)
- [ ] Date filters (modified in last week, month)
- [ ] Search history
- [ ] File content search (full-text indexing)

## Indexing

- [x] SQLite persistent index (survives restarts)
- [x] WAL journal mode + `synchronous=NORMAL` for low write amplification
- [x] Batch inserts (1000 files per transaction) during full/incremental index
- [x] Batch FSEvent writes (5-second debounce, single transaction per flush)
- [x] Background indexing (`com.mcfind.indexing`, qos `.utility`)
- [x] Progress indicator during indexing
- [x] Cancel indexing in progress
- [x] Smart skip list for junk directories:
  - [x] `node_modules`, `__pycache__`, `.venv`, `target`, `dist`, `build`
  - [x] `.git`, `.svn`, `.hg`
  - [x] System caches (`/Library/Caches`, `/Library/Logs`)
  - [x] Browser data (Chrome, Firefox profiles)
  - [x] Xcode build artifacts (`DerivedData`, `CoreSimulator`)
  - [x] Application bundles (`.app`, `.framework`, `.xcodeproj`)
  - [x] `.Trash`, `Mail`, `Containers`, `Saved Application State`
- [x] Schema migration support (normalized columns for Unicode search)
- [x] Indexes directories themselves (not just files)
- [x] Periodic VACUUM — hourly freelist check (>10K free pages, >10% ratio) prevents index bloat
- [ ] Multiple directory support (not just home)
- [x] Incremental indexing (scan only changed directories)
- [ ] Index statistics dashboard
- [ ] Export/import index

## File Monitoring (FSEvents)

- [x] File system change detection via FSEvents
- [x] Changes buffered in memory with 5-second debounce
- [x] Batched SQLite writes in a single transaction per flush
- [x] Handles create, delete, modify, rename events
- [x] Ignores database directory events
- [x] Respects settings-based path exclusion
- [x] Remaining buffer flushed on deinit
- [ ] Monitor external drives
- [ ] Monitor network shares

## User Interface

- [x] Native SwiftUI + AppKit hybrid
- [x] Search bar with clear button
- [x] Results list with columns: Name, Path, Size, Modified
- [x] File icons per result
- [x] File size formatting (KB/MB/GB)
- [x] Smart date formatting (Today/Yesterday/day name/full date)
- [x] Status bar: result count + total indexed files
- [x] Loading indicator during index load
- [x] Progress bar with file count during indexing
- [x] Empty state messages ("Start typing to search", "No files found")
- [x] Alternating row backgrounds
- [x] Resizable columns
- [x] Compact mode toggle (UserDefaults)
- [x] Show full path toggle (UserDefaults)
- [x] Hidden title bar with transparent background
- [x] Search cursor always active — typing works without clicking into search field
- [x] Right-click context menu on results (Open, Reveal in Finder, Copy Path, Copy File, Share)
- [ ] Advanced filters UI panel
- [ ] Search history dropdown
- [ ] Quick Look + Preview column (preview pane with file metadata)
- [ ] File preview on selection
- [ ] Dark mode refinements
- [ ] Menu bar icon with quick search popup
- [ ] Launch at login option

## Settings & Configuration

- [x] Hierarchical path inclusion/exclusion
- [x] Three-level Library control: Library → CloudStorage → iCloud Drive
- [x] Default: Library OFF, CloudStorage ON, iCloud ON
- [x] Visual hierarchy in settings (indentation, arrow icons, smaller font)
- [x] Settings persistence via UserDefaults
- [x] "Reset to Defaults" button
- [x] Re-index prompt after settings change
- [x] Index dot files and directories toggle (UserDefaults, default off)
- [ ] User-customizable skip patterns
- [ ] Import/export settings profiles
- [ ] Show estimated index size per path

## Keyboard Navigation

- [x] ↑/↓ navigate results
- [x] Enter starts rename on selected file (when result list is focused)
- [x] Escape cancels inline rename
- [x] Escape clears search or closes window
- [x] Cmd+Shift+R re-index
- [x] Cmd+, opens settings
- [x] Cmd+W closes window
- [x] Double-click opens file
- [x] Auto-focus search field on launch
- [ ] Customizable keyboard shortcuts

## Context Menu Actions

- [x] Open in Default App
- [x] Reveal in Finder
- [x] Copy Path
- [x] Copy File
- [x] Share menu
- [x] Rename (inline editing)
- [x] Open Terminal Here (open terminal at file's directory)
- [x] Copy Path (Escaped for Terminal)

## Drag & Drop

- [x] Drag files from result list to external destinations (Finder, apps, etc.)

## Data Model

- [x] `FileItem` struct with `path`, `name`, `isDirectory`, `size`, `dateModified`, `fileExtension`
- [x] `Identifiable` (UUID) and `Hashable`
- [x] `NSImage` icon resolution via `UTType`
- [ ] Bookmarks/favorites
- [ ] File tagging (read/write macOS tags, search/filter by tag)

## Build & Deployment

- [x] Xcode project (McFind.xcodeproj)
- [x] macOS 14.0+ (Sonoma) minimum target
- [x] Swift 5.7+
- [x] GitHub Actions CI/CD:
  - [x] macOS build workflow
  - [x] Release workflow (DMG + PKG)
  - [x] Ad-hoc code signing
- [x] GitHub Pages website (docs/index.html)
- [x] Application icon (SVG + PNG)
- [x] `.claude/rules.md` project guidelines
- [ ] Notarization
- [ ] App Store submission

## Documentation

- [x] README.md — project overview, badges, download links
- [x] CHANGELOG.md — version history (Keep a Changelog format)
- [x] docs/SETUP.md — installation and configuration guide
- [x] docs/DEVELOPMENT.md — architecture and developer guide
- [x] docs/HIERARCHICAL_SETTINGS.md — settings feature details
- [x] docs/FEATURES.md — complete feature list
- [x] docs/PROJECT_STRUCTURE.md — repository layout
- [x] docs/SPEC.md — this file
- [ ] API documentation (DocC)
- [ ] Contribution guide

## Known Limitations

- Home directory only (no external drives / network shares)
- macOS only (uses FSEvents, AppKit)
- Full Disk Access must be granted manually
- 1000 result cap
- No file content search
- No file content search
- Incremental indexing relies on directory mtime changes; files content-modified in-place (no directory mtime change) are only caught on next full reindex

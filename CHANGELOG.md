# Changelog

All notable changes to McFind will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.4] - 2026-06-03

### Added
- Applications folder symlink in DMG installer for drag-and-drop installation
- WAL journal mode + `synchronous=NORMAL` PRAGMAs to reduce write amplification
- FSEvent write batching: file system changes buffered in memory with 5-second debounce, flushed as a single SQLite transaction
- `IndexDatabase.applyChanges(inserts:deletes:)` for mixed batch operations in one transaction

### Changed
- FSEvent handling no longer writes to SQLite per-event; accumulates in a buffer and commits after 5 seconds of inactivity
- Database round-trips during file bursts reduced from 1-per-event to 1-per-5-second-window

## [0.2.3] - 2026-06-03

### Fixed
- Status bar not showing any content during indexing (SearchViewModel not forwarding FileIndexer's `objectWillChange`)
- "Scanning for file changes..." showing indefinitely with no visible progress during incremental indexing
- Flashing status messages caused by competing UI update blocks

### Added
- Real-time enumeration progress during incremental scanning — checked item count displayed every 1000 items

### Changed
- Simplified status bar fallback to always display the indexed item count regardless of indexing mode

## [0.2.2] - 2026-06-03

### Added
- Drag-and-drop support: files can now be dragged from the result list to other applications (Finder, etc.)
- Inline rename: right-click a file and select "Rename", or press Enter when the result list is focused
- Enter key on a selected file in the result list now starts rename (instead of opening the file)
- Escape key cancels inline rename and restores the original name
- Visual feedback during rename: text field shows a background while editing

### Changed
- `selectedFile` converted from stored `@Published` property to computed property, reducing redundant view updates
- **Keyboard behavior**: Enter now triggers rename when the result list is focused; double-click still opens the file

### Fixed
- "Modifying state during view update" warnings caused by mutating `@Binding` inside `NSViewRepresentable.updateNSView`
- `tableViewSelectionDidChange` delegate no longer modifies `@Published` state synchronously during view update cycles
- Intents framework `linkd` connection errors suppressed via Info.plist keys
- Arrow-key navigation with automatic table view focus
- Author credit in README, website footer, and macOS About dialog

### Removed
- Direct `selectedFile` property writes — now derived from `files[selectedIndex]`

## [0.2.0] - 2026-06-02

### Added
- Quick Look integration: press Space to preview selected file with QLPreviewPanel
- Size filters (file size ranges) in search results toolbar
- "Move to Trash" option in results context menu (right-click)

### Fixed
- Dot files ("."-prefixed) no longer appear in search results
- Single-click on search results no longer opens files (now requires double-click or Enter)
- Escape key in Quick Look no longer erases search text field
- Quick Look closing no longer resets selection to first file
- Search text field refocus no longer triggers duplicate searches

## [0.1.4] - 2026-06-02

### Added
- Advanced search syntax: wildcards (`*`, `?`) and regex (`/pattern/`) support
- Incremental indexing: startup now only scans changed directories (compares stored directory mtime vs current). Unchanged subtrees are bulk-marked via SQL, avoiding filesystem walks and DB writes. Stale entries from deleted/excluded paths are auto-cleaned. Full reindex still available via Cmd+Shift+R.
- `dir_mtime` and `metadata` tables in SQLite for tracking directory modification times and index generation counter
- `generation` column on `files` table for mark-and-sweep cleanup of stale entries
- `FileItem` init from pre-read file properties to avoid double stat during enumeration

## [0.1.3] - 2026-06-02

### Added
- Unicode-aware case-insensitive search (Greek, Romanian, Russian, etc.)
- SPEC.md tracking implemented and planned features
- Automatic VACUUM when database has >10K free pages (>10%)

### Changed
- Search uses normalized (lowercased) name/path columns for Unicode case folding
- File icon resolution simplified to `NSWorkspace.shared.icon(forFile:)` for reliability
- Disabled automatic Shortcuts registration to avoid linkd service crash

### Fixed
- Crash on startup from `dbQueue.sync` inside `dbQueue.async` (VACUUM deadlock)
- Crash from zero-size NSImage in SwiftUI `Image(nsImage:)`
- Database bloat from accumulated FSEvent-driven deletes

## [0.1.2] - 2026-06-02

### Added
- Professional website with GitHub Pages deployment (docs/index.html)
- Application icon with magnifying glass design (SVG + all PNG sizes)
- Icon generation scripts (generate_icons.py, generate_icons_simple.py)
- Ad-hoc code signing in CI/CD workflows to prevent Gatekeeper warnings
- Comprehensive documentation:
  - DEPLOYMENT.md - GitHub Pages deployment guide
  - CODE_SIGNING.md - Complete code signing guide
  - ICONS.md - Icon generation guide
- Website features:
  - Modern responsive design with macOS-inspired styling
  - Feature highlights and download links
  - Keyboard shortcuts reference
  - Performance metrics section
  - Favicon and header logo

### Changed
- Updated CI/CD workflows (macos.yml, release.yml) to include automatic ad-hoc signing
- Website now auto-deploys on push to master via GitHub Actions

## [0.1.1] - 2026-06-02

### Fixed
- Performance improvements for large database initialization

## [0.1.0] - 2026-06-02

### Added
- Hierarchical settings for granular control over indexed folders
- Library/CloudStorage subfolder (ON by default) - indexes OneDrive, SharePoint, Google Drive, Dropbox
- Library/Mobile Documents subfolder (ON by default) - indexes iCloud Drive
- Search now includes full file paths, not just filenames
- Settings window with folder toggles (Cmd+,)
- Re-index command (Cmd+Shift+R)
- Visual hierarchy in settings (indented subfolders with arrow icons)
- Comprehensive documentation in docs/ folder (SETUP.md, DEVELOPMENT.md, HIERARCHICAL_SETTINGS.md)
- CHANGELOG.md for tracking version history
- Project rules in .claude/rules.md

### Changed
- Library folder now excluded by default (but cloud subfolders are included)
- Settings renamed from `Settings` to `IndexSettings` to avoid SwiftUI conflict
- Minimum macOS version requirement updated to 13.0 (Ventura)
- Search query now uses `name LIKE ? OR path LIKE ?` for better results
- Improved skip list to exclude more system junk (Saved Application State, com.apple.* folders)

### Fixed
- Infinite loop issue when selecting items in table view
- "Publishing changes from within view updates" warnings
- TableView selection feedback loop with programmatic vs user selection
- Files array binding causing unnecessary reloads
- Settings window now uses proper SwiftUI Settings scene
- "Loading index..." hang with large databases (1M+ files) - UI now shows immediately

### Removed
- Old documentation files consolidated into docs/ folder

## [0.0.3] - 2025-09-15

### Added
- GitHub Actions workflows for automated builds
- DMG and PKG installers
- Release automation

### Changed
- Updated README with download links and badges
- Improved CI/CD pipeline

## [0.0.2] - 2024-12-31

### Added
- Background indexing with progress indicator
- Real-time file system monitoring via FSEvents
- SQLite-based index for fast searching
- File metadata display (size, date, icons)

### Changed
- Switched from in-memory to persistent SQLite storage
- Improved indexing performance with batch inserts

### Fixed
- Memory leaks in file enumeration
- UI blocking during initial index

## [0.0.1] - 2024-12-01

### Added
- Initial release
- Basic file search functionality
- SwiftUI interface
- Home directory indexing
- Keyboard navigation
- File opening on Enter/double-click

---

## Release Process

When preparing a new release:

1. **Update this CHANGELOG.md:**
   - Move items from [Unreleased] to new version section
   - Add release date
   - Create new empty [Unreleased] section

2. **Update version in project:**
   - Xcode: Select project → General → Version
   - Update CFBundleShortVersionString in Info.plist

3. **Update README.md:**
   - Update version number in "Latest Release" section
   - Update download links if needed

4. **Commit and tag:**
   ```bash
   git add CHANGELOG.md README.md
   git commit -m "Release vX.Y.Z"
   git tag -a vX.Y.Z -m "Release vX.Y.Z"
   git push origin main --tags
   ```

5. **GitHub Release:**
   - Create release on GitHub with tag
   - Copy changelog section to release notes
   - Upload DMG and PKG installers

[0.2.4]: https://github.com/ntufar/mcfind/releases/tag/v0.2.4
[0.2.3]: https://github.com/ntufar/mcfind/releases/tag/v0.2.3
[0.2.2]: https://github.com/ntufar/mcfind/releases/tag/v0.2.2
[0.2.0]: https://github.com/ntufar/mcfind/releases/tag/v0.2.0
[0.1.4]: https://github.com/ntufar/mcfind/releases/tag/v0.1.4
[0.1.3]: https://github.com/ntufar/mcfind/releases/tag/v0.1.3
[0.1.2]: https://github.com/ntufar/mcfind/releases/tag/v0.1.2
[0.1.1]: https://github.com/ntufar/mcfind/releases/tag/v0.1.1
[0.1.0]: https://github.com/ntufar/mcfind/releases/tag/v0.1.0
[0.0.3]: https://github.com/ntufar/mcfind/releases/tag/v0.0.3
[0.0.2]: https://github.com/ntufar/mcfind/releases/tag/v0.0.2
[0.0.1]: https://github.com/ntufar/mcfind/releases/tag/v0.0.1

## Version Numbering

We use Semantic Versioning (MAJOR.MINOR.PATCH):

- **MAJOR**: Incompatible changes, major rewrites
- **MINOR**: New features, backwards-compatible
- **PATCH**: Bug fixes, backwards-compatible

Examples:
- New feature: 0.0.3 → 0.1.0
- Bug fix: 0.1.0 → 0.1.1
- Breaking change: 0.1.1 → 1.0.0

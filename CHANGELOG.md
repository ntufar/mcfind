# Changelog

All notable changes to McFind will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
### Changed
### Fixed
### Removed

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

## Version Numbering

We use Semantic Versioning (MAJOR.MINOR.PATCH):

- **MAJOR**: Incompatible changes, major rewrites
- **MINOR**: New features, backwards-compatible
- **PATCH**: Bug fixes, backwards-compatible

Examples:
- New feature: 0.0.3 → 0.1.0
- Bug fix: 0.1.0 → 0.1.1
- Breaking change: 0.1.1 → 1.0.0

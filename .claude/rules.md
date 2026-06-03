# McFind Project Rules

## Development Guidelines

### Code Quality
- Prefer SwiftUI native components over custom implementations
- Use `@Published` for observable state changes
- Avoid force unwrapping - use `guard` or optional binding
- Write self-documenting code - minimal comments unless explaining "why"
- No premature abstractions - implement what's needed now

### Architecture
- Follow MVVM pattern
- Keep ViewModels focused on a single responsibility
- Database access only through `IndexDatabase` class
- Settings access only through `IndexSettings.shared`
- Use background queues for I/O operations

### Performance
- Use SQLite indexes on searchable fields
- Batch database operations where possible
- Debounce user input (150ms for search)
- Skip unnecessary file system operations

### Testing
- **Every time code is changed**, the corresponding tests must be updated or new tests must be added to cover the change.
- **All tests must pass before committing changes.**
- Run tests using `xcodebuild test -project McFind.xcodeproj -scheme McFind -destination 'platform=macOS'` or via Xcode's test navigator.
- Test changes in the actual app before marking complete
- Verify keyboard shortcuts work
- Check that file monitoring detects changes
- Test with large file counts (100k+ files)

## Release Process

### ⚠️ BEFORE EVERY RELEASE - UPDATE CHANGELOG

**This is mandatory. Do not skip.**

When preparing a release:

1. **Update CHANGELOG.md** (in project root)
   - Move all items from `[Unreleased]` section to new version section
   - Add today's date in format `[X.Y.Z] - YYYY-MM-DD`
   - Create new empty `[Unreleased]` section at top
   - Categorize changes under: Added, Changed, Fixed, Removed

2. **Verify test coverage**
   - Ensure all new functionality and changes have corresponding test coverage
   - Run full test suite and confirm all tests pass
   - Update existing tests if behavior changed

3. **Update version numbers**
   - Xcode project: General → Version
   - README.md: Latest Release section
   - Info.plist: CFBundleShortVersionString

4. **Update README.md**
   - Version number in "Latest Release (vX.Y.Z)" section
   - Download links (if release process changed)

5. **Commit and tag**
   ```bash
   git add CHANGELOG.md README.md McFind.xcodeproj
   git commit -m "Release vX.Y.Z"
   git tag -a vX.Y.Z -m "Release vX.Y.Z"
   git push origin main --tags
   ```

6. **Create GitHub Release**
   - Use the tag created above
   - Copy the changelog section for this version into release notes
   - Upload DMG and PKG installers

### Version Numbering (Semantic Versioning)

- **PATCH** (0.0.X): Bug fixes, small improvements, no new features
- **MINOR** (0.X.0): New features, backwards-compatible changes
- **MAJOR** (X.0.0): Breaking changes, major rewrites, API changes

Examples:
- Fixed infinite loop → 0.0.3 → 0.0.4 (PATCH)
- Added settings feature → 0.0.4 → 0.1.0 (MINOR)
- Redesigned entire UI → 0.1.0 → 1.0.0 (MAJOR)

## Git Workflow

### Commit Messages
Use conventional commits format:
- `feat: add hierarchical settings`
- `fix: resolve infinite loop in table view`
- `docs: update README with new features`
- `refactor: rename Settings to IndexSettings`
- `perf: optimize database queries`

### Branching
- `main` - stable, release-ready code
- Feature branches: `feature/settings-ui`
- Bug fixes: `fix/table-selection-loop`

## Documentation

### When to Update Docs

**Update immediately when:**
- Adding a new feature → Update docs/FEATURES.md
- Changing behavior → Update docs/DEVELOPMENT.md
- Adding settings → Update docs/HIERARCHICAL_SETTINGS.md
- Fixing a bug → Update CHANGELOG.md (Unreleased section)

**Location of docs:**
- User-facing: docs/SETUP.md
- Developer-facing: docs/DEVELOPMENT.md
- Technical details: docs/HIERARCHICAL_SETTINGS.md
- Changes: CHANGELOG.md
- Overview: README.md

### Style Guide
- Use clear, concise language
- Include code examples where helpful
- Use markdown formatting consistently
- Link between related documents
- Keep README.md brief, link to detailed docs

## File Organization

### Source Files
```
McFind/
├── IndexDatabase.swift      # SQLite layer
├── FileIndexer.swift        # File system indexing
├── IndexSettings.swift      # User preferences
├── SearchViewModel.swift    # Search logic
├── ContentView.swift        # Main UI
├── TableView.swift          # Results table
├── SettingsView.swift       # Settings UI
├── FileItem.swift           # Data model
├── FileMonitor.swift        # FSEvents monitoring
├── KeyEventHandling.swift   # Keyboard shortcuts
└── McFindApp.swift          # App entry point
```

### Documentation
```
docs/
├── SETUP.md                 # User installation guide
├── DEVELOPMENT.md           # Developer guide
├── HIERARCHICAL_SETTINGS.md # Settings details
└── FEATURES.md              # Feature list
```

## Deprecation Policy

When deprecating features:
1. Add deprecation notice to CHANGELOG.md
2. Keep deprecated code for at least one MINOR version
3. Provide migration path in documentation
4. Remove in next MAJOR version

## Questions or Issues?

- Check docs/ folder first
- Look at CHANGELOG.md for recent changes
- Review existing code for patterns
- Ask in GitHub issues (if public repo)

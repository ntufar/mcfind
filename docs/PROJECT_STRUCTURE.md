# McFind Project Structure

## Repository Layout

```
mcfind/
├── .claude/
│   ├── rules.md              # Project rules & release process
│   └── settings.local.json   # Claude Code local settings
├── docs/
│   ├── SETUP.md              # User installation & configuration
│   ├── DEVELOPMENT.md        # Developer guide & architecture
│   ├── HIERARCHICAL_SETTINGS.md  # Settings feature details
│   ├── FEATURES.md           # Complete feature list
│   └── PROJECT_STRUCTURE.md  # This file
├── McFind/                   # Source code
│   ├── IndexDatabase.swift
│   ├── FileIndexer.swift
│   ├── IndexSettings.swift
│   ├── SearchViewModel.swift
│   ├── ContentView.swift
│   ├── TableView.swift
│   ├── SettingsView.swift
│   ├── FileItem.swift
│   ├── FileMonitor.swift
│   ├── KeyEventHandling.swift
│   └── McFindApp.swift
├── McFind.xcodeproj/         # Xcode project
├── CHANGELOG.md              # Version history
└── README.md                 # Main entry point
```

## Key Files

### User Documentation
- **README.md** - Main project overview, download links, quick start
- **CHANGELOG.md** - Version history and release notes
- **docs/SETUP.md** - Installation guide and troubleshooting
- **docs/FEATURES.md** - Complete feature list

### Developer Documentation
- **docs/DEVELOPMENT.md** - Architecture, components, debugging
- **docs/HIERARCHICAL_SETTINGS.md** - Settings implementation details
- **docs/PROJECT_STRUCTURE.md** - This file

### Project Rules
- **.claude/rules.md** - Development guidelines and release process
  - **⚠️ Important:** Contains mandatory CHANGELOG update requirement for releases

## Documentation Flow

When users need help:
1. Start with **README.md** for overview
2. Go to **docs/SETUP.md** for installation/config
3. Check **CHANGELOG.md** for recent changes
4. Refer to **docs/FEATURES.md** for specific features

When developers contribute:
1. Read **docs/DEVELOPMENT.md** for architecture
2. Follow **.claude/rules.md** for guidelines
3. Update **CHANGELOG.md** for all changes
4. Update relevant docs when adding features

## Release Checklist

Before every release, check:
- [ ] CHANGELOG.md updated (move Unreleased → version section)
- [ ] Version number updated in Xcode project
- [ ] README.md download section updated
- [ ] All new features documented
- [ ] All bug fixes documented
- [ ] Git tag created (vX.Y.Z)

See `.claude/rules.md` for detailed release process.

## Need Help?

- User questions → docs/SETUP.md
- Developer questions → docs/DEVELOPMENT.md
- Feature requests → GitHub Issues
- Bug reports → GitHub Issues + CHANGELOG.md

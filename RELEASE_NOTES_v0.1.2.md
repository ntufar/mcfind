# McFind v0.1.2 - Website, Icon, and Code Signing

**Release Date:** June 2, 2026

This release adds a professional website, application icon, and code signing to prevent macOS Gatekeeper warnings.

## 🌐 New Website

- **Live at:** https://ntufar.github.io/mcfind/ (once GitHub Pages is enabled)
- Professional landing page with modern, responsive design
- macOS-inspired styling with blue gradient (#007AFF)
- Feature highlights, download links, and keyboard shortcuts
- Automated deployment via GitHub Actions

## 🎨 Application Icon

- New magnifying glass icon with document lines
- Blue gradient background matching macOS design language
- All required macOS sizes (16x16 to 1024x1024 with @2x variants)
- Icon appears in app, dock, Finder, and website

## 🔐 Code Signing

- Ad-hoc code signing prevents "Apple could not verify" warnings
- Automatic signing in all CI/CD workflows
- Comprehensive documentation for distribution signing

## 📚 Documentation

New comprehensive guides:

- **DEPLOYMENT.md** - GitHub Pages deployment and website updates
- **CODE_SIGNING.md** - Complete code signing guide with 3 solutions:
  - Ad-hoc signing (free, current setup)
  - Developer ID signing (for distribution)
  - Self-signed certificate (free alternative)
- **ICONS.md** - Icon generation and customization guide

## 🛠️ Developer Tools

- `generate_icons_simple.py` - Generate all macOS icon sizes from code (PIL-based)
- `generate_icons.py` - Generate icons from SVG source (requires cairosvg)
- Updated CI/CD workflows with automatic ad-hoc signing

## 📦 Installation

### DMG Installer (Recommended)
1. Download [McFind.dmg](https://github.com/ntufar/mcfind/releases/latest/download/McFind.dmg)
2. Open the DMG file
3. Drag McFind.app to your Applications folder
4. Launch McFind from Applications

### PKG Installer
1. Download [McFind.pkg](https://github.com/ntufar/mcfind/releases/latest/download/McFind.pkg)
2. Double-click to run the installer
3. Follow the installation prompts
4. Launch McFind from Applications

**Note:** The app is now ad-hoc signed, which should prevent Gatekeeper warnings on the build machine. If you still see a warning, right-click the app and select "Open" to allow it.

## 🔄 Upgrading from v0.1.1

This is a non-breaking release. Simply download and install the new version. Your existing index and settings will be preserved.

## 📝 Full Changelog

See [CHANGELOG.md](CHANGELOG.md) for detailed changes.

## 🐛 Known Issues

None specific to this release. See [GitHub Issues](https://github.com/ntufar/mcfind/issues) for all known issues.

## 🙏 Contributing

Contributions are welcome! Please feel free to submit a Pull Request or open an issue.

## 📄 License

Open Source - see repository for details.

---

**Previous Release:** [v0.1.1](RELEASE_NOTES_v0.1.1.md) - Performance improvements

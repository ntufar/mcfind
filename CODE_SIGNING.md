# Code Signing & Notarization

McFind is distributed outside the Mac App Store, signed with a **Developer ID** certificate
and **notarized** by Apple, so it opens on any Mac without Gatekeeper warnings.

| Setting | Value |
|---|---|
| Team | Nicolai Tufar (`6CT959RWB8`) |
| App signing identity | `Developer ID Application: Nicolai Tufar (6CT959RWB8)` |
| Installer signing identity | `Developer ID Installer: Nicolai Tufar (6CT959RWB8)` |
| Hardened runtime | Enabled (`ENABLE_HARDENED_RUNTIME = YES`) |
| Export method | `developer-id` (`scripts/ExportOptions.plist`) |

Certificates expire **2031-09-17**.

## Making a release locally

```bash
./scripts/release.sh
```

This archives the app, exports it with Developer ID, notarizes and staples the app,
builds `McFind.dmg` and `McFind.pkg`, signs, notarizes and staples both, and runs a
Gatekeeper assessment. Output goes to `build/release/`.

`SKIP_NOTARIZE=1 ./scripts/release.sh` produces signed but un-notarized artifacts (fast, for testing).

### One-time setup on a new Mac

1. Import the Developer ID Application and Installer identities (`.p12`) into the login keychain.
   Check with `security find-identity -v | grep "Developer ID"`.
2. Store notarization credentials (App Store Connect API key "McFind Notarization",
   Developer role) under the profile name the script uses:
   ```bash
   xcrun notarytool store-credentials mcfind-notary \
     --key ~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8 \
     --key-id <KEY_ID> --issuer <ISSUER_ID>
   ```
3. `brew install create-dmg`

## CI (GitHub Actions)

Pushing a `v*` tag runs `.github/workflows/release.yml`, which imports the certificates into a
temporary keychain, runs `scripts/release.sh`, publishes the DMG and PKG to a GitHub release, and
updates the Homebrew tap.

Repository secrets:

| Secret | Contents |
|---|---|
| `DEVELOPER_ID_P12` | base64 `.p12` of the Developer ID Application identity |
| `DEVELOPER_ID_INSTALLER_P12` | base64 `.p12` of the Developer ID Installer identity |
| `DEVELOPER_ID_P12_PASSWORD` | password for both `.p12` files |
| `ASC_API_KEY_P8` | base64 App Store Connect API key (`AuthKey_*.p8`) |
| `ASC_API_KEY_ID` | API key ID |
| `ASC_API_ISSUER_ID` | API issuer ID |

`macos.yml` and `distribute.yml` build with `CODE_SIGNING_ALLOWED=NO` (they only check that the
app builds and produce ad-hoc test artifacts).

## Verifying a build

```bash
codesign --verify --deep --strict --verbose=2 McFind.app
codesign -dvv McFind.app                       # Authority=Developer ID Application…, flags=runtime
spctl --assess --type execute --verbose McFind.app   # source=Notarized Developer ID
xcrun stapler validate McFind.dmg
pkgutil --check-signature McFind.pkg
```

## Troubleshooting

- **Notarization "Invalid"**: `xcrun notarytool log <submission-id> --keychain-profile mcfind-notary`
  shows which binary failed and why (usually missing hardened runtime or a secure timestamp).
- **`errSecInternalComponent` in CI**: the key partition list wasn't set; see the import step in `release.yml`.
- **Rotating certificates**: create new ones at developer.apple.com → Certificates, then update the keychain and the `.p12` secrets.

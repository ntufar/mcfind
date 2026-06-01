# Code Signing Guide for McFind

This document explains how to code sign the McFind application to prevent macOS Gatekeeper warnings.

## The Problem

When you build and run a macOS app without code signing, macOS Gatekeeper shows a warning:

> "McFind" Not Opened
> 
> Apple could not verify "McFind" is free of malware that may harm your Mac or compromise your privacy.

## Solutions

### ✅ Solution 1: Ad-Hoc Signing (Current Setup)

**What it does:** Signs the app without a certificate. Works on your Mac and prevents the warning.

**Limitations:** 
- Only works on the Mac where it was signed
- Other users will still see the warning
- Cannot be distributed through Mac App Store

**How to use:**

The CI/CD workflows now automatically apply ad-hoc signing. For local builds:

```bash
# After building in Xcode, sign the app
codesign --force --deep --sign - /path/to/McFind.app

# Verify it worked
codesign --verify --verbose /path/to/McFind.app
```

**Current Status:** ✅ Implemented in CI/CD workflows (macos.yml and release.yml)

---

### Solution 2: Developer ID Signing (Recommended for Distribution)

**What it does:** Signs with an Apple Developer certificate. Works on all Macs.

**Requirements:**
- Apple Developer Program membership ($99/year)
- Developer ID Application certificate

**Steps:**

1. **Join Apple Developer Program**
   - Visit https://developer.apple.com/programs/
   - Enroll for $99/year

2. **Create Developer ID Certificate**
   - Log in to https://developer.apple.com/account/
   - Go to Certificates, Identifiers & Profiles
   - Click the "+" button to create a new certificate
   - Select "Developer ID Application"
   - Follow the prompts to generate and download the certificate
   - Double-click the certificate to install in Keychain

3. **Sign in Xcode**
   - Open `McFind.xcodeproj`
   - Select the project in the navigator
   - Go to **Signing & Capabilities** tab
   - Under "Team", select your developer account
   - Xcode will automatically sign future builds

4. **Manual Signing (if needed)**
   ```bash
   # Find your certificate identity
   security find-identity -v -p codesigning
   
   # Sign with your certificate
   codesign --force --deep --sign "Developer ID Application: Your Name (TEAMID)" McFind.app
   
   # Verify
   codesign --verify --verbose McFind.app
   spctl --assess --verbose McFind.app
   ```

5. **Notarization (Required for Distribution)**

   After signing, you must notarize with Apple:

   ```bash
   # Create a DMG
   hdiutil create -volname "McFind" -srcfolder McFind.app -ov -format UDZO McFind.dmg
   
   # Notarize
   xcrun notarytool submit McFind.dmg \
     --apple-id your@email.com \
     --password "app-specific-password" \
     --team-id TEAMID \
     --wait
   
   # Staple the notarization ticket
   xcrun stapler staple McFind.dmg
   ```

   **App-Specific Password:**
   - Generate at https://appleid.apple.com/account/manage
   - Use this instead of your actual Apple ID password

---

### Solution 3: Self-Signed Certificate (Free Alternative)

**What it does:** Creates a local certificate for signing. Works on your Mac only.

**Steps:**

1. **Create Certificate**
   - Open **Keychain Access**
   - Menu: Keychain Access → Certificate Assistant → Create a Certificate
   - Name: "McFind Self-Signed"
   - Identity Type: Self-Signed Root
   - Certificate Type: Code Signing
   - Check "Let me override defaults"
   - Click Continue through the steps
   - Set Keychain to "login"

2. **Sign with Self-Signed Certificate**
   ```bash
   codesign --force --deep --sign "McFind Self-Signed" McFind.app
   codesign --verify --verbose McFind.app
   ```

3. **Trust the Certificate**
   - Open Keychain Access
   - Find "McFind Self-Signed" certificate
   - Right-click → Get Info
   - Expand "Trust"
   - Set "Code Signing" to "Always Trust"

**Limitations:** Only works on your Mac. Other users must manually trust your certificate.

---

## For CI/CD (GitHub Actions)

### Current Setup (Ad-Hoc Signing)

The workflows already include ad-hoc signing:

```yaml
- name: Ad-hoc sign the app
  run: |
    BUILD_DIR=$(xcodebuild -project McFind.xcodeproj -scheme McFind -configuration Release -showBuildSettings | grep -m 1 "BUILD_DIR" | cut -d'=' -f2 | xargs)
    codesign --force --deep --sign - "$BUILD_DIR/Release/McFind.app"
```

### Upgrade to Developer ID Signing

To use your Developer ID in GitHub Actions:

1. **Export Certificate**
   ```bash
   # Export certificate and private key from Keychain
   # Save as McFind_Certificate.p12 with a password
   ```

2. **Add GitHub Secrets**
   - Go to Repository Settings → Secrets and Variables → Actions
   - Add secrets:
     - `MACOS_CERTIFICATE`: Base64-encoded .p12 file
     - `MACOS_CERTIFICATE_PASSWORD`: The password you set
     - `APPLE_ID`: Your Apple ID email
     - `APPLE_ID_PASSWORD`: App-specific password
     - `APPLE_TEAM_ID`: Your team ID

3. **Update Workflow**
   ```yaml
   - name: Import Certificate
     run: |
       echo "${{ secrets.MACOS_CERTIFICATE }}" | base64 --decode > certificate.p12
       security create-keychain -p temp_password build.keychain
       security default-keychain -s build.keychain
       security unlock-keychain -p temp_password build.keychain
       security import certificate.p12 -k build.keychain -P "${{ secrets.MACOS_CERTIFICATE_PASSWORD }}" -T /usr/bin/codesign
       security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k temp_password build.keychain

   - name: Sign with Developer ID
     run: |
       codesign --force --deep --sign "Developer ID Application: Your Name" McFind.app
   ```

---

## Quick Reference

### Check if App is Signed
```bash
codesign --display --verbose=4 McFind.app
```

### Verify Signature
```bash
codesign --verify --verbose McFind.app
```

### Check Gatekeeper Assessment
```bash
spctl --assess --verbose McFind.app
```

### Remove Quarantine (Bypass Warning Temporarily)
```bash
xattr -dr com.apple.quarantine McFind.app
```

---

## Troubleshooting

### "Code object is not signed at all"
```bash
# Sign it
codesign --force --deep --sign - McFind.app
```

### "The code signature is not valid"
```bash
# Re-sign
codesign --force --deep --sign - McFind.app
```

### "App is damaged and can't be opened"
```bash
# Remove quarantine attribute
xattr -cr McFind.app
```

### Users Still See Warning After Signing
- Ad-hoc signing only works on the build machine
- You need a Developer ID certificate for distribution
- See "Solution 2: Developer ID Signing" above

---

## Recommendations

**For personal use:** ✅ Current ad-hoc signing setup is sufficient

**For distribution to others:**
- Get an Apple Developer account
- Use Developer ID Application certificate
- Notarize the app with Apple
- Update CI/CD workflows to use the certificate

**For Mac App Store:**
- Use "Mac App Store" certificate type (not Developer ID)
- Follow App Store submission guidelines
- Enable sandboxing and required entitlements

---

## Resources

- [Apple Code Signing Guide](https://developer.apple.com/support/code-signing/)
- [Notarization Documentation](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- [Xcode Signing & Capabilities](https://developer.apple.com/documentation/xcode/adding-capabilities-to-your-app)

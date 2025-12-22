# Build Scripts

## Prerequisites

1. **Apple Developer Account** ($99/year)
   - Enroll at [developer.apple.com](https://developer.apple.com)

2. **Developer ID Application Certificate**
   - Open Xcode → Settings → Accounts → Manage Certificates
   - Click + → Developer ID Application

3. **Set your Team ID in Xcode**
   - Open `Clipsa.xcodeproj`
   - Select the Clipsa target → Signing & Capabilities
   - Select your team for Release configuration

4. **Store Notarization Credentials** (one-time)
   ```bash
   xcrun notarytool store-credentials "ClipsaNotary" \
     --apple-id "your@email.com" \
     --team-id "YOUR_TEAM_ID" \
     --password "app-specific-password"
   ```
   
   Get app-specific password at: [appleid.apple.com](https://appleid.apple.com) → Security → App-Specific Passwords

## Building

### Full Build (Signed + Notarized)

```bash
./scripts/build-dmg.sh
```

This will:
1. Build the app in Release mode
2. Sign with Developer ID
3. Create DMG
4. Submit for notarization (~2-10 min)
5. Staple the notarization ticket

Output: `dist/Clipsa-1.0.dmg`

### Quick Build (Signed, No Notarization)

```bash
./scripts/build-dmg.sh --skip-notarize
```

Faster for testing. Users will get a warning on first open.

### Unsigned Build (Testing Only)

```bash
./scripts/build-dmg.sh --unsigned
```

For local testing. Cannot be distributed.

### Styled DMG (Custom Layout)

After building:

```bash
./scripts/create-styled-dmg.sh
```

Creates a DMG with nicer icon positioning.

## Troubleshooting

### "Developer ID Application" certificate not found

Make sure you:
1. Have an Apple Developer account
2. Created the certificate in Xcode
3. Set the Team ID in project settings

### Notarization fails

Check the logs:
```bash
xcrun notarytool log <submission-id> --keychain-profile "ClipsaNotary"
```

Common issues:
- Hardened Runtime not enabled
- Missing entitlements
- Unsigned frameworks/libraries

### "The application is damaged" when opening

The DMG wasn't notarized or the notarization ticket wasn't stapled.
Run the full build with notarization.


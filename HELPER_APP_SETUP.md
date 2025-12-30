# GramfixHelper App Setup Instructions

This document provides step-by-step instructions for setting up the helper app target in Xcode to enable "Launch at Login" functionality.

## Overview

The helper app (`GramfixHelper`) is a minimal app that launches the main Gramfix app when the system starts. It's bundled inside the main app and managed by the Service Management framework.

## Step 1: Create Helper App Target

1. Open `Gramfix.xcodeproj` in Xcode
2. Go to **File > New > Target...**
3. Select **macOS** tab
4. Choose **App** template
5. Click **Next**
6. Configure the target:
   - **Product Name**: `GramfixHelper`
   - **Bundle Identifier**: `com.gramfix.app.helper`
   - **Language**: Swift
   - **Interface**: SwiftUI
   - **Storage**: None (uncheck all options)
7. Click **Finish**
8. Xcode will ask to activate the scheme - click **Activate**

## Step 2: Configure Helper App Settings

1. Select the **GramfixHelper** target in the project navigator
2. Go to **General** tab:
   - Set **Deployment Target** to match main app (macOS 26.0)
   - Set **Display Name** to `GramfixHelper` (or leave empty)
3. Go to **Signing & Capabilities** tab:
   - Use the same **Team** as the main app
   - **Code Signing Style**: Automatic (or match main app)
   - **Do NOT enable App Sandbox** (or use minimal entitlements if needed)

## Step 3: Add Helper App Source File

1. The helper app source file is already created at: `GramfixHelper/GramfixHelperApp.swift`
2. In Xcode, right-click the **GramfixHelper** target folder
3. Select **Add Files to "Gramfix"...**
4. Navigate to and select `GramfixHelper/GramfixHelperApp.swift`
5. Make sure **GramfixHelper** target is checked (not the main app target)
6. Click **Add**

## Step 4: Embed Helper App in Main App

1. Select the **Gramfix** (main app) target
2. Go to **Build Phases** tab
3. Expand **Copy Files** phase (if it doesn't exist, click **+** and add "New Copy Files Phase")
4. Configure the Copy Files phase:
   - **Destination**: Wrapper
   - **Subpath**: (leave empty)
   - **Code Sign On Copy**: ✅ (checked)
5. Click **+** to add files
6. Select `GramfixHelper.app` from the list (it should appear after building the helper target)
7. If the file doesn't appear:
   - Build the **GramfixHelper** target first (Product > Build)
   - Then add `GramfixHelper.app` from `$(BUILT_PRODUCTS_DIR)/GramfixHelper.app`

## Step 5: Configure Helper App Info.plist (Optional)

The helper app should have minimal configuration. If Xcode generated an Info.plist:

1. Select **GramfixHelper** target
2. Go to **Info** tab
3. Set **Application Category**: `public.app-category.utilities`
4. Add key **LSUIElement** with value `YES` (to hide from Dock)

Alternatively, create `GramfixHelper/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>LSUIElement</key>
    <true/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
</dict>
</plist>
```

Then set **Info.plist File** in target settings to `GramfixHelper/Info.plist`.

## Step 6: Build and Test

1. Build the project (⌘B)
2. Run the main app (⌘R)
3. Open Settings (⌘,)
4. Find the **Startup** section
5. Toggle **Launch at login** on
6. Verify in **System Settings > Users & Groups > Login Items** that `GramfixHelper` appears
7. Restart your Mac or log out/in to test

## Troubleshooting

### Helper app doesn't launch main app
- Verify bundle ID is exactly `com.gramfix.app.helper`
- Check that helper app is embedded in main app bundle
- Check Console.app for error messages from GramfixHelper

### Login item doesn't appear in System Settings
- Verify `SMAppService` registration succeeded (check logs)
- Try disabling and re-enabling the toggle
- Check that helper app bundle ID matches in `LoginItemManager.swift`

### Build errors
- Ensure helper app target is added to the project
- Verify source file is added to helper target (not main target)
- Check that deployment targets match

## Verification

After setup, you should have:
- ✅ `GramfixHelper` target in Xcode
- ✅ `GramfixHelper/GramfixHelperApp.swift` file added to helper target
- ✅ Helper app embedded in main app's Copy Files phase
- ✅ Bundle ID: `com.gramfix.app.helper`
- ✅ Toggle works in Settings
- ✅ Login item appears in System Settings



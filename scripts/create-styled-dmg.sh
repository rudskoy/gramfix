#!/bin/bash
set -e

# ============================================================================
# Create a Styled DMG with custom window layout
# ============================================================================
# This script creates a prettier DMG with:
# - Custom window size
# - Icon positions (app on left, Applications alias on right)
# - Hidden toolbar and sidebar
#
# Run after build-dmg.sh --unsigned for testing the layout
# ============================================================================

APP_NAME="Gramfix"
VERSION="1.0"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${PROJECT_DIR}/build"
DIST_DIR="${PROJECT_DIR}/dist"
SCRIPTS_DIR="${PROJECT_DIR}/scripts"
APP_PATH="${BUILD_DIR}/Release/${APP_NAME}.app"

DMG_TEMP="${BUILD_DIR}/${APP_NAME}-temp.dmg"
DMG_FINAL="${DIST_DIR}/${APP_NAME}-${VERSION}.dmg"
VOLUME_NAME="${APP_NAME}"
DMG_SIZE="100m"

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
NC='\033[0m'

log() { echo -e "${BLUE}[DMG]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }

# Check if app exists
if [ ! -d "${APP_PATH}" ]; then
    echo "Error: ${APP_PATH} not found. Run build-dmg.sh first."
    exit 1
fi

# Ensure the app has the icns icon (for compatibility with non-Tahoe systems)
ICNS_PATH="${SCRIPTS_DIR}/Gramfix.icns"
if [ -f "${ICNS_PATH}" ]; then
    log "Copying app icon to bundle..."
    cp "${ICNS_PATH}" "${APP_PATH}/Contents/Resources/AppIcon.icns"
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string 'AppIcon'" "${APP_PATH}/Contents/Info.plist" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile 'AppIcon'" "${APP_PATH}/Contents/Info.plist"
    touch "${APP_PATH}"
fi

# Clean up
rm -f "${DMG_TEMP}" "${DMG_FINAL}"
mkdir -p "${DIST_DIR}"

# Create a temporary DMG
log "Creating temporary DMG..."
hdiutil create -srcfolder "${APP_PATH}" -volname "${VOLUME_NAME}" -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" -format UDRW -size ${DMG_SIZE} "${DMG_TEMP}"

# Mount it
log "Mounting DMG..."
DEVICE=$(hdiutil attach -readwrite -noverify -noautoopen "${DMG_TEMP}" | \
    egrep '^/dev/' | sed 1q | awk '{print $1}')
MOUNT_POINT="/Volumes/${VOLUME_NAME}"

# Wait for mount
sleep 2

# Add Applications symlink
log "Adding Applications symlink..."
ln -s /Applications "${MOUNT_POINT}/Applications"

# Set window appearance using AppleScript
log "Styling DMG window..."
osascript <<EOF
tell application "Finder"
    tell disk "${VOLUME_NAME}"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {100, 100, 640, 400}
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 80
        set position of item "${APP_NAME}.app" of container window to {130, 150}
        set position of item "Applications" of container window to {410, 150}
        close
        open
        update without registering applications
        delay 2
    end tell
end tell
EOF

# Hide hidden files
SetFile -a V "${MOUNT_POINT}/.fseventsd" 2>/dev/null || true
SetFile -a V "${MOUNT_POINT}/.Trashes" 2>/dev/null || true

# Sync and unmount
log "Finalizing..."
sync
hdiutil detach "${DEVICE}"

# Convert to compressed DMG
log "Compressing DMG..."
hdiutil convert "${DMG_TEMP}" -format UDZO -imagekey zlib-level=9 -o "${DMG_FINAL}"

# Clean up temp DMG
rm -f "${DMG_TEMP}"

success "Styled DMG created: ${DMG_FINAL}"
echo "  Size: $(du -h "${DMG_FINAL}" | cut -f1)"

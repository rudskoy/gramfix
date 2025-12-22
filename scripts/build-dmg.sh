#!/bin/bash
set -e

# ============================================================================
# Clipsa DMG Build Script
# ============================================================================
# 
# Prerequisites:
# 1. Apple Developer Account with Developer ID Application certificate
# 2. Store notarization credentials (one-time):
#    xcrun notarytool store-credentials "ClipsaNotary" \
#      --apple-id "your@email.com" \
#      --team-id "YOURTEAMID" \
#      --password "app-specific-password"
#
# Usage:
#   ./scripts/build-dmg.sh           # Build, sign, notarize
#   ./scripts/build-dmg.sh --skip-notarize  # Build and sign only
#   ./scripts/build-dmg.sh --unsigned       # Build unsigned (for testing)
#
# ============================================================================

# Configuration
APP_NAME="Clipsa"
BUNDLE_ID="com.clipsa.app"
VERSION=$(grep -A1 'MARKETING_VERSION' Clipsa.xcodeproj/project.pbxproj | head -1 | grep -o '[0-9.]*' | head -1)
VERSION=${VERSION:-1.0}

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${PROJECT_DIR}/build"
DIST_DIR="${PROJECT_DIR}/dist"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
APP_PATH="${BUILD_DIR}/Release/${APP_NAME}.app"

# Notarization profile name (set up with xcrun notarytool store-credentials)
NOTARY_PROFILE="ClipsaNotary"

# Parse arguments
SKIP_NOTARIZE=false
UNSIGNED=false
for arg in "$@"; do
    case $arg in
        --skip-notarize) SKIP_NOTARIZE=true ;;
        --unsigned) UNSIGNED=true ;;
    esac
done

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() { echo -e "${BLUE}[BUILD]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }

# ============================================================================
# Step 1: Clean and Build
# ============================================================================
log "Building ${APP_NAME} v${VERSION}..."

cd "${PROJECT_DIR}"

# Clean previous builds
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}" "${DIST_DIR}"

# Build the app
if [ "$UNSIGNED" = true ]; then
    log "Building unsigned (for testing only)..."
    xcodebuild -project Clipsa.xcodeproj \
        -scheme Clipsa \
        -configuration Release \
        -derivedDataPath "${BUILD_DIR}/DerivedData" \
        CODE_SIGN_IDENTITY="-" \
        CODE_SIGNING_REQUIRED=NO \
        ONLY_ACTIVE_ARCH=NO \
        build
else
    log "Building with Developer ID signing..."
    xcodebuild -project Clipsa.xcodeproj \
        -scheme Clipsa \
        -configuration Release \
        -derivedDataPath "${BUILD_DIR}/DerivedData" \
        ONLY_ACTIVE_ARCH=NO \
        build
fi

# Copy the app to a consistent location
mkdir -p "${BUILD_DIR}/Release"
cp -R "${BUILD_DIR}/DerivedData/Build/Products/Release/${APP_NAME}.app" "${BUILD_DIR}/Release/"

APP_PATH="${BUILD_DIR}/Release/${APP_NAME}.app"

if [ ! -d "${APP_PATH}" ]; then
    error "Build failed - ${APP_NAME}.app not found"
fi

success "Build complete"

# ============================================================================
# Step 2: Verify Code Signature
# ============================================================================
if [ "$UNSIGNED" = false ]; then
    log "Verifying code signature..."
    codesign --verify --deep --strict "${APP_PATH}" 2>&1 || warn "Code signature verification had issues"
    codesign -dv --verbose=4 "${APP_PATH}" 2>&1 | head -10
    success "Code signature verified"
fi

# ============================================================================
# Step 3: Create DMG
# ============================================================================
log "Creating DMG..."

DMG_TEMP="${BUILD_DIR}/temp.dmg"
DMG_FINAL="${DIST_DIR}/${DMG_NAME}"
DMG_STAGING="${BUILD_DIR}/dmg-staging"

# Clean up any previous DMG
rm -f "${DMG_FINAL}" "${DMG_TEMP}"
rm -rf "${DMG_STAGING}"

# Create staging directory
mkdir -p "${DMG_STAGING}"
cp -R "${APP_PATH}" "${DMG_STAGING}/"

# Create Applications symlink
ln -s /Applications "${DMG_STAGING}/Applications"

# Create the DMG
hdiutil create -volname "${APP_NAME}" \
    -srcfolder "${DMG_STAGING}" \
    -ov -format UDZO \
    "${DMG_FINAL}"

# Clean up staging
rm -rf "${DMG_STAGING}"

if [ ! -f "${DMG_FINAL}" ]; then
    error "DMG creation failed"
fi

success "DMG created: ${DMG_FINAL}"

# ============================================================================
# Step 4: Notarize (if not skipped)
# ============================================================================
if [ "$UNSIGNED" = false ] && [ "$SKIP_NOTARIZE" = false ]; then
    log "Submitting for notarization..."
    log "This may take a few minutes..."
    
    # Check if credentials are stored
    if ! xcrun notarytool history --keychain-profile "${NOTARY_PROFILE}" > /dev/null 2>&1; then
        warn "Notarization credentials not found."
        warn "Set up credentials with:"
        echo ""
        echo "  xcrun notarytool store-credentials \"${NOTARY_PROFILE}\" \\"
        echo "    --apple-id \"your@email.com\" \\"
        echo "    --team-id \"YOURTEAMID\" \\"
        echo "    --password \"app-specific-password\""
        echo ""
        warn "Skipping notarization. DMG is signed but not notarized."
    else
        # Submit for notarization
        xcrun notarytool submit "${DMG_FINAL}" \
            --keychain-profile "${NOTARY_PROFILE}" \
            --wait
        
        # Staple the ticket
        log "Stapling notarization ticket..."
        xcrun stapler staple "${DMG_FINAL}"
        
        success "Notarization complete!"
    fi
elif [ "$SKIP_NOTARIZE" = true ]; then
    warn "Notarization skipped (--skip-notarize flag)"
fi

# ============================================================================
# Done!
# ============================================================================
echo ""
success "=========================================="
success "Build complete!"
success "=========================================="
echo ""
echo "  DMG: ${DMG_FINAL}"
echo "  Size: $(du -h "${DMG_FINAL}" | cut -f1)"
echo ""

if [ "$UNSIGNED" = true ]; then
    warn "This is an UNSIGNED build for testing only."
    warn "Users will see a security warning when opening."
fi


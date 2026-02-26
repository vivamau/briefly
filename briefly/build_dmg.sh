#!/bin/bash
set -euo pipefail

# ============================================================
# Briefly — Build & Package as DMG for Free Distribution
# ============================================================
# This script builds the macOS app and packages it into a DMG
# file suitable for free distribution (without the App Store).
#
# Prerequisites:
#   1. Xcode must be installed
#   2. xcode-select must point to Xcode.app:
#      sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
#
# Usage:
#   chmod +x build_dmg.sh
#   ./build_dmg.sh
# ============================================================

APP_NAME="briefly"
SCHEME="briefly"
PROJECT="briefly.xcodeproj"
CONFIGURATION="Release"
ARCHIVE_PATH="./build/${APP_NAME}.xcarchive"
EXPORT_PATH="./build/export"
DMG_OUTPUT="./build/${APP_NAME}.dmg"
DMG_VOLUME_NAME="Briefly"
DMG_TEMP="./build/dmg_staging"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_step() {
    echo -e "\n${BLUE}▶ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# -----------------------------------------------------------
# Step 0: Verify environment
# -----------------------------------------------------------
print_step "Verifying build environment..."

# Check xcode-select points to Xcode.app
DEVELOPER_DIR=$(xcode-select -p 2>/dev/null || true)
if [[ "$DEVELOPER_DIR" != *"Xcode.app"* ]]; then
    print_error "xcode-select is not pointing to Xcode.app"
    echo "Current: $DEVELOPER_DIR"
    echo ""
    echo "Fix this by running:"
    echo "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
    exit 1
fi

XCODE_VERSION=$(xcodebuild -version | head -1)
print_success "Using $XCODE_VERSION"

# -----------------------------------------------------------
# Step 1: Clean previous builds
# -----------------------------------------------------------
print_step "Cleaning previous builds..."
rm -rf ./build
mkdir -p ./build
print_success "Build directory cleaned"

# -----------------------------------------------------------
# Step 2: Build and archive the app for macOS
# -----------------------------------------------------------
print_step "Building and archiving ${APP_NAME} for macOS..."

xcodebuild archive \
    -project "${PROJECT}" \
    -scheme "${SCHEME}" \
    -configuration "${CONFIGURATION}" \
    -destination "generic/platform=macOS" \
    -archivePath "${ARCHIVE_PATH}" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=YES \
    CODE_SIGNING_ALLOWED=YES \
    DEVELOPMENT_TEAM="" \
    ENABLE_APP_SANDBOX=YES \
    ENABLE_HARDENED_RUNTIME=YES \
    2>&1 | tail -20

if [ ! -d "${ARCHIVE_PATH}" ]; then
    print_error "Archive failed! Check the build output above."
    exit 1
fi
print_success "Archive created at ${ARCHIVE_PATH}"

# -----------------------------------------------------------
# Step 3: Export the app from the archive
# -----------------------------------------------------------
print_step "Exporting app from archive..."

# Create the export options plist for ad-hoc distribution
cat > ./build/ExportOptions.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>mac-application</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>signingCertificate</key>
    <string>-</string>
    <key>stripSwiftSymbols</key>
    <true/>
</dict>
</plist>
EOF

# Try to export using xcodebuild, but if it fails (common with ad-hoc),
# fall back to extracting directly from the archive
xcodebuild -exportArchive \
    -archivePath "${ARCHIVE_PATH}" \
    -exportOptionsPlist ./build/ExportOptions.plist \
    -exportPath "${EXPORT_PATH}" \
    2>&1 | tail -10 || {
    print_warning "Standard export failed, extracting app directly from archive..."
    mkdir -p "${EXPORT_PATH}"
    cp -R "${ARCHIVE_PATH}/Products/Applications/${APP_NAME}.app" "${EXPORT_PATH}/${APP_NAME}.app"
}

APP_PATH="${EXPORT_PATH}/${APP_NAME}.app"

if [ ! -d "${APP_PATH}" ]; then
    # Try alternate location within archive
    APP_FOUND=$(find "${ARCHIVE_PATH}" -name "*.app" -type d | head -1)
    if [ -n "$APP_FOUND" ]; then
        mkdir -p "${EXPORT_PATH}"
        cp -R "$APP_FOUND" "${APP_PATH}"
    else
        print_error "Could not find the built .app bundle!"
        exit 1
    fi
fi

print_success "App exported to ${APP_PATH}"

# -----------------------------------------------------------
# Step 4: Ad-hoc code sign the app
# -----------------------------------------------------------
print_step "Code signing app with ad-hoc signature..."

# Sign all frameworks and dylibs first, then the app itself
find "${APP_PATH}" -name "*.dylib" -o -name "*.framework" | while read -r item; do
    codesign --force --deep --sign - "$item" 2>/dev/null || true
done

codesign --force --deep --sign - \
    --entitlements "briefly.entitlements" \
    "${APP_PATH}"

codesign --verify --deep --strict "${APP_PATH}" 2>&1 && \
    print_success "Code signing verified" || \
    print_warning "Code signing verification had warnings (app may still work)"

# -----------------------------------------------------------
# Step 5: Create the DMG
# -----------------------------------------------------------
print_step "Creating DMG installer..."

# Set up the staging directory with the app and an Applications symlink
rm -rf "${DMG_TEMP}"
mkdir -p "${DMG_TEMP}"
cp -R "${APP_PATH}" "${DMG_TEMP}/"
ln -s /Applications "${DMG_TEMP}/Applications"

# Calculate the size needed (app size + 20MB buffer)
APP_SIZE_KB=$(du -sk "${DMG_TEMP}" | cut -f1)
DMG_SIZE_KB=$((APP_SIZE_KB + 20480))

# Create a temporary DMG
hdiutil create \
    -srcfolder "${DMG_TEMP}" \
    -volname "${DMG_VOLUME_NAME}" \
    -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" \
    -format UDRW \
    -size ${DMG_SIZE_KB}k \
    "./build/${APP_NAME}_temp.dmg"

# Mount the temporary DMG
MOUNT_OUTPUT=$(hdiutil attach -readwrite -noverify -noautoopen "./build/${APP_NAME}_temp.dmg")
DEVICE=$(echo "${MOUNT_OUTPUT}" | grep "Apple_HFS" | awk '{print $1}')
MOUNT_POINT="/Volumes/${DMG_VOLUME_NAME}"

# Set up the DMG window appearance using AppleScript
# This creates a nice drag-to-install experience
echo '
   tell application "Finder"
     tell disk "'${DMG_VOLUME_NAME}'"
           open
           set current view of container window to icon view
           set toolbar visible of container window to false
           set statusbar visible of container window to false
           set the bounds of container window to {400, 100, 920, 440}
           set theViewOptions to the icon view options of container window
           set arrangement of theViewOptions to not arranged
           set icon size of theViewOptions to 80
           set position of item "'${APP_NAME}'.app" of container window to {130, 160}
           set position of item "Applications" of container window to {390, 160}
           close
           open
           update without registering applications
           delay 2
     end tell
   end tell
' | osascript 2>/dev/null || print_warning "Could not customize DMG window layout (this is cosmetic only)"

# Set the DMG background to white
sync

# Unmount the temporary DMG
hdiutil detach "${DEVICE}" -quiet || hdiutil detach "${DEVICE}" -force

# Convert to compressed, read-only DMG
rm -f "${DMG_OUTPUT}"
hdiutil convert \
    "./build/${APP_NAME}_temp.dmg" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "${DMG_OUTPUT}"

# Clean up
rm -f "./build/${APP_NAME}_temp.dmg"
rm -rf "${DMG_TEMP}"

# -----------------------------------------------------------
# Step 6: Verify and report
# -----------------------------------------------------------
print_step "Build complete!"

DMG_SIZE=$(du -sh "${DMG_OUTPUT}" | cut -f1)
DMG_FULL_PATH=$(cd "$(dirname "${DMG_OUTPUT}")" && pwd)/$(basename "${DMG_OUTPUT}")

echo ""
echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  DMG created successfully!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  📦 File:     ${DMG_FULL_PATH}"
echo -e "  📏 Size:     ${DMG_SIZE}"
echo ""
echo -e "  ${YELLOW}Distribution Notes:${NC}"
echo -e "  • This DMG is ad-hoc signed (no Apple Developer account)"
echo -e "  • Recipients will need to right-click → Open on first launch"
echo -e "  • macOS Gatekeeper may show an 'unidentified developer' warning"
echo -e "  • To bypass: System Settings → Privacy & Security → Open Anyway"
echo ""
echo -e "  To notarize (removes Gatekeeper warnings), you'd need an"
echo -e "  Apple Developer account (\$99/year)."
echo ""

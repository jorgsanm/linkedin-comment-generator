#!/bin/bash
set -euo pipefail

SIGNING_IDENTITY="LinkedIn Assistant Dev"
ENTITLEMENTS_FILE="$(dirname "$0")/LinkedInCommentAssistant.entitlements"
BINARY=".build/debug/LinkedInCommentAssistant"
APP_NAME="LKD Comments"
APP_DIR="/Applications/${APP_NAME}.app"

echo "Building…"
swift build

echo "Installing to ${APP_DIR}…"
# Kill running instance
pkill -f "${APP_NAME}" 2>/dev/null || true
sleep 0.3

# Create .app bundle
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

cp "${BINARY}" "${APP_DIR}/Contents/MacOS/${APP_NAME}"

# Copy resources
if [ -d ".build/debug/LinkedInCommentAssistant_LinkedInCommentAssistant.bundle" ]; then
    cp -R ".build/debug/LinkedInCommentAssistant_LinkedInCommentAssistant.bundle" "${APP_DIR}/Contents/Resources/"
fi
cp "Sources/LinkedInCommentAssistant/Resources/AppIcon.icns" "${APP_DIR}/Contents/Resources/AppIcon.icns"

cat > "${APP_DIR}/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>LKD Comments</string>
    <key>CFBundleDisplayName</key>
    <string>LKD Comments</string>
    <key>CFBundleIdentifier</key>
    <string>com.jorgesingular.lkd-comments</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleExecutable</key>
    <string>LKD Comments</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

echo "Signing with identity: ${SIGNING_IDENTITY}"
codesign --force --deep --sign "${SIGNING_IDENTITY}" --entitlements "${ENTITLEMENTS_FILE}" "${APP_DIR}"

echo "Verifying signature…"
codesign -dvv "${APP_DIR}" 2>&1 | grep "Authority="

echo "Done. Open with: open '${APP_DIR}'"

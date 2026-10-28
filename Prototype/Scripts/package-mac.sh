#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="ChatMemory"
BUNDLE_ID="com.rainnn.chatmemory.prototype.mac"
VERSION="0.7.0"
BUILD_NUMBER="1"
DIST_DIR="${ROOT}/dist"
APP_DIR="${DIST_DIR}/${APP_NAME}.app"
ICONSET_DIR="${DIST_DIR}/AppIcon.iconset"
DMG_STAGING_DIR="${DIST_DIR}/dmg-root"

cd "${ROOT}"

echo "▸ Building release app"
swift build -c release --product ChatMemoryPrototypeApp

echo "▸ Generating app icon"
rm -rf "${DIST_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS" "${APP_DIR}/Contents/Resources" "${ICONSET_DIR}"
swift run -c release MacIconGenerator "${ICONSET_DIR}/icon-master.png"

for size in 16 32 128 256 512; do
    sips -z "${size}" "${size}" "${ICONSET_DIR}/icon-master.png" --out "${ICONSET_DIR}/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z "${double}" "${double}" "${ICONSET_DIR}/icon-master.png" --out "${ICONSET_DIR}/icon_${size}x${size}@2x.png" >/dev/null
done

iconutil -c icns "${ICONSET_DIR}" -o "${APP_DIR}/Contents/Resources/AppIcon.icns"
cp "${ROOT}/Resources/macOS/Info.plist" "${APP_DIR}/Contents/Info.plist"
cp "${ROOT}/.build/release/ChatMemoryPrototypeApp" "${APP_DIR}/Contents/MacOS/${APP_NAME}"
chmod +x "${APP_DIR}/Contents/MacOS/${APP_NAME}"

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" "${APP_DIR}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${BUILD_NUMBER}" "${APP_DIR}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier ${BUNDLE_ID}" "${APP_DIR}/Contents/Info.plist"

echo "▸ Applying ad-hoc code signature"
codesign --force --options runtime --sign - "${APP_DIR}"
codesign --verify --strict "${APP_DIR}"

echo "▸ Creating ZIP"
ditto -c -k --keepParent "${APP_DIR}" "${DIST_DIR}/${APP_NAME}-${VERSION}-macOS.zip"

echo "▸ Creating DMG"
rm -rf "${DMG_STAGING_DIR}"
mkdir -p "${DMG_STAGING_DIR}"
cp -R "${APP_DIR}" "${DMG_STAGING_DIR}/${APP_NAME}.app"
ln -s /Applications "${DMG_STAGING_DIR}/Applications"
hdiutil create \
    -volname "${APP_NAME}" \
    -srcfolder "${DMG_STAGING_DIR}" \
    -ov \
    -format UDZO \
    "${DIST_DIR}/${APP_NAME}-${VERSION}-macOS.dmg"

shasum -a 256 "${DIST_DIR}/${APP_NAME}-${VERSION}-macOS.dmg" > "${DIST_DIR}/${APP_NAME}-${VERSION}-macOS.dmg.sha256"

echo "✅ Packaged:"
echo "   ${DIST_DIR}/${APP_NAME}-${VERSION}-macOS.zip"
echo "   ${DIST_DIR}/${APP_NAME}-${VERSION}-macOS.dmg"
echo "   ${DIST_DIR}/${APP_NAME}-${VERSION}-macOS.dmg.sha256"


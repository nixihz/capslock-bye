#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$PROJECT_ROOT/dist/release"
APP_BUNDLE="$DIST_DIR/CapsLock Bye.app"
if [ ! -d "$APP_BUNDLE" ]; then
    echo "Run task release first, or use task dmg to build and package." >&2
    exit 1
fi

codesign --verify --strict --verbose=2 "$APP_BUNDLE"
lipo "$APP_BUNDLE/Contents/MacOS/CapsBye" -verify_arch arm64 x86_64
SIGN_IDENTITY="$(codesign -dv --verbose=4 "$APP_BUNDLE" 2>&1 | sed -n 's/^Authority=\(Developer ID Application:.*\)/\1/p')"
if [ -z "$SIGN_IDENTITY" ]; then
    echo "The release app must be signed with Developer ID Application." >&2
    exit 1
fi
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_BUNDLE/Contents/Info.plist")"
DMG_NAME="CapsLock-Bye-$VERSION-universal.dmg"
STAGING_DIR="$(mktemp -d "$DIST_DIR/.dmg-staging.XXXXXX")"
trap 'rm -rf "$STAGING_DIR"' EXIT
mkdir "$STAGING_DIR/contents"
ditto "$APP_BUNDLE" "$STAGING_DIR/contents/CapsLock Bye.app"
ln -s /Applications "$STAGING_DIR/contents/Applications"

hdiutil create -volname "CapsLock Bye" -srcfolder "$STAGING_DIR/contents" \
    -format UDZO -fs HFS+ "$STAGING_DIR/$DMG_NAME"
codesign --sign "${CAPSBYE_SIGN_IDENTITY:-$SIGN_IDENTITY}" --timestamp "$STAGING_DIR/$DMG_NAME"
codesign --verify --strict --verbose=2 "$STAGING_DIR/$DMG_NAME"
hdiutil verify "$STAGING_DIR/$DMG_NAME"
mv -f "$STAGING_DIR/$DMG_NAME" "$DIST_DIR/$DMG_NAME"
cd "$DIST_DIR"
shasum -a 256 "$DMG_NAME" > "$DMG_NAME.sha256"
echo "Signed DMG prepared; run task notarize before distribution: $DIST_DIR/$DMG_NAME"

#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
case "$MODE" in run|--build-only|--ci|--release|--verify|--debug|--logs|--telemetry) ;; *) echo "Usage: $0 [--build-only|--ci|--release|--verify|--debug|--logs|--telemetry]" >&2; exit 2 ;; esac
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"
DIST_DIR="$PROJECT_ROOT/dist"
BUILD_ARGS=(--configuration debug)
if [ "$MODE" = --release ] || [ "$MODE" = --ci ]; then
    DIST_DIR="$DIST_DIR/${MODE#--}"
    BUILD_ARGS=(--configuration release --arch arm64 --arch x86_64)
fi
APP_BUNDLE="$DIST_DIR/CapsLock Bye.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/CapsBye"
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' Resources/Info.plist)"

# Prefer Developer ID for a stable application signature, then Apple Development.
# CI always uses ad-hoc signing and needs no certificates or secrets.
# For local builds, an explicit identity (including '-') wins.
SIGN_IDENTITY="${CAPSBYE_SIGN_IDENTITY:-}"
if [ "$MODE" = --ci ]; then
    SIGN_IDENTITY="-"
elif [ -z "$SIGN_IDENTITY" ]; then
    SIGN_IDENTITY="$(security find-identity -v -p codesigning | awk '
        /"Developer ID Application:/ && !developer_id { developer_id = $2 }
        /"Apple Development:/ && !development { development = $2 }
        END { print developer_id ? developer_id : development }
    ')"
fi
if [ -z "$SIGN_IDENTITY" ]; then
    SIGN_IDENTITY="-"
    echo "No developer signing identity found; using ad-hoc signing for local development."
fi
if [ "$MODE" = --release ]; then
    if ! security find-identity -v -p codesigning | awk -v identity="$SIGN_IDENTITY" '
        /"Developer ID Application:/ {
            name = $0; sub(/^[^"]*"/, "", name); sub(/".*$/, "", name)
            if ($2 == identity || name == identity) found = 1
        }
        END { exit !found }
    '; then
        echo "Release builds require a Developer ID Application certificate (full name or SHA-1)." >&2
        exit 1
    fi
fi

# Only stop the copy built from this checkout, using normal app termination so
# any held modifiers are released. Do not kill another installed copy.
if pgrep -f "^$APP_BINARY" >/dev/null; then
    # The app handles SIGTERM on its main queue and releases held modifiers.
    # This does not depend on Apple Events permissions or keyboard focus.
    pkill -TERM -f "^$APP_BINARY$" || true
    for ((attempt = 0; attempt < 30; attempt++)); do
        if ! pgrep -f "^$APP_BINARY" >/dev/null; then break; fi
        sleep 0.1
    done
    if pgrep -f "^$APP_BINARY" >/dev/null; then
        echo "CapsLock Bye did not quit. Close it before rebuilding." >&2
        exit 1
    fi
fi

swift build "${BUILD_ARGS[@]}" --product CapsBye
BUILD_BINARY="$(swift build "${BUILD_ARGS[@]}" --show-bin-path)/CapsBye"
if [ "$MODE" = --release ] || [ "$MODE" = --ci ]; then
    lipo "$BUILD_BINARY" -verify_arch arm64 x86_64
fi
if [ ! -f Resources/AppIcon.icns ] || [ Resources/AppIconSource.png -nt Resources/AppIcon.icns ] || [ script/generate_icon.swift -nt Resources/AppIcon.icns ]; then
    swift script/generate_icon.swift
fi
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
cp "$BUILD_BINARY" "$APP_BINARY"
cp Resources/Info.plist "$APP_BUNDLE/Contents/Info.plist"
if [ -f Resources/AppIcon.icns ]; then cp Resources/AppIcon.icns "$APP_BUNDLE/Contents/Resources/"; fi
for localization in Resources/*.lproj; do cp -R "$localization" "$APP_BUNDLE/Contents/Resources/"; done
chmod +x "$APP_BINARY"
if [ "$MODE" = --release ]; then
    codesign --force --sign "$SIGN_IDENTITY" --identifier "$BUNDLE_ID" --options runtime --timestamp "$APP_BUNDLE"
else
    codesign --force --sign "$SIGN_IDENTITY" --identifier "$BUNDLE_ID" "$APP_BUNDLE"
fi
codesign --verify --strict --verbose=2 "$APP_BUNDLE"

case "$MODE" in
    --ci)
        VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_BUNDLE/Contents/Info.plist")"
        ARCHIVE="CapsLock-Bye-$VERSION-universal-adhoc.zip"
        ditto -c -k --keepParent "$APP_BUNDLE" "$DIST_DIR/$ARCHIVE"
        (cd "$DIST_DIR" && shasum -a 256 "$ARCHIVE" > "$ARCHIVE.sha256")
        echo "CI build (ad-hoc signed, not notarized): $DIST_DIR/$ARCHIVE"
        ;;
    --release)
        echo "$APP_BUNDLE"
        echo "Release app prepared. Run task notarize to package and notarize the DMG."
        ;;
    --build-only) echo "$APP_BUNDLE" ;;
    --debug) lldb -- "$APP_BINARY" ;;
    --logs) open -n "$APP_BUNDLE"; /usr/bin/log stream --info --style compact --predicate 'process == "CapsBye"' ;;
    --telemetry) open -n "$APP_BUNDLE"; /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\"" ;;
    --verify) open -n "$APP_BUNDLE"; sleep 1; pgrep -x CapsBye >/dev/null; echo "CapsLock Bye is running." ;;
    run) open -n "$APP_BUNDLE" ;;
esac

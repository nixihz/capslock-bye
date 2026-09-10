#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-submit}"
case "$MODE" in submit|--resume) ;; *) echo "Usage: $0 [--resume]" >&2; exit 2 ;; esac
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT/dist/release" || { echo "Run task release first." >&2; exit 1; }
APP_BUNDLE="$PWD/CapsLock Bye.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_BUNDLE/Contents/Info.plist")"
ARCHIVE="CapsLock-Bye-$VERSION-universal.dmg"
NOTARIZED_ARCHIVE="CapsLock-Bye-$VERSION-universal-notarized.dmg"
# Separate DMG state from any older ZIP submission in this checkout.
STATE_PREFIX="notarization-dmg"
PROFILE="${CAPSBYE_NOTARY_PROFILE:-capsbye-notary}"
NOTARY_ARGS=(--keychain-profile "$PROFILE")
if [ -n "${CAPSBYE_NOTARY_KEYCHAIN:-}" ]; then
    NOTARY_ARGS+=(--keychain "$CAPSBYE_NOTARY_KEYCHAIN")
fi

codesign --verify --strict --verbose=2 "$APP_BUNDLE"
if [ "$MODE" = submit ]; then
    # Check credentials before building and uploading. Passwords stay in the Keychain.
    xcrun notarytool history "${NOTARY_ARGS[@]}" --output-format json >/dev/null
    "$PROJECT_ROOT/script/build_dmg.sh"
    shasum -a 256 "$ARCHIVE" > "$STATE_PREFIX-upload.sha256"
    shasum -a 256 "$APP_BUNDLE/Contents/MacOS/CapsBye" > "$STATE_PREFIX-app.sha256"
    xcrun notarytool submit "$ARCHIVE" "${NOTARY_ARGS[@]}" --no-wait --output-format json > "$STATE_PREFIX-submission.json"
fi

SUBMISSION_ID="$(plutil -extract id raw -o - "$STATE_PREFIX-submission.json")"
shasum -a 256 -c "$STATE_PREFIX-upload.sha256"
shasum -a 256 -c "$STATE_PREFIX-app.sha256"
echo "Apple notarization submission: $SUBMISSION_ID"
if ! xcrun notarytool wait "$SUBMISSION_ID" "${NOTARY_ARGS[@]}" --timeout 30m; then
    echo "Notarization did not finish successfully. Run task notarize:resume to check the same submission." >&2
    xcrun notarytool log "$SUBMISSION_ID" "${NOTARY_ARGS[@]}" "$STATE_PREFIX-log.json" || true
    exit 1
fi
xcrun notarytool info "$SUBMISSION_ID" "${NOTARY_ARGS[@]}" --output-format json > "$STATE_PREFIX-status.json"
if [ "$(plutil -extract status raw -o - "$STATE_PREFIX-status.json")" != Accepted ]; then
    xcrun notarytool log "$SUBMISSION_ID" "${NOTARY_ARGS[@]}" "$STATE_PREFIX-log.json"
    echo "Apple did not accept this submission. See dist/release/$STATE_PREFIX-log.json." >&2
    exit 1
fi
xcrun notarytool log "$SUBMISSION_ID" "${NOTARY_ARGS[@]}" "$STATE_PREFIX-log.json"
# Apple issues tickets for the DMG and its nested app. Also staple the local app
# for standalone validation; the distributed DMG carries its own ticket.
xcrun stapler staple "$APP_BUNDLE"
xcrun stapler validate "$APP_BUNDLE"
codesign --verify --strict --verbose=2 "$APP_BUNDLE"
spctl --assess --type execute --verbose=4 "$APP_BUNDLE"
# Keep the uploaded DMG unchanged so a resume can still verify its checksum.
# Work in a temporary directory so only a fully validated DMG gets the final name.
STAGING_DIR="$(mktemp -d "$PWD/.notarized-dmg.XXXXXX")"
trap 'rm -rf "$STAGING_DIR"' EXIT
cp "$ARCHIVE" "$STAGING_DIR/$NOTARIZED_ARCHIVE"
xcrun stapler staple "$STAGING_DIR/$NOTARIZED_ARCHIVE"
xcrun stapler validate "$STAGING_DIR/$NOTARIZED_ARCHIVE"
codesign --verify --strict --verbose=2 "$STAGING_DIR/$NOTARIZED_ARCHIVE"
hdiutil verify "$STAGING_DIR/$NOTARIZED_ARCHIVE"
spctl --assess --type open --context context:primary-signature --verbose=4 "$STAGING_DIR/$NOTARIZED_ARCHIVE"
mv -f "$STAGING_DIR/$NOTARIZED_ARCHIVE" "$NOTARIZED_ARCHIVE"
shasum -a 256 "$NOTARIZED_ARCHIVE" > "$NOTARIZED_ARCHIVE.sha256"
echo "Notarized distribution: $PWD/$NOTARIZED_ARCHIVE"

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASE_DIR="$ROOT_DIR/build/release"
XCODE_BUILD_DIR="$RELEASE_DIR/xcode"
APP_NAME="PhonoDeck.app"
APP_OUT="$RELEASE_DIR/$APP_NAME"
ZIP_OUT="$RELEASE_DIR/PhonoDeck-local-unsigned.zip"
METADATA_OUT="$RELEASE_DIR/metadata.json"

plist_value() {
  /usr/libexec/PlistBuddy -c "Print :$2" "$1" 2>/dev/null || true
}

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

cd "$ROOT_DIR"

bash scripts/release-preflight.sh

xcodegen generate

rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"

xcodebuild \
  -project PhonoDeck.xcodeproj \
  -scheme PhonoDeck \
  -configuration Release \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  GOOGLE_OAUTH_CLIENT_SECRET= \
  SYMROOT="$XCODE_BUILD_DIR" \
  build

BUILT_APP="$XCODE_BUILD_DIR/Release/$APP_NAME"
if [[ ! -d "$BUILT_APP" ]]; then
  echo "PACKAGE-LOCAL: built app missing" >&2
  exit 1
fi

ditto "$BUILT_APP" "$APP_OUT"

INFO_PLIST="$APP_OUT/Contents/Info.plist"
version="$(plist_value "$INFO_PLIST" CFBundleShortVersionString)"
build="$(plist_value "$INFO_PLIST" CFBundleVersion)"
bundle_id="$(plist_value "$INFO_PLIST" CFBundleIdentifier)"
oauth_secret="$(plist_value "$INFO_PLIST" GoogleOAuthClientSecret)"

if [[ -n "$oauth_secret" && "$oauth_secret" != "YOUR_DESKTOP_APP_CLIENT_SECRET" ]]; then
  echo "PACKAGE-LOCAL: packaged app contains a non-empty OAuth client secret" >&2
  rm -f "$ZIP_OUT" "$METADATA_OUT"
  exit 1
fi

if [[ "$bundle_id" != "ro.hont.phonodeck" ]]; then
  echo "PACKAGE-LOCAL: unexpected bundle identifier" >&2
  exit 1
fi

if ! codesign --verify --deep --strict "$APP_OUT" >/dev/null 2>&1; then
  signing_status="unsigned"
else
  signing_status="signed"
fi

(cd "$RELEASE_DIR" && ditto -c -k --keepParent "$APP_NAME" "$(basename "$ZIP_OUT")")
sha256="$(shasum -a 256 "$ZIP_OUT" | awk '{print $1}')"
created_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

cat > "$METADATA_OUT" <<JSON
{
  "name": "PhonoDeck",
  "bundleIdentifier": "$(json_escape "$bundle_id")",
  "version": "$(json_escape "$version")",
  "build": "$(json_escape "$build")",
  "configuration": "Release",
  "signingStatus": "$(json_escape "$signing_status")",
  "artifact": "$(json_escape "$(basename "$ZIP_OUT")")",
  "sha256": "$(json_escape "$sha256")",
  "createdAt": "$(json_escape "$created_at")"
}
JSON

echo "PACKAGE-LOCAL: PASS $ZIP_OUT"
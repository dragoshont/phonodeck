#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0
warn=0

ok() { printf 'ok    %s\n' "$1"; }
warn_msg() { printf 'warn  %s\n' "$1"; warn=$((warn + 1)); }
fail_msg() { printf 'fail  %s\n' "$1" >&2; fail=1; }

require_tool() {
  if command -v "$1" >/dev/null 2>&1; then
    ok "tool $1"
  else
    fail_msg "missing required tool $1"
  fi
}

plist_value() {
  /usr/libexec/PlistBuddy -c "Print :$2" "$1" 2>/dev/null || true
}

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

xcconfig_value() {
  local key="$1"
  local file="$2"
  awk -F= -v key="$key" '$1 ~ "^" key "[[:space:]]*$" {print $2}' "$file" 2>/dev/null | tail -n 1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

cd "$ROOT_DIR"

require_tool xcodebuild
require_tool xcodegen
require_tool plutil
require_tool codesign
require_tool ditto
require_tool shasum

if xcrun notarytool --help >/dev/null 2>&1; then
  ok "tool xcrun notarytool"
else
  warn_msg "xcrun notarytool unavailable; signed notarization must be run on a configured Mac"
fi

for path in project.yml Makefile Config/Info.plist Config/PhonoDeck.entitlements Config/BuildSettings.xcconfig Config/Secrets.xcconfig.example; do
  if [[ -f "$path" ]]; then ok "file $path"; else fail_msg "missing $path"; fi
done

marketing_version="$(awk -F: '/^[[:space:]]+MARKETING_VERSION:/ {gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2; exit}' project.yml)"
build_version="$(awk -F: '/^[[:space:]]+CURRENT_PROJECT_VERSION:/ {gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2; exit}' project.yml)"
bundle_identifier="$(awk -F: '
  /^  PhonoDeck:$/ { in_app = 1; next }
  /^  [A-Za-z0-9_]+:$/ && in_app { in_app = 0 }
  in_app && /^[[:space:]]+PRODUCT_BUNDLE_IDENTIFIER:/ {
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2)
    print $2
    exit
  }
' project.yml)"

if [[ "$marketing_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([-.][A-Za-z0-9.]+)?$ ]]; then ok "marketing version present"; else fail_msg "MARKETING_VERSION must be semantic, e.g. 0.1.0"; fi
if [[ "$build_version" =~ ^[0-9]+$ ]]; then ok "build number present"; else fail_msg "CURRENT_PROJECT_VERSION must be an integer"; fi
if [[ "$bundle_identifier" == "ro.hont.phonodeck" ]]; then ok "bundle identifier ro.hont.phonodeck"; else fail_msg "unexpected bundle identifier"; fi

if plutil -lint Config/Info.plist >/dev/null; then ok "Info.plist valid"; else fail_msg "Info.plist invalid"; fi
if plutil -lint Config/PhonoDeck.entitlements >/dev/null; then ok "entitlements plist valid"; else fail_msg "entitlements plist invalid"; fi

for key in CFBundleShortVersionString CFBundleVersion GoogleOAuthClientID GoogleOAuthClientSecret LSApplicationCategoryType NSAppTransportSecurity; do
  if grep -q "$key" Config/Info.plist; then ok "Info.plist key $key"; else fail_msg "missing Info.plist key $key"; fi
done

for entitlement in com.apple.security.app-sandbox com.apple.security.network.client com.apple.security.network.server com.apple.security.files.user-selected.read-only com.apple.security.files.user-selected.read-write; do
  value="$(plist_value Config/PhonoDeck.entitlements "$entitlement")"
  if [[ "$value" == "true" ]]; then ok "entitlement $entitlement"; else fail_msg "missing entitlement $entitlement"; fi
done

if grep -q '#include? "Secrets.xcconfig"' Config/BuildSettings.xcconfig; then
  ok "optional local secrets include"
else
  fail_msg "BuildSettings.xcconfig must include Secrets.xcconfig optionally"
fi

if git check-ignore -q Config/Secrets.xcconfig; then
  ok "Config/Secrets.xcconfig ignored"
else
  fail_msg "Config/Secrets.xcconfig must be ignored"
fi

if [[ -f Config/Secrets.xcconfig ]]; then
  google_secret="$(trim "$(xcconfig_value GOOGLE_OAUTH_CLIENT_SECRET Config/Secrets.xcconfig)")"
  if [[ -z "$google_secret" || "$google_secret" == "YOUR_DESKTOP_APP_CLIENT_SECRET" ]]; then
    ok "local Google OAuth secret is empty/placeholder"
  else
    warn_msg "local Google OAuth secret present in ignored config; package-local must strip it from artifacts"
  fi
else
  ok "local secrets file absent"
fi

if [[ -n "${PHONODECK_DEVELOPER_ID_APPLICATION:-}" ]]; then ok "Developer ID identity env present"; else warn_msg "Developer ID identity env missing"; fi
if [[ -n "${PHONODECK_NOTARY_KEYCHAIN_PROFILE:-}" ]]; then ok "notary keychain profile env present"; else warn_msg "notary keychain profile env missing"; fi

if [[ "$fail" -ne 0 ]]; then
  echo "RELEASE-PREFLIGHT: FAIL"
  exit 1
fi

echo "RELEASE-PREFLIGHT: PASS (${warn} warning(s))"
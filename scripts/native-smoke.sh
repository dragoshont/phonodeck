#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${1:-$ROOT_DIR/.architrave/native-smoke/$(date -u +%Y%m%dT%H%M%SZ)}"
APP_PATH="$ROOT_DIR/build/Debug/PhonoDeck.app"
LOG_FILE="$OUT_DIR/phonodeck.log"
SUMMARY_FILE="$OUT_DIR/summary.md"

mkdir -p "$OUT_DIR"

failures=0
warn() { printf 'WARN  %s\n' "$*" | tee -a "$SUMMARY_FILE"; }
fail() { printf 'FAIL  %s\n' "$*" | tee -a "$SUMMARY_FILE"; failures=$((failures + 1)); }
pass() { printf 'ok    %s\n' "$*" | tee -a "$SUMMARY_FILE"; }

cat > "$SUMMARY_FILE" <<'MARKDOWN'
# PhonoDeck Native Smoke

This smoke test launches the native macOS app, navigates the primary screens,
captures screenshots, and verifies source/load evidence in OSLog. It never prints
token or secret values.

MARKDOWN

start_utc="$(date -u '+%Y-%m-%d %H:%M:%S')"

if [[ "${PHONODECK_SMOKE_BUILD:-1}" != "0" ]]; then
  (cd "$ROOT_DIR" && xcodegen generate >/tmp/phonodeck-native-smoke-generate.log 2>&1)
  (cd "$ROOT_DIR" && xcodebuild -quiet -project PhonoDeck.xcodeproj -scheme PhonoDeck -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO SYMROOT="$ROOT_DIR/build" build >/tmp/phonodeck-native-smoke-build.log 2>&1)
fi

if [[ ! -x "$APP_PATH/Contents/MacOS/PhonoDeck" ]]; then
  fail "debug app bundle is missing at $APP_PATH"
  exit 1
fi

osascript -e 'tell application "PhonoDeck" to quit' >/dev/null 2>&1 || true
pkill -x PhonoDeck >/dev/null 2>&1 || true
open "$APP_PATH"
sleep 2

if pgrep -x PhonoDeck >/dev/null 2>&1; then
  pass "PhonoDeck process is running"
else
  fail "PhonoDeck process did not start"
fi

google_status=0
plex_status=0
spotify_status=0
security find-generic-password -s ro.hont.phonodeck.google -a youtube-oauth-tokens >/dev/null 2>&1 || google_status=$?
security find-generic-password -s ro.hont.phonodeck.plex -a plex-credentials >/dev/null 2>&1 || plex_status=$?
security find-generic-password -s ro.hont.phonodeck.spotify -a spotify-oauth-tokens >/dev/null 2>&1 || spotify_status=$?
printf '\n## Credential Presence\n\n' >> "$SUMMARY_FILE"
printf -- '- Google keychain status: %s\n' "$google_status" >> "$SUMMARY_FILE"
printf -- '- Plex keychain status: %s\n' "$plex_status" >> "$SUMMARY_FILE"
printf -- '- Spotify keychain status: %s\n' "$spotify_status" >> "$SUMMARY_FILE"

capture_screen() {
  local label="$1"
  local key="$2"
  local modifiers="$3"
  osascript <<APPLESCRIPT
tell application "PhonoDeck" to activate
delay 0.2
tell application "System Events"
  key code $key using {$modifiers}
end tell
delay 0.6
do shell script "screencapture -x \"$OUT_DIR/$label.png\""
APPLESCRIPT
  if [[ -s "$OUT_DIR/$label.png" ]]; then
    local bytes
    bytes="$(wc -c < "$OUT_DIR/$label.png" | tr -d ' ')"
    if [[ "$bytes" -gt 50000 ]]; then
      pass "captured $label screenshot ($bytes bytes)"
    else
      fail "$label screenshot appears too small ($bytes bytes)"
    fi
  else
    fail "missing $label screenshot"
  fi
}

printf '\n## Screen Captures\n\n' >> "$SUMMARY_FILE"
capture_screen library 18 'command down'
capture_screen playlists 19 'command down'
capture_screen albums 20 'command down'
capture_screen artists 21 'command down'
capture_screen queue 23 'command down'
capture_screen search 3 'command down'
capture_screen settings 43 'command down'

log show --style compact --info --start "$start_utc" --predicate 'subsystem == "ro.hont.phonodeck" && (category == "app" || category == "auth" || category == "playlist" || category == "search" || category == "playback")' > "$LOG_FILE" || true

printf '\n## Runtime Evidence\n\n' >> "$SUMMARY_FILE"
if [[ "$google_status" -eq 0 ]]; then
  if grep -q 'Library load finished' "$LOG_FILE"; then
    pass "Google/YouTube library load emitted runtime evidence"
  else
    fail "Google credentials exist but no YouTube library load evidence was found"
  fi
else
  warn "Google credentials absent; skipping YouTube library assertions"
fi

if [[ "$plex_status" -eq 0 ]]; then
  if grep -q 'Source library snapshot loaded; source=plex' "$LOG_FILE"; then
    pass "Plex source library snapshot loaded"
  elif grep -q 'Source library snapshot failed; source=plex' "$LOG_FILE"; then
    fail "Plex credentials exist but source library snapshot failed"
  else
    fail "Plex credentials exist but no source library snapshot evidence was found"
  fi
else
  warn "Plex credentials absent; skipping Plex library assertions"
fi

if [[ "$spotify_status" -eq 0 ]]; then
  if grep -q 'Spotify account restored\|Spotify connected' "$LOG_FILE"; then
    pass "Spotify account emitted restore/connect evidence"
  else
    fail "Spotify credentials exist but no Spotify restore/connect evidence was found"
  fi
else
  warn "Spotify credentials absent; skipping Spotify account assertions"
fi

if grep -q 'Playlist metadata enrichment skipped; rows still loaded' "$LOG_FILE"; then
  pass "playlist row fallback path is observable"
else
  warn "playlist row fallback was not exercised during this smoke run"
fi

printf '\nArtifacts: `%s`\n' "$OUT_DIR" >> "$SUMMARY_FILE"

if [[ "$failures" -eq 0 ]]; then
  printf 'NATIVE-SMOKE: PASS\n'
else
  printf 'NATIVE-SMOKE: FAIL (%s failures)\n' "$failures"
  exit 1
fi
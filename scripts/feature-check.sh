#!/usr/bin/env bash
# Deterministic gates for the Feature Builder harness — the "code-graded"
# (rule-based) layer that complements the semantic Adversarial Judge.
#
#   scripts/feature-check.sh          # full: ui-map JSON + xcodegen + build + test
#   scripts/feature-check.sh --quick  # fast: ui-map JSON validation only (used by hooks)
#
# Exit 0 = PASS, non-zero = FAIL. No secrets, no side effects beyond the build.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

quick=0
[ "${1:-}" = "--quick" ] && quick=1
fail=0
map="docs/design/phonodeck-ui-map.json"

echo "== validate ${map} =="
if [ -f "$map" ]; then
  if python3 -c "import json,sys; json.load(open(sys.argv[1])); print('ui-map JSON OK')" "$map"; then :; else
    echo "ui-map JSON INVALID"; fail=1
  fi
else
  echo "WARN: ${map} not found"
fi

if [ "$quick" -eq 1 ]; then
  if [ "$fail" -eq 0 ]; then echo "FEATURE-CHECK (quick): PASS"; else echo "FEATURE-CHECK (quick): FAIL"; fi
  exit "$fail"
fi

echo "== make generate =="; make generate || fail=1
echo "== make build ==";    make build    || fail=1
echo "== make test ==";     make test     || fail=1

if [ "$fail" -ne 0 ]; then echo "FEATURE-CHECK: FAIL"; exit 1; fi
echo "FEATURE-CHECK: PASS"

#!/usr/bin/env bash
# PostToolUse deterministic gate: keep the design source-of-truth parseable.
# Drains and ignores the hook JSON on stdin, validates phonodeck-ui-map.json,
# and BLOCKS (exit 2) if a tool left it invalid. Fast and auditable.
set -uo pipefail
cat >/dev/null 2>&1 || true   # drain stdin (hook payload, unused)
cd "$(dirname "$0")/../.." || exit 0

map="docs/design/phonodeck-ui-map.json"
[ -f "$map" ] || exit 0

if python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$map" 2>/dev/null; then
  exit 0
fi
echo "BLOCKED: ${map} is not valid JSON. The design map is the source of truth — fix it before continuing." >&2
exit 2

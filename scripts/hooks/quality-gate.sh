#!/usr/bin/env bash
# Stop gate for the Feature Builder harness (inline, scoped to that agent).
# Deterministic reminder that a feature isn't "done" until the code-graded gate
# is green AND the Adversarial Judge returned PASS. Also blocks if the design
# map broke. Drains the hook JSON on stdin (unused).
set -uo pipefail
cat >/dev/null 2>&1 || true
cd "$(dirname "$0")/../.." || exit 0

map="docs/design/phonodeck-ui-map.json"
if [ -f "$map" ] && ! python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$map" 2>/dev/null; then
  echo "BLOCKED: ${map} is not valid JSON — fix it before finishing." >&2
  exit 2
fi

printf '%s' '{"systemMessage":"Feature Builder gate: before declaring the feature done, confirm scripts/feature-check.sh is green (xcodegen + build + test + ui-map valid) AND the Adversarial Judge returned PASS against docs/qa/feature-evaluation-rubric.md. If this was a non-feature edit, ignore."}'
exit 0

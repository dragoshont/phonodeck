#!/usr/bin/env python3
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

REVIEW_MARKERS = [
    "remains missing",
    "still missing",
    "not implemented",
    "not wired",
    "planned",
    "future",
    "out of scope",
    "deferred",
    "todo",
    "experimental",
    "risk-labeled",
    "no-cookie",
    "official fallback",
]
MANUAL_MARKERS = [
    "manual",
    "voiceover",
    "keyboard",
    "accessibility",
    "operator",
    "live",
    "smoke",
    "full keyboard access",
    "increase contrast",
    "reduce motion",
    "route picker",
]
STORYBOOK_MARKERS = ["storybook"]
TEST_MARKERS = ["test", "tests", "fixture", "assert"]
IMPLEMENTED_MARKERS = ["implemented", "wired", "added", "passes", "uses", "now "]

ROW_RE = re.compile(r"^\| (?P<id>[A-Z]+-\d{3}) \| (?P<case>.*?) \| (?P<status>PASS|FAIL) \| (?P<evidence>.*?) \|$", re.MULTILINE)


def classify(status: str, case: str, evidence: str) -> str:
    text = f"{case} {evidence}".lower()
    if status == "FAIL":
        return "fail"
    if any(marker in text for marker in REVIEW_MARKERS):
        return "needs-review"
    if any(marker in text for marker in MANUAL_MARKERS):
        return "manual-or-live-evidence"
    if any(marker in text for marker in STORYBOOK_MARKERS):
        return "storybook-evidence"
    if any(marker in text for marker in TEST_MARKERS):
        return "tested-evidence"
    if any(marker in text for marker in IMPLEMENTED_MARKERS):
        return "implemented-claim"
    return "unclassified-pass"


def main() -> int:
    matrix_path = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("docs/qa/production-p0-screen-test-matrix.md")
    if not matrix_path.exists():
        print(f"QA matrix not found: {matrix_path}", file=sys.stderr)
        return 2

    rows = []
    for match in ROW_RE.finditer(matrix_path.read_text()):
        row = match.groupdict()
        row["classification"] = classify(row["status"], row["case"], row["evidence"])
        rows.append(row)

    if not rows:
        print(f"No QA rows found in {matrix_path}", file=sys.stderr)
        return 2

    counts = Counter(row["classification"] for row in rows)
    by_prefix = defaultdict(Counter)
    for row in rows:
        prefix = row["id"].split("-")[0]
        by_prefix[prefix][row["classification"]] += 1

    print("# QA Evidence Closure Report")
    print()
    print("This report classifies the P0 matrix evidence without changing the original row IDs. It is a release-evidence tool, not a replacement for live/manual validation.")
    print()
    print("## Summary")
    print()
    print(f"- Total rows: {len(rows)}")
    for key in sorted(counts):
        print(f"- {key}: {counts[key]}")
    print()
    print("## Surface Breakdown")
    print()
    print("| Surface | Total | Fail | Needs Review | Manual/Live | Storybook | Tested | Implemented Claim | Unclassified |")
    print("|---|---:|---:|---:|---:|---:|---:|---:|---:|")
    for prefix in sorted(by_prefix):
        counter = by_prefix[prefix]
        total = sum(counter.values())
        print(
            f"| {prefix} | {total} | {counter['fail']} | {counter['needs-review']} | "
            f"{counter['manual-or-live-evidence']} | {counter['storybook-evidence']} | "
            f"{counter['tested-evidence']} | {counter['implemented-claim']} | {counter['unclassified-pass']} |"
        )
    print()
    print("## Rows Requiring Review")
    print()
    review_rows = [row for row in rows if row["classification"] in {"fail", "needs-review", "manual-or-live-evidence", "storybook-evidence", "unclassified-pass"}]
    if not review_rows:
        print("No rows require review by this classifier.")
    else:
        print("| ID | Classification | Test Case | Current Status | Evidence |")
        print("|---|---|---|---|---|")
        for row in review_rows:
            case = row["case"].replace("|", "\\|")
            evidence = row["evidence"].replace("|", "\\|")
            print(f"| {row['id']} | {row['classification']} | {case} | {row['status']} | {evidence} |")
    print()
    print("## Interpretation")
    print()
    print("- `implemented-claim` means the row says implementation exists, but not necessarily that manual/live evidence exists.")
    print("- `tested-evidence` means the row references tests or fixtures.")
    print("- `needs-review` means the evidence contains stale, planned, experimental, or fallback wording and must be rechecked before release GO.")
    print("- `manual-or-live-evidence` means a human/operator validation artifact is expected.")
    print("- `storybook-evidence` is useful design evidence, but not native packaged-app proof.")
    print()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

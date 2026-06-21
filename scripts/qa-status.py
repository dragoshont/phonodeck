#!/usr/bin/env python3
import re
import sys
from pathlib import Path


def main() -> int:
    matrix_path = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("docs/qa/production-p0-screen-test-matrix.md")
    if not matrix_path.exists():
        print(f"QA matrix not found: {matrix_path}", file=sys.stderr)
        return 2

    text = matrix_path.read_text()
    rows = re.findall(r"^\| ([A-Z]+-\d{3}) \| .*? \| (PASS|FAIL) \|", text, flags=re.MULTILINE)
    if not rows:
        print(f"No QA rows found in {matrix_path}", file=sys.stderr)
        return 2

    failures = [row_id for row_id, status in rows if status == "FAIL"]
    passes = len(rows) - len(failures)
    print(f"QA matrix: {passes} PASS / {len(failures)} FAIL / {len(rows)} total")
    if failures:
        print("Remaining FAIL cases:")
        for row_id in failures:
            print(f"- {row_id}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
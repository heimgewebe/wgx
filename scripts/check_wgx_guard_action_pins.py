#!/usr/bin/env python3
"""Require immutable external action refs in the reusable WGX guard workflow."""

from __future__ import annotations

import re
import sys
from pathlib import Path

USES_RE = re.compile(r"^\s*(?:-\s*)?uses:\s*([^\s#]+)")
FULL_COMMIT_RE = re.compile(r"^[0-9a-f]{40}$")
DEFAULT_WORKFLOW = Path(".github/workflows/wgx-guard.yml")


def check_workflow(path: Path) -> list[str]:
    findings: list[str] = []
    external_count = 0

    if not path.is_file():
        return [f"workflow not found: {path}"]

    for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        match = USES_RE.match(line)
        if match is None:
            continue
        value = match.group(1)
        if len(value) >= 2 and value[0] == value[-1] and value[0] in {"\"", "'"}:
            value = value[1:-1]
        if value.startswith("./"):
            continue
        external_count += 1
        if "@" not in value:
            findings.append(f"{path}:{line_number}: external uses ref has no @ revision: {value}")
            continue
        target, revision = value.rsplit("@", 1)
        if not FULL_COMMIT_RE.fullmatch(revision):
            findings.append(
                f"{path}:{line_number}: {target}@{revision} is not pinned to a full lowercase commit SHA"
            )

    if external_count == 0:
        findings.append(f"{path}: no external uses references found")
    return findings


def main(argv: list[str] | None = None) -> int:
    args = sys.argv[1:] if argv is None else argv
    if len(args) > 1:
        print("usage: check_wgx_guard_action_pins.py [workflow]", file=sys.stderr)
        return 2
    path = Path(args[0]) if args else DEFAULT_WORKFLOW
    findings = check_workflow(path)
    if findings:
        for finding in findings:
            print(f"FAIL: {finding}", file=sys.stderr)
        return 1
    print(f"PASS: all external uses references in {path} are full commit pins")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

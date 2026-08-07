#!/usr/bin/env python3
"""Validate that the legacy WGX smoke entrypoint is only a pinned Metarepo shim."""

from __future__ import annotations

import sys
from pathlib import Path

DEFAULT_WORKFLOW = Path(".github/workflows/wgx-smoke.yml")
METAREPO_VERIFICATION_COMMIT = "31dbecc6c7b966faa73ad3dceb0ded7329187f36"
METAREPO_REUSABLE = (
    "heimgewebe/metarepo/.github/workflows/reusable-repo-verify.yml@"
    + METAREPO_VERIFICATION_COMMIT
)


def check_contract(path: Path) -> list[str]:
    if not path.is_file():
        return [f"workflow not found: {path}"]

    text = path.read_text(encoding="utf-8")
    findings: list[str] = []
    required_fragments = {
        "workflow_call trigger": "  workflow_call:",
        "pinned Metarepo verification reusable": f"uses: {METAREPO_REUSABLE}",
        "smoke mode binding": "      mode: smoke",
    }
    for label, fragment in required_fragments.items():
        if fragment not in text:
            findings.append(f"{path}: missing {label}")

    for forbidden in (
        "runs-on:",
        "actions/checkout@",
        "setup-python@",
        "pip install",
        "wgx task smoke",
        "repository: heimgewebe/wgx",
    ):
        if forbidden in text:
            findings.append(f"{path}: compatibility shim contains implementation detail: {forbidden}")
    if "reusable-repo-verify.yml@main" in text:
        findings.append(f"{path}: Metarepo verification workflow must not use @main")
    return findings


def main(argv: list[str] | None = None) -> int:
    args = sys.argv[1:] if argv is None else argv
    if len(args) > 1:
        print("usage: check_wgx_smoke_contract.py [workflow]", file=sys.stderr)
        return 2
    path = Path(args[0]) if args else DEFAULT_WORKFLOW
    findings = check_contract(path)
    if findings:
        for finding in findings:
            print(f"FAIL: {finding}", file=sys.stderr)
        return 1
    print(f"PASS: {path} is a pinned Metarepo smoke compatibility shim")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

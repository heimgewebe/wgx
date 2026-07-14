#!/usr/bin/env python3
"""Validate the reusable, immutable WGX smoke workflow contract."""

from __future__ import annotations

import sys
from pathlib import Path

DEFAULT_WORKFLOW = Path(".github/workflows/wgx-smoke.yml")
PINNED_CLI_COMMIT = "3c2391623a1719ac5f0dd1cda6ba906b94079053"
PY_YAML_WHEEL_SHA256 = "ba1cc08a7ccde2d2ec775841541641e4548226580ab850948cbfda66a1befcdc"


def check_contract(path: Path) -> list[str]:
    if not path.is_file():
        return [f"workflow not found: {path}"]

    text = path.read_text(encoding="utf-8")
    findings: list[str] = []
    required_fragments = {
        "workflow_call trigger": "  workflow_call:",
        "pinned WGX CLI checkout": f"          ref: {PINNED_CLI_COMMIT}",
        "fixed Python runtime": '          python-version: "3.12"',
        "hash-only dependency install": "--require-hashes",
        "binary-only dependency install": "--only-binary=:all:",
        "pinned PyYAML version": "PyYAML==6.0.3",
        "pinned PyYAML wheel hash": f"            --hash=sha256:{PY_YAML_WHEEL_SHA256}",
        "declared smoke-task failure": "WGX profile does not declare a smoke task",
        "smoke task execution": "          wgx task smoke",
    }
    for label, fragment in required_fragments.items():
        if fragment not in text:
            findings.append(f"{path}: missing {label}")

    if "ref: main" in text:
        findings.append(f"{path}: WGX CLI checkout must not use ref: main")
    if "wgx-smoke.yml@main" in text:
        findings.append(f"{path}: smoke workflow must not recursively call @main")
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
    print(f"PASS: {path} is reusable and bound to the pinned WGX CLI")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

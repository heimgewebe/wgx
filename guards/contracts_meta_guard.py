#!/usr/bin/env python3
"""
contracts_meta_guard.py

Guard: Structural integrity checks for contracts/events/*.schema.json and optional *.meta.json sidecars.

Design:
- Keep schema files strict-validator friendly (no unknown x-* keys).
- Governance metadata lives next to schema in *.meta.json (NOT JSON-Schema).
- Ensure meta sidecar (if present) is valid and points to the schema.

Exit codes:
 0 OK
 2 Guard found violations
 3 Misconfiguration (missing directories etc.)
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any


SSOT_HINT = "SSOT: metarepo/contracts/events/*.schema.json"


@dataclass
class Finding:
    level: str  # "ERROR" | "WARN"
    path: str
    message: str


def _read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def _is_json_schema_file(p: Path) -> bool:
    return p.name.endswith(".schema.json")


def _is_meta_file_for_schema(schema: Path) -> Path:
    # Replace ".schema.json" with ".meta.json"
    base = schema.name[:-len(".schema.json")]
    return schema.with_name(base + ".meta.json")


def _schema_basename(schema: Path) -> str:
    return schema.name[:-len(".schema.json")]


def _collect_files(root: Path) -> list[Path]:
    if not root.exists() or not root.is_dir():
        raise FileNotFoundError(str(root))
    return sorted([p for p in root.iterdir() if p.is_file()])


def _has_forbidden_x_keys(schema_obj: dict[str, Any]) -> list[str]:
    return sorted([k for k in schema_obj.keys() if isinstance(k, str) and k.startswith("x-")])


def _validate_meta(meta: dict[str, Any], meta_path: Path, schema_path: Path, require_meta_fields: bool) -> list[Finding]:
    findings: list[Finding] = []

    def err(msg: str) -> None:
        findings.append(Finding("ERROR", str(meta_path), msg))

    def warn(msg: str) -> None:
        findings.append(Finding("WARN", str(meta_path), msg))

    # Required top-level keys (when meta exists)
    for key in ["contract", "schema", "governance"]:
        if key not in meta:
            if require_meta_fields:
                err(f"missing '{key}'")
            else:
                warn(f"missing '{key}'")

    # schema pointer check (best-effort)
    schema_ptr = meta.get("schema")
    if isinstance(schema_ptr, str):
        # Expect relative path that matches actual repo path
        expected = str(schema_path.as_posix())
        if schema_ptr != expected:
            warn(f"schema path mismatch: meta.schema='{schema_ptr}' expected '{expected}'")
    else:
        if require_meta_fields:
            err("meta.schema must be a string")
        else:
            warn("meta.schema should be a string")

    # contract name (best-effort consistency)
    contract = meta.get("contract")
    if isinstance(contract, str):
        # Allow either full name or basename; warn on obvious mismatch
        base = _schema_basename(schema_path)
        if base not in contract:
            warn(f"meta.contract '{contract}' does not seem to reference schema basename '{base}'")
    else:
        if require_meta_fields:
            err("meta.contract must be a string")
        else:
            warn("meta.contract should be a string")

    gov = meta.get("governance")
    if isinstance(gov, dict):
        for k in ["producers", "consumers"]:
            v = gov.get(k)
            if not isinstance(v, list) or len(v) == 0:
                if require_meta_fields:
                    err(f"governance.{k} must be a non-empty list")
                else:
                    warn(f"governance.{k} should be a non-empty list")
            else:
                # Ensure all entries are strings
                bad = [x for x in v if not isinstance(x, str) or not x.strip()]
                if bad:
                    if require_meta_fields:
                        err(f"governance.{k} contains non-string/empty entries: {bad!r}")
                    else:
                        warn(f"governance.{k} contains non-string/empty entries: {bad!r}")
    else:
        if require_meta_fields:
            err("meta.governance must be an object")
        else:
            warn("meta.governance should be an object")

    return findings


def _validate_schema(schema: dict[str, Any], schema_path: Path, strict: bool) -> list[Finding]:
    findings: list[Finding] = []

    def err(msg: str) -> None:
        findings.append(Finding("ERROR", str(schema_path), msg))

    def warn(msg: str) -> None:
        findings.append(Finding("WARN", str(schema_path), msg))

    # forbidden x-* keys in strict mode
    xkeys = _has_forbidden_x_keys(schema)
    if xkeys:
        if strict:
            err(f"forbidden keys in schema (strict): {xkeys} — move governance to *.meta.json ({SSOT_HINT})")
        else:
            warn(f"forbidden keys in schema: {xkeys} — move governance to *.meta.json ({SSOT_HINT})")

    # minimal sanity: $id and $schema are helpful; warn-only to avoid blocking
    if "$schema" not in schema:
        warn("missing '$schema' (recommended)")
    if "$id" not in schema:
        warn("missing '$id' (recommended)")

    # $ref sanity: relative refs should point to existing file
    ref = schema.get("$ref")
    if isinstance(ref, str) and ref.startswith("./"):
        target = schema_path.parent / ref[2:]
        if not target.exists():
            # In strict mode, missing ref is error (validator will fail)
            if strict:
                err(f"$ref cannot be resolved: '{ref}' → expected file '{target.as_posix()}'")
            else:
                warn(f"$ref cannot be resolved: '{ref}' → expected file '{target.as_posix()}'")

    return findings


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default="contracts/events", help="Directory to scan (default: contracts/events)")
    ap.add_argument("--strict", action="store_true", help="Treat issues as errors (default: warn on some)")
    ap.add_argument("--require-meta", action="store_true", help="Require *.meta.json for each *.schema.json")
    ap.add_argument("--require-meta-fields", action="store_true", help="Treat missing meta fields as errors (if meta exists)")
    args = ap.parse_args()

    root = Path(args.root)
    try:
        files = _collect_files(root)
    except FileNotFoundError:
        print(f"[contracts-meta-guard] ERROR: missing directory '{root.as_posix()}'", file=sys.stderr)
        return 3

    findings: list[Finding] = []

    schemas = [p for p in files if _is_json_schema_file(p)]
    for schema_path in schemas:
        try:
            schema_obj = _read_json(schema_path)
        except Exception as e:
            findings.append(Finding("ERROR", str(schema_path), f"invalid JSON: {e}"))
            continue

        if not isinstance(schema_obj, dict):
            findings.append(Finding("ERROR", str(schema_path), "schema root must be a JSON object"))
            continue

        findings.extend(_validate_schema(schema_obj, schema_path, strict=args.strict))

        meta_path = _is_meta_file_for_schema(schema_path)
        if meta_path.exists():
            try:
                meta_obj = _read_json(meta_path)
            except Exception as e:
                findings.append(Finding("ERROR", str(meta_path), f"invalid JSON: {e}"))
                continue
            if not isinstance(meta_obj, dict):
                findings.append(Finding("ERROR", str(meta_path), "meta root must be a JSON object"))
            else:
                findings.extend(_validate_meta(meta_obj, meta_path, schema_path, require_meta_fields=args.require_meta_fields))
        else:
            if args.require_meta:
                findings.append(Finding("ERROR", str(meta_path), "missing meta sidecar for schema (required by guard)"))

    # Print summary
    errors = [f for f in findings if f.level == "ERROR"]
    warns = [f for f in findings if f.level == "WARN"]

    for f in warns:
        print(f"[contracts-meta-guard] WARN  {f.path}: {f.message}", file=sys.stderr)
    for f in errors:
        print(f"[contracts-meta-guard] ERROR {f.path}: {f.message}", file=sys.stderr)

    if errors:
        print(f"[contracts-meta-guard] FAIL: {len(errors)} error(s), {len(warns)} warning(s)", file=sys.stderr)
        return 2

    print(f"[contracts-meta-guard] OK: {len(schemas)} schema file(s), {len(warns)} warning(s)", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

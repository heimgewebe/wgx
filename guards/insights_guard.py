#!/usr/bin/env python3
"""
guards/insights_guard.py

Validates insight streams against local contracts.
Part of PR3d (wgx guard hardening).

Logic:
1. Locate schema (contracts/insights.schema.json or contracts/events/insights.schema.json)
2. Locate data (artifacts/insights.daily.json, etc.)
3. Validate data against schema (supports JSON and JSONL)
4. Enforce strict structure for insight.negation

Exit codes:
 0: Success or Skip (missing optional dependency or no relevant files)
 1: Validation Failure or Parse Error
"""

import sys
import json
import glob
import os

try:
    import jsonschema
except ImportError:
    # Use ::notice:: for GitHub Actions visibility
    print("::notice::[wgx][guard][insights] SKIP: jsonschema not installed", file=sys.stderr)
    sys.exit(0)

def load_data(filepath):
    """
    Load data from JSON or JSONL file.
    Returns a list of items or raises an exception.
    """
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Try JSON first
    try:
        data = json.loads(content)
        if isinstance(data, list):
            return data
        elif isinstance(data, dict):
            return [data]
        else:
            # Valid JSON but not a list/dict (e.g. primitive) -> treat as empty list or invalid?
            # Contracts usually expect objects/lists.
            return []
    except json.JSONDecodeError:
        # Try JSONL
        items = []
        lines = content.splitlines()
        valid_lines_count = 0

        for i, line in enumerate(lines):
            line = line.strip()
            if not line:
                continue
            try:
                items.append(json.loads(line))
                valid_lines_count += 1
            except json.JSONDecodeError as e:
                 raise ValueError(f"Line {i+1}: {e}")

        # Hardsicherung: JSONL fallback only valid if at least one line was valid JSON.
        # If content was not empty but produced 0 valid lines (e.g. random text file with no newlines that failed first parse),
        # we should have caught it.
        # If file was truly empty (0 bytes), content is empty, first json.loads fails? No, json.loads("") raises.
        # If file is whitespace only, content.splitlines() might be empty or whitespace lines.
        # If we have content but 0 valid lines, it's garbage.
        if content.strip() and valid_lines_count == 0:
             raise ValueError("File content is neither valid JSON nor valid JSONL (no valid lines found)")

        return items

def main():
    # 1. Locate Schema
    schema_path = None
    if os.path.exists("contracts/insights.schema.json"):
        schema_path = "contracts/insights.schema.json"
    elif os.path.exists("contracts/events/insights.schema.json"):
        schema_path = "contracts/events/insights.schema.json"

    if not schema_path:
        # Skip with info
        print("[wgx][guard][insights] SKIP: No schema found (checked contracts/insights.schema.json, contracts/events/insights.schema.json).", file=sys.stderr)
        return 0

    # 2. Locate Data
    # Priority list (first match wins)
    patterns = [
        "artifacts/insights.daily.json",
        "artifacts/insights.json",
        "insights/*.json",
        "events/insights/*.json"
    ]

    data_files = []
    found_source = ""

    for pat in patterns:
        if "*" in pat:
            matches = sorted(glob.glob(pat))
            if matches:
                data_files = matches
                found_source = pat
                break
        else:
            if os.path.exists(pat):
                data_files = [pat]
                found_source = pat
                break

    if not data_files:
        print("[wgx][guard][insights] SKIP: No insight data found.", file=sys.stderr)
        return 0

    print(f"[wgx][guard][insights] Validating {len(data_files)} file(s) from '{found_source}' against '{schema_path}'...", file=sys.stderr)

    # 3. Load Schema
    try:
        with open(schema_path, 'r', encoding='utf-8') as f:
            schema = json.load(f)
    except Exception as e:
         print(f"[wgx][guard][insights] ERROR: Failed to parse schema {schema_path}: {e}", file=sys.stderr)
         return 1

    # 4. Validate
    errors = 0

    for df in data_files:
        try:
            items = load_data(df)
        except Exception as e:
            print(f"[wgx][guard][insights] ERROR: Failed to parse data {df}: {e}", file=sys.stderr)
            errors += 1
            continue

        for i, item in enumerate(items):
            item_id = item.get("id", f"item-{i}")
            schema_failed = False

            # Schema Validation
            try:
                jsonschema.validate(instance=item, schema=schema)
            except jsonschema.ValidationError as e:
                schema_failed = True
                # Format error: concise if possible
                msg = e.message
                if len(msg) > 200: msg = msg[:200] + "..."
                print(f"[wgx][guard][insights]\nschema: {schema_path}\ndata: {df}\nid: {item_id}\nerror: {msg}", file=sys.stderr)
                errors += 1

            # Explicit Negation Check (Defense in Depth)
            # NOTE: Ideally, the requirement for 'relation', 'thesis', and 'antithesis' should be enforced
            # by the contract (schema) itself. We perform this manual check as "Defense-in-Depth" to ensure
            # structural integrity even if the local contract is lenient.
            # TODO: Advocate for upstreaming strict negation logic (mandatory relation.thesis/antithesis)
            # into the canonical Metarepo contracts. Once standardized, this manual check might become redundant.

            # Only run if schema validation passed (to avoid duplicate errors if schema already catches it)
            if not schema_failed and item.get("type") == "insight.negation":
                relation = item.get("relation")
                if not isinstance(relation, dict):
                     print(f"[wgx][guard][insights]\nschema: {schema_path}\ndata: {df}\nid: {item_id}\nerror: missing relation for insight.negation", file=sys.stderr)
                     errors += 1
                else:
                    if "thesis" not in relation:
                        print(f"[wgx][guard][insights]\nschema: {schema_path}\ndata: {df}\nid: {item_id}\nerror: missing relation.thesis for insight.negation", file=sys.stderr)
                        errors += 1
                    if "antithesis" not in relation:
                         print(f"[wgx][guard][insights]\nschema: {schema_path}\ndata: {df}\nid: {item_id}\nerror: missing relation.antithesis for insight.negation", file=sys.stderr)
                         errors += 1

    if errors > 0:
        print(f"[wgx][guard][insights] FAILED: {errors} error(s) found.", file=sys.stderr)
        return 1

    print("[wgx][guard][insights] OK", file=sys.stderr)
    return 0

if __name__ == "__main__":
    sys.exit(main())

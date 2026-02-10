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
    # Defer exit until main() so imports (e.g. for testing) keep working.
    jsonschema = None

try:
    from guards._util import safe_item_id
except ImportError:
    from _util import safe_item_id

def load_data(filepath):
    """
    Load data from JSON or JSONL file.
    Returns a list of items or raises an exception.
    """
    items = []
    with open(filepath, 'r', encoding='utf-8') as f:
        # Try JSON first
        try:
            data = json.load(f)
            if isinstance(data, list):
                return data
            elif isinstance(data, dict):
                return [data]
            else:
                # Valid JSON but wrong shape (e.g. primitive) – surface as error so
                # callers do not silently skip validation.
                raise ValueError(
                    "File content must be a JSON object or array (got primitive value)"
                )
        except json.JSONDecodeError:
            # Try JSONL
            f.seek(0)
            valid_lines_count = 0

            for i, line in enumerate(f):
                line = line.strip()
                if not line:
                    continue
                try:
                    items.append(json.loads(line))
                    valid_lines_count += 1
                except json.JSONDecodeError as e:
                    raise ValueError(f"Line {i+1}: {e}")

            # If we reached here, either file is empty, whitespace only, or we parsed some lines.
            # If no valid lines were found, it's an empty or whitespace-only file (since invalid lines raise).
            # We return empty list in that case.

            return items

def main():
    if jsonschema is None:
        # Use ::notice:: for GitHub Actions visibility
        print("::notice::[wgx][guard][insights] SKIP: jsonschema not installed", file=sys.stderr)
        return 0

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

        # Optimization: Create a validator instance once to avoid repeated schema compilation
        # which can be very expensive for large datasets.
        validator_cls = jsonschema.validators.validator_for(schema)
        validator_cls.check_schema(schema)
        validator = validator_cls(schema)

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
            item_id = safe_item_id(item, i)
            schema_failed = False

            # Schema Validation
            try:
                validator.validate(item)
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
            # Defense-in-depth: even if contracts are lenient/out-of-date, enforce relation.thesis/antithesis.

            # Only run if schema validation passed (to avoid duplicate errors if schema already catches it)
            if not schema_failed and item.get("type") == "insight.negation":
                relation = item.get("relation")
                if not isinstance(relation, dict):
                     print(f"[wgx][guard][insights]\nschema: {schema_path}\ndata: {df}\nid: {item_id}\nerror: invalid relation for insight.negation (expected object)", file=sys.stderr)
                     errors += 1
                else:
                    # Thesis check
                    thesis = relation.get("thesis")
                    if not isinstance(thesis, str) or not thesis.strip():
                        print(f"[wgx][guard][insights]\nschema: {schema_path}\ndata: {df}\nid: {item_id}\nerror: invalid relation.thesis for insight.negation (expected non-empty string)", file=sys.stderr)
                        errors += 1

                    # Antithesis check
                    antithesis = relation.get("antithesis")
                    if not isinstance(antithesis, str) or not antithesis.strip():
                         print(f"[wgx][guard][insights]\nschema: {schema_path}\ndata: {df}\nid: {item_id}\nerror: invalid relation.antithesis for insight.negation (expected non-empty string)", file=sys.stderr)
                         errors += 1

    if errors > 0:
        print(f"[wgx][guard][insights] FAILED: {errors} error(s) found.", file=sys.stderr)
        return 1

    print("[wgx][guard][insights] OK", file=sys.stderr)
    return 0

if __name__ == "__main__":
    sys.exit(main())

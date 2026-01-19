#!/usr/bin/env python3
"""
guards/data_flow_guard.py

Guard: Validates data flow artifacts against their contracts.
Part of the "Heimgewebe" architecture hardening.

Logic:
1. Iterates over defined data flows (Observatory, Delivery Reports, Ingest State, Events).
2. Locates schema for each flow.
3. Locates data files for each flow.
4. Validates data against schema.

Exit codes:
 0: Success (all checks passed or skipped)
 1: Validation Failure
"""

import sys
import json
import glob
import os

try:
    import jsonschema
except ImportError:
    jsonschema = None

# Configuration: Flows to check
# schema_candidates: list of relative paths to look for schema (first found wins)
# data_patterns: list of glob patterns to look for data files
FLOWS = {
    "observatory": {
        "schema_candidates": [
            "contracts/knowledge.observatory.schema.json",
            "contracts/events/knowledge.observatory.schema.json"
        ],
        "data_patterns": [
            "artifacts/knowledge.observatory.json"
        ]
    },
    "delivery_report": {
        "schema_candidates": [
            "contracts/plexer.delivery.report.v1.schema.json",
            "contracts/events/plexer.delivery.report.v1.schema.json"
        ],
        "data_patterns": [
            "reports/plexer/delivery.report.json",
            "reports/delivery.report.json"
        ]
    },
    "ingest_state": {
        "schema_candidates": [
            "contracts/heimlern.ingest.state.v1.schema.json",
            "contracts/events/heimlern.ingest.state.v1.schema.json"
        ],
        "data_patterns": [
            "data/heimlern.cursor.json",
            "data/ingest.state.json"
        ]
    },
    "event_envelope": {
        "schema_candidates": [
            "contracts/plexer.event.envelope.v1.schema.json",
            "contracts/events/plexer.event.envelope.v1.schema.json"
        ],
        "data_patterns": [
            "event.json",
            "events/*.json",
            "reports/events/*.json"
        ]
    }
}

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
            # Valid JSON but primitive
            raise ValueError("File content must be a JSON object or array")
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

        if content.strip() and valid_lines_count == 0:
             raise ValueError("File content is neither valid JSON nor valid JSONL")

        return items

def resolve_schema(candidates):
    for path in candidates:
        if os.path.exists(path):
            return path
    return None

def resolve_data(patterns):
    files = []
    for pat in patterns:
        if "*" in pat:
            matches = sorted(glob.glob(pat))
            files.extend(matches)
        else:
            if os.path.exists(pat):
                files.append(pat)
    return sorted(list(set(files))) # dedupe

def main():
    if jsonschema is None:
        print("::notice::[wgx][guard][data_flow] SKIP: jsonschema not installed", file=sys.stderr)
        return 0

    total_errors = 0
    checks_run = 0

    for flow_name, config in FLOWS.items():
        # 1. Locate Schema
        schema_path = resolve_schema(config["schema_candidates"])
        if not schema_path:
            # Skip this flow if no schema is defined
            continue

        # 2. Locate Data
        data_files = resolve_data(config["data_patterns"])
        if not data_files:
            # Skip if no data found
            continue

        checks_run += 1
        print(f"[wgx][guard][data_flow] Checking '{flow_name}': {len(data_files)} file(s) against '{schema_path}'...", file=sys.stderr)

        # 3. Load Schema
        try:
            with open(schema_path, 'r', encoding='utf-8') as f:
                schema = json.load(f)
        except Exception as e:
            print(f"[wgx][guard][data_flow] ERROR: Failed to parse schema {schema_path}: {e}", file=sys.stderr)
            total_errors += 1
            continue

        # 4. Validate Data
        for df in data_files:
            try:
                items = load_data(df)
            except Exception as e:
                print(f"[wgx][guard][data_flow] ERROR: Failed to parse data {df}: {e}", file=sys.stderr)
                total_errors += 1
                continue

            for i, item in enumerate(items):
                item_id = item.get("id", f"item-{i}")
                try:
                    jsonschema.validate(instance=item, schema=schema)
                except jsonschema.ValidationError as e:
                    msg = e.message
                    if len(msg) > 200: msg = msg[:200] + "..."
                    print(f"[wgx][guard][data_flow]\nflow: {flow_name}\nschema: {schema_path}\ndata: {df}\nid: {item_id}\nerror: {msg}", file=sys.stderr)
                    total_errors += 1

    if total_errors > 0:
        print(f"[wgx][guard][data_flow] FAILED: {total_errors} error(s) found.", file=sys.stderr)
        return 1

    if checks_run == 0:
        print("[wgx][guard][data_flow] SKIP: No active flows detected (schema + data missing).", file=sys.stderr)
    else:
        print(f"[wgx][guard][data_flow] OK: {checks_run} flow(s) checked.", file=sys.stderr)

    return 0

if __name__ == "__main__":
    sys.exit(main())

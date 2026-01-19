#!/usr/bin/env python3
"""
guards/data_flow_guard.py

Guard: Validates data flow artifacts against their contracts.
Part of the "Heimgewebe" architecture hardening.

Config:
- Reads flow definitions from 'contracts/flows.yaml' (or .json).
- Format:
  flows:
    <name>:
      schema: "path/to/schema.json"
      data: ["pattern/to/data.json"]

Logic:
1. Load configuration.
2. For each flow:
   - Check if data exists.
   - If data exists:
     - Check if schema exists.
     - If schema MISSING -> FAIL.
     - If schema EXISTS -> Validate (FAIL on error).
   - If data missing -> SKIP (OK).

Exit codes:
 0: Success (all checks passed or skipped)
 1: Validation Failure or Config Error
"""

import sys
import json
import glob
import os
import pathlib
from urllib.parse import urljoin

# Try imports
try:
    import jsonschema
except ImportError:
    jsonschema = None

try:
    import yaml
except ImportError:
    yaml = None

def load_config():
    """
    Load flows configuration from contracts/flows.yaml or contracts/flows.json.
    """
    candidates = ["contracts/flows.yaml", "contracts/flows.json", ".wgx/flows.yaml", ".wgx/flows.json"]

    for path in candidates:
        if os.path.exists(path):
            if path.endswith(".yaml") or path.endswith(".yml"):
                if yaml is None:
                    print(f"::warning::[wgx][guard][data_flow] Found config '{path}' but PyYAML is not installed. Skipping.", file=sys.stderr)
                    continue
                try:
                    with open(path, 'r', encoding='utf-8') as f:
                        return yaml.safe_load(f), path
                except Exception as e:
                    print(f"[wgx][guard][data_flow] ERROR: Failed to parse YAML config '{path}': {e}", file=sys.stderr)
                    sys.exit(1)
            else:
                try:
                    with open(path, 'r', encoding='utf-8') as f:
                        return json.load(f), path
                except Exception as e:
                    print(f"[wgx][guard][data_flow] ERROR: Failed to parse JSON config '{path}': {e}", file=sys.stderr)
                    sys.exit(1)

    return None, None

def load_data(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    try:
        data = json.loads(content)
        if isinstance(data, list):
            return data
        elif isinstance(data, dict):
            return [data]
        else:
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

def resolve_data(patterns):
    files = []
    if isinstance(patterns, str):
        patterns = [patterns]

    for pat in patterns:
        if "*" in pat:
            matches = sorted(glob.glob(pat))
            files.extend(matches)
        else:
            if os.path.exists(pat):
                files.append(pat)
    return sorted(list(set(files)))

def main():
    if jsonschema is None:
        print("::notice::[wgx][guard][data_flow] SKIP: jsonschema not installed", file=sys.stderr)
        return 0

    config, config_path = load_config()

    if not config:
        # Fallback to hardcoded defaults ONLY if no config found, or exit?
        # The prompt implies we should harmonize. If config is missing, maybe we shouldn't guess.
        # But to be safe for existing repos without config, we might output a warning.
        print("::notice::[wgx][guard][data_flow] No flow configuration found (checked contracts/flows.yaml, etc). Skipping.", file=sys.stderr)
        return 0

    flows = config.get("flows", {})
    if not flows:
        print(f"[wgx][guard][data_flow] Config '{config_path}' has no 'flows' defined.", file=sys.stderr)
        return 0

    total_errors = 0
    checks_run = 0

    for flow_name, definition in flows.items():
        # Definition format: { "schema": "...", "data": [...] }
        # Or schema_candidates/data_patterns from previous version?
        # Let's support the simple "schema" (string) and "data" (list/string) format as per prompt implication.

        schema_rel_path = definition.get("schema")
        data_patterns = definition.get("data")

        if not data_patterns:
            continue

        # 1. Locate Data
        data_files = resolve_data(data_patterns)

        if not data_files:
            # No data -> SKIP (OK)
            continue

        # 2. Locate Schema (Strict check now)
        if not schema_rel_path:
             print(f"[wgx][guard][data_flow] ERROR: Flow '{flow_name}' has data files but no 'schema' defined in config.", file=sys.stderr)
             total_errors += 1
             continue

        if not os.path.exists(schema_rel_path):
             print(f"[wgx][guard][data_flow] FAIL: Flow '{flow_name}' data exists ({len(data_files)} files) but schema is missing at '{schema_rel_path}'.", file=sys.stderr)
             total_errors += 1
             continue

        checks_run += 1
        print(f"[wgx][guard][data_flow] Checking '{flow_name}': {len(data_files)} file(s) against '{schema_rel_path}'...", file=sys.stderr)

        # 3. Load Schema & Validate
        try:
            with open(schema_rel_path, 'r', encoding='utf-8') as f:
                schema = json.load(f)

            # Prepare Resolver
            # Base URI as file:// path to the schema directory to support relative $ref
            schema_abs_path = pathlib.Path(schema_rel_path).resolve()
            base_uri = schema_abs_path.as_uri()

            # In jsonschema >= 4.18, referencing is different, but < 4.18 uses RefResolver.
            # We try standard validate; if it fails on ref, we might need manual resolver setup.
            # Usually providing a fully resolved schema or correct working dir helps.
            # Ideally, we pass resolver=... to validate, but simple validate() might not infer base_uri from file.
            # We will use explicit validator class to set base_uri.

            validator_cls = jsonschema.validators.validator_for(schema)
            # Create a resolver that points to the schema file's location
            resolver = jsonschema.RefResolver(base_uri=base_uri, referrer=schema)
            validator = validator_cls(schema, resolver=resolver)

        except Exception as e:
            print(f"[wgx][guard][data_flow] ERROR: Failed to prepare schema '{schema_rel_path}': {e}", file=sys.stderr)
            total_errors += 1
            continue

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
                    validator.validate(item)
                except jsonschema.ValidationError as e:
                    msg = e.message
                    if len(msg) > 200: msg = msg[:200] + "..."
                    print(f"[wgx][guard][data_flow]\nflow: {flow_name}\nschema: {schema_rel_path}\ndata: {df}\nid: {item_id}\nerror: {msg}", file=sys.stderr)
                    total_errors += 1

    if total_errors > 0:
        print(f"[wgx][guard][data_flow] FAILED: {total_errors} error(s) found.", file=sys.stderr)
        return 1

    if checks_run == 0:
        # This is now acceptable if no data was found.
        # But if config existed and we found no *active* flows, it's just "OK, nothing to do".
        print("[wgx][guard][data_flow] OK: No active data flows found.", file=sys.stderr)
    else:
        print(f"[wgx][guard][data_flow] OK: {checks_run} flow(s) checked.", file=sys.stderr)

    return 0

if __name__ == "__main__":
    sys.exit(main())

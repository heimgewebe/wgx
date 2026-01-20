#!/usr/bin/env python3
"""
guards/data_flow_guard.py

Guard: Validates data flow artifacts against their contracts.
Part of the "Heimgewebe" architecture hardening.

Config:
- Canonical flow definition: '.wgx/flows.json' (or .yaml).
- Supports 'contracts/flows.json' for legacy/transition.
- Format:
  flows:
    <name>:
      schema: "contracts/path/to/schema.json"
      data: ["pattern/to/data.json"]

SSOT Philosophy:
- Schemas referenced in 'schema' path should be either:
  (A) Automatically mirrored schemas from the Metarepo.
  (B) Vendored schemas in a fixed path (e.g. .wgx/contracts/) with strict sync rules.
- Local ad-hoc schemas are discouraged.

Logic:
1. Load configuration (prioritizing .wgx/flows.json).
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
    Load flows configuration.
    Priority:
    1. .wgx/flows.json (Canonical)
    2. .wgx/flows.yaml
    3. contracts/flows.json (Legacy)
    4. contracts/flows.yaml
    """
    candidates = [
        ".wgx/flows.json",
        ".wgx/flows.yaml",
        "contracts/flows.json",
        "contracts/flows.yaml"
    ]

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
        if "**" in pat:
             # Recursive globs are forbidden to prevent unbounded scans.
             # This is a configuration error.
             raise ValueError(f"Recursive glob pattern '{pat}' is forbidden.")

        if "*" in pat:
            # Explicit recursive=False for hardening
            matches = sorted(glob.glob(pat, recursive=False))
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
        print("::notice::[wgx][guard][data_flow] No flow configuration found (checked .wgx/flows.json, contracts/flows.yaml, etc). Skipping.", file=sys.stderr)
        return 0

    flows = config.get("flows", {})
    if not flows:
        print(f"[wgx][guard][data_flow] Config '{config_path}' has no 'flows' defined.", file=sys.stderr)
        return 0

    total_errors = 0
    checks_run = 0

    for flow_name, definition in flows.items():
        schema_rel_path = definition.get("schema")
        data_patterns = definition.get("data")

        if not data_patterns:
            continue

        # 1. Locate Data
        try:
            data_files = resolve_data(data_patterns)
        except ValueError as e:
            print(f"[wgx][guard][data_flow] ERROR flow={flow_name} error='{e}'", file=sys.stderr)
            total_errors += 1
            continue

        if not data_files:
            continue

        # 2. Locate Schema (Strict check)
        if not schema_rel_path:
             print(f"[wgx][guard][data_flow] ERROR flow={flow_name} error='Missing schema definition in config'", file=sys.stderr)
             total_errors += 1
             continue

        if not os.path.exists(schema_rel_path):
             print(f"[wgx][guard][data_flow] FAIL flow={flow_name} files={len(data_files)} error='Schema missing at {schema_rel_path}'", file=sys.stderr)
             total_errors += 1
             continue

        # 3. Load Schema & Validate
        try:
            with open(schema_rel_path, 'r', encoding='utf-8') as f:
                schema = json.load(f)

            schema_abs_path = pathlib.Path(schema_rel_path).resolve()
            base_uri = schema_abs_path.as_uri()

            validator_cls = jsonschema.validators.validator_for(schema)
            # Compatibility wrapper for RefResolver
            try:
                resolver = jsonschema.RefResolver(base_uri=base_uri, referrer=schema)
                validator = validator_cls(schema, resolver=resolver)
            except AttributeError:
                # RefResolver deprecated/removed in newer versions
                # Newer jsonschema might need 'referencing' library or different setup.
                # For now, we attempt basic validation, but warn about potential $ref issues.
                # Ideally, this environment should use a pinned compatible version.
                print(f"[wgx][guard][data_flow] WARN flow={flow_name} error='RefResolver not available (jsonschema version?), references may fail'", file=sys.stderr)
                validator = validator_cls(schema)
            except Exception as e:
                # Other init errors
                print(f"[wgx][guard][data_flow] ERROR flow={flow_name} error='Validator init failed: {e}'", file=sys.stderr)
                total_errors += 1
                continue

        except Exception as e:
            print(f"[wgx][guard][data_flow] ERROR flow={flow_name} schema={schema_rel_path} error='Failed to prepare schema: {e}'", file=sys.stderr)
            total_errors += 1
            continue

        # Log start of check for this flow
        print(f"[wgx][guard][data_flow] CHECK flow={flow_name} files={len(data_files)} schema={schema_rel_path}", file=sys.stderr)

        for df in data_files:
            checks_run += 1
            try:
                items = load_data(df)
            except Exception as e:
                print(f"[wgx][guard][data_flow] ERROR flow={flow_name} data={df} error='Failed to parse data: {e}'", file=sys.stderr)
                total_errors += 1
                continue

            for i, item in enumerate(items):
                item_id = item.get("id", f"item-{i}")
                try:
                    validator.validate(item)
                except jsonschema.ValidationError as e:
                    msg = e.message
                    if len(msg) > 200: msg = msg[:200] + "..."
                    # Single line log format
                    print(f"[wgx][guard][data_flow] FAIL flow={flow_name} schema={schema_rel_path} data={df} id={item_id} error='{msg}'", file=sys.stderr)
                    total_errors += 1

    if total_errors > 0:
        print(f"[wgx][guard][data_flow] FAILED: {total_errors} error(s) found.", file=sys.stderr)
        return 1

    if checks_run == 0:
        print("[wgx][guard][data_flow] OK: No active data flows found.", file=sys.stderr)
    else:
        print(f"[wgx][guard][data_flow] OK: {checks_run} file(s) checked.", file=sys.stderr)

    return 0

if __name__ == "__main__":
    sys.exit(main())

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
      schema: ".wgx/contracts/path/to/schema.json"
      data: ["pattern/to/data.json"]

SSOT Philosophy:
- Schemas referenced in 'schema' path MUST be vendored/mirrored contracts.
- Canonical path: .wgx/contracts/ (vendored) or contracts/ (mirrored).
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

def check_ssot_path(path):
    # Recommend canonical paths for schemas to avoid drift
    if not (path.startswith(".wgx/contracts/") or path.startswith("contracts/")):
        print(f"[wgx][guard][data_flow] WARN schema={path} message='Schema is outside canonical vendor paths (.wgx/contracts/ or contracts/). This may cause drift.'", file=sys.stderr)

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

        # Enforce/Warn SSOT path
        check_ssot_path(schema_rel_path)

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
            validator = None

            # Strict Resolver Strategy: Must support resolution
            try:
                # Legacy: jsonschema < 4.18 (approximately)
                if hasattr(jsonschema, 'RefResolver'):
                    resolver = jsonschema.RefResolver(base_uri=base_uri, referrer=schema)
                    validator = validator_cls(schema, resolver=resolver)
                else:
                    # Modern: jsonschema >= 4.18 should handle local refs if cwd/base_uri is correct?
                    # Or requires `referencing`.
                    # For this guard in a restricted env, we FAIL if we can't guarantee resolution.
                    # Attempt simple init, but if it's missing explicit referencing support logic and RefResolver is gone,
                    # we deem it unsafe for contracts with refs.
                    # Note: Simple validator_cls(schema) in new versions DOES resolve relative refs if URI is proper.
                    # We'll assume if RefResolver is missing, the modern behavior works OR we fail.
                    # But to be STRICT as requested:

                    # If we can't confirm resolution capability, we fail.
                    # However, Validator(schema) in new versions usually works for local refs relative to CWD if no base_uri provided,
                    # or needs Registry.

                    # Strategy: If RefResolver is missing, we try to see if we can use modern `referencing` (not available here).
                    # So we fail if RefResolver is missing? That breaks on modern setups.
                    # Compromise: Try to instantiate. If no RefResolver, warn but proceed ONLY if we trust the env.
                    # BUT prompt says: "FAIL if resolution cannot be guaranteed".

                    # We check:
                    try:
                        # Attempt to construct with a Registry if 'referencing' was importable (not here).
                        # Without 'referencing', we assume old behavior or fail.
                        # Check for RefResolver again.
                        raise ImportError("Modern jsonschema handling requires 'referencing' lib which is not detected/implemented here, and RefResolver is missing.")
                    except ImportError as e:
                         # Re-raise to be caught below
                         raise e

            except ImportError:
                 # This block catches the explicit raise above if RefResolver was missing.
                 print(f"[wgx][guard][data_flow] ERROR flow={flow_name} error='Strict $ref resolution required. RefResolver missing and no modern fallback available.'", file=sys.stderr)
                 total_errors += 1
                 continue
            except Exception as e:
                # Catch instantiation errors
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

#!/usr/bin/env python3
"""
guards/data_flow_guard.py

Guard: Validates data flow artifacts against their contracts.
Part of the "Heimgewebe" architecture hardening.

Config:
- Canonical flow definition: '.wgx/flows.json' (or .yaml/.yml).
- Supports 'contracts/flows.json' for legacy/transition.
- Format (Array of Objects):
  [
    {
      "name": "my_flow",
      "schema_path": ".wgx/contracts/my_schema.json",
      "data_pattern": ["artifacts/*.json"]
    }
  ]

SSOT Philosophy:
- Schemas referenced in 'schema_path' MUST be vendored/mirrored contracts.
- Canonical path: .wgx/contracts/ (vendored) or contracts/ (mirrored).
- Local ad-hoc schemas are discouraged.

Strict Mode & Policy:
- WGX_STRICT=1: Missing dependencies (jsonschema) -> FAIL (Exit 1).
- Default: Missing dependencies -> SKIP (Exit 0).
- DATA_FLOW_GUARD_DATA_CACHE_MAX: Integer (default 256). Controls LRU cache size for data files.
  - Set to 0 to disable data caching.
- Reference Resolution ($ref):
  - If schema uses $ref and no resolver (RefResolver) is available -> ALWAYS FAIL (Exit 1).
  - This prevents false negatives/security theatre.
  - Currently supports `jsonschema.RefResolver` (Legacy). Modern `referencing` support is planned but not active.
  - TODO: Migration von RefResolver -> referencing (jsonschema >=4)

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
import collections
import urllib.request
import urllib.parse

# Try imports
try:
    import jsonschema
except ImportError:
    jsonschema = None

try:
    from referencing import Registry, Resource
    from referencing.exceptions import Unresolvable
    from referencing.jsonschema import DRAFT202012
    HAS_REFERENCING = True
except ImportError:
    HAS_REFERENCING = False
    Registry = None
    Resource = None
    DRAFT202012 = None
    Unresolvable = None

try:
    from guards._util import safe_item_id
except ImportError:
    from _util import safe_item_id

try:
    import yaml
except ImportError:
    yaml = None

def is_strict():
    return os.environ.get("WGX_STRICT") == "1"

def create_retriever(base_dir, allowed_roots):
    """
    Factory for a retrieve function that enforces root-jail.
    Only allows access to files within the specified allowed_roots.
    Resolves relative paths against base_dir.
    """
    # Normalize roots to absolute real paths for robust comparison (symlink-safe)
    roots = [os.path.realpath(os.path.abspath(r)) for r in allowed_roots]
    base_dir_abs = os.path.realpath(os.path.abspath(base_dir))

    def retrieve(uri):
        if not HAS_REFERENCING:
            raise RuntimeError("retrieve called but referencing is not available")

        parsed = urllib.parse.urlparse(uri)

        if parsed.scheme not in ("", "file"):
            raise ValueError(f"Network/Unsupported reference forbidden: {uri}")

        # Check for non-empty netloc in file URIs (indicates remote server/UNC path)
        if parsed.scheme == "file" and parsed.netloc:
            raise ValueError(f"Network reference (UNC/remote) forbidden: {uri}")

        # Resolve local path
        if parsed.scheme == "file":
            path = urllib.request.url2pathname(parsed.path)
        else:
            # Relative path: resolve against base_dir, NOT cwd
            if not os.path.isabs(parsed.path):
                path = os.path.join(base_dir_abs, parsed.path)
            else:
                path = parsed.path

        # Normalize and make absolute real path (resolve symlinks)
        abs_path = os.path.realpath(os.path.abspath(path))

        # Enforce Root Jail
        allowed = False
        for root in roots:
            # os.path.commonpath returns the longest common sub-path.
            # If the file is inside root, commonpath([root, file]) should be root.
            try:
                if os.path.commonpath([root, abs_path]) == root:
                    allowed = True
                    break
            except ValueError:
                # Can happen on Windows if drives match/don't match confusingly
                continue

        if not allowed:
            # We wrap this in Unresolvable so referencing handles it gracefully (or fails if strict)
            raise Unresolvable(ref=uri)

        try:
            with open(abs_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
                return Resource.from_contents(data, default_specification=DRAFT202012)
        except Exception as e:
            raise Unresolvable(ref=uri) from e

    return retrieve

def load_config():
    """
    Load flows configuration.
    Priority:
    1. .wgx/flows.json (Canonical)
    2. .wgx/flows.yaml / .yml
    3. contracts/flows.json (Legacy)
    4. contracts/flows.yaml / .yml
    """
    candidates = [
        ".wgx/flows.json",
        ".wgx/flows.yaml",
        ".wgx/flows.yml",
        "contracts/flows.json",
        "contracts/flows.yaml",
        "contracts/flows.yml"
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
        # Try JSON first
        try:
            data = json.load(f)
            if isinstance(data, list):
                return data
            elif isinstance(data, dict):
                return [data]
            else:
                raise ValueError("File content must be a JSON object or array")
        except json.JSONDecodeError:
            # Try JSONL
            f.seek(0)
            items = []

            # Empty/whitespace file yields [] (treated as empty JSONL).
            for i, line in enumerate(f):
                line = line.strip()
                if not line:
                    continue
                try:
                    items.append(json.loads(line))
                except json.JSONDecodeError as e:
                    # Provide clearer error context for operator
                    raise ValueError(f"Line {i+1}: invalid JSON: {e}")

            return items

def resolve_data(patterns):
    files = []
    if isinstance(patterns, str):
        patterns = [patterns]

    if not patterns:
        return []

    for pat in patterns:
        if "**" in pat:
             # Recursive globs are forbidden to prevent unbounded scans.
             raise ValueError(f"Recursive glob pattern '{pat}' is forbidden.")

        if "*" in pat:
            matches = sorted(glob.glob(pat, recursive=False))
            files.extend(matches)
        else:
            if os.path.exists(pat):
                files.append(pat)
    return sorted(list(set(files)))

def check_ssot_path(path):
    if not (path.startswith(".wgx/contracts/") or path.startswith("contracts/")):
        print(f"[wgx][guard][data_flow] WARN schema={path} message='Schema is outside canonical vendor paths (.wgx/contracts/ or contracts/). This may cause drift.'", file=sys.stderr)

def has_ref(schema_obj):
    """Recursively check if schema object contains '$ref' key."""
    if isinstance(schema_obj, dict):
        if "$ref" in schema_obj:
            return True
        for v in schema_obj.values():
            if has_ref(v):
                return True
    elif isinstance(schema_obj, list):
        for item in schema_obj:
            if has_ref(item):
                return True
    return False

def main():
    if jsonschema is None:
        if is_strict():
            print("::error::[wgx][guard][data_flow] Strict mode enabled (WGX_STRICT=1) but 'jsonschema' is missing.", file=sys.stderr)
            return 1
        print("::notice::[wgx][guard][data_flow] SKIP: jsonschema not installed", file=sys.stderr)
        return 0

    config, config_path = load_config()

    if not config:
        print("::notice::[wgx][guard][data_flow] No flow configuration found (checked .wgx/flows.json, contracts/flows.yaml, etc). Skipping.", file=sys.stderr)
        return 0

    # Parse config: Expect list or dict with "flows" key
    flows = []
    if isinstance(config, list):
        flows = config
    elif isinstance(config, dict) and "flows" in config:
        f = config["flows"]
        if isinstance(f, list):
            flows = f
        elif isinstance(f, dict):
            for k, v in f.items():
                item = v.copy()
                item["name"] = k
                if "schema" in item and "schema_path" not in item:
                    item["schema_path"] = item["schema"]
                if "data" in item and "data_pattern" not in item:
                    item["data_pattern"] = item["data"]
                flows.append(item)
    else:
        print(f"[wgx][guard][data_flow] Config '{config_path}' has invalid format. Expected List of Objects or Object with 'flows' key.", file=sys.stderr)
        return 1

    if not flows:
        print(f"[wgx][guard][data_flow] Config '{config_path}' defines no flows.", file=sys.stderr)
        return 0

    # Cache for loaded schemas/validators to avoid redundant parsing
    # Key: Absolute path string, Value: validator instance
    schema_cache = {}

    # Cache for loaded data files to avoid redundant I/O and parsing
    # Key: Absolute path string, Value: items (tuple)
    # LRU Strategy: bounded size to prevent unbounded memory growth
    data_cache = collections.OrderedDict()
    data_cache_max = 256
    try:
        if "DATA_FLOW_GUARD_DATA_CACHE_MAX" in os.environ:
             val = int(os.environ["DATA_FLOW_GUARD_DATA_CACHE_MAX"])
             data_cache_max = max(0, val)
    except ValueError:
        invalid_val = os.environ.get("DATA_FLOW_GUARD_DATA_CACHE_MAX", "")
        print(f"[wgx][guard][data_flow] WARN invalid DATA_FLOW_GUARD_DATA_CACHE_MAX='{invalid_val}', using default 256", file=sys.stderr)
        data_cache_max = 256

    total_errors = 0
    checks_run = 0

    for definition in flows:
        flow_name = definition.get("name", "unnamed_flow")

        schema_rel_path = definition.get("schema_path") or definition.get("schema")
        data_patterns = definition.get("data_pattern") or definition.get("data")

        if not data_patterns:
            continue

        try:
            data_files = resolve_data(data_patterns)
        except ValueError as e:
            print(f"[wgx][guard][data_flow] ERROR flow={flow_name} error='{e}'", file=sys.stderr)
            total_errors += 1
            continue

        if not data_files:
            continue

        if not schema_rel_path:
             print(f"[wgx][guard][data_flow] ERROR flow={flow_name} error='Missing schema_path definition in config'", file=sys.stderr)
             total_errors += 1
             continue

        check_ssot_path(schema_rel_path)

        if not os.path.exists(schema_rel_path):
             print(f"[wgx][guard][data_flow] FAIL flow={flow_name} files={len(data_files)} error='Schema missing at {schema_rel_path}'", file=sys.stderr)
             total_errors += 1
             continue

        # 3. Load Schema & Validate
        try:
            schema_abs_path = pathlib.Path(schema_rel_path).resolve()
            schema_key = str(schema_abs_path)

            if schema_key in schema_cache:
                validator = schema_cache[schema_key]
            else:
                with open(schema_abs_path, 'r', encoding='utf-8') as f:
                    schema = json.load(f)

                base_uri = schema_abs_path.as_uri()

                validator_cls = jsonschema.validators.validator_for(schema)
                validator = None

                try:
                    # 1. Try referencing (New, jsonschema >= 4.18)
                    if HAS_REFERENCING:
                        # Ensure schema has an ID matching its file path so relative refs resolve correctly
                        if "$id" not in schema:
                            # Create a copy to avoid side effects on cached schema or re-runs
                            schema = dict(schema)
                            schema["$id"] = base_uri

                        resource = Resource.from_contents(schema, default_specification=DRAFT202012)

                        # Define allowed roots for $ref resolution
                        # 1. The directory of the current schema (for relative refs)
                        schema_dir = os.path.dirname(str(schema_abs_path))
                        allowed_roots = [schema_dir]

                        # 2. Canonical contract roots (if they exist)
                        # This allows schemas to reference shared contracts in .wgx/contracts or contracts
                        cwd = os.getcwd()
                        for d in [".wgx/contracts", "contracts"]:
                            d_abs = os.path.abspath(os.path.join(cwd, d))
                            if os.path.exists(d_abs):
                                allowed_roots.append(d_abs)

                        retrieve = create_retriever(base_dir=schema_dir, allowed_roots=allowed_roots)
                        registry = Registry(retrieve=retrieve).with_resource(base_uri, resource)
                        validator = validator_cls(schema, registry=registry)

                    # 2. Try RefResolver (Legacy)
                    elif hasattr(jsonschema, 'RefResolver'):
                        resolver = jsonschema.RefResolver(base_uri=base_uri, referrer=schema)
                        validator = validator_cls(schema, resolver=resolver)
                    else:
                        # Missing RefResolver.
                        if has_ref(schema):
                             # If schema uses refs but we lack resolver capability -> HARD FAIL always.
                             raise ImportError("RefResolver missing and schema uses $ref. Resolution capability required.")
                        else:
                            # Safe to proceed without resolver for simple schemas
                            validator = validator_cls(schema)

                    schema_cache[schema_key] = validator

                except ImportError as e:
                     print(f"[wgx][guard][data_flow] ERROR flow={flow_name} error='{e}'", file=sys.stderr)
                     total_errors += 1
                     continue
                except Exception as e:
                    print(f"[wgx][guard][data_flow] ERROR flow={flow_name} error='Validator init failed: {e}'", file=sys.stderr)
                    total_errors += 1
                    continue

        except Exception as e:
            print(f"[wgx][guard][data_flow] ERROR flow={flow_name} schema={schema_rel_path} error='Failed to prepare schema: {e}'", file=sys.stderr)
            total_errors += 1
            continue

        print(f"[wgx][guard][data_flow] CHECK flow={flow_name} files={len(data_files)} schema={schema_rel_path}", file=sys.stderr)

        for df in data_files:
            checks_run += 1

            try:
                # Use absolute path for reliable caching
                df_abs_path = str(pathlib.Path(df).resolve())

                # LRU Cache Logic
                if data_cache_max > 0:
                    if df_abs_path in data_cache:
                        items = data_cache[df_abs_path]
                        data_cache.move_to_end(df_abs_path)
                    else:
                        # Load data and cache as immutable tuple to prevent side effects
                        loaded_items = load_data(df)
                        items = tuple(loaded_items)

                        # Evict oldest if full
                        if len(data_cache) >= data_cache_max:
                            data_cache.popitem(last=False)

                        data_cache[df_abs_path] = items
                else:
                    # Caching disabled
                    items = load_data(df)

            except Exception as e:
                print(f"[wgx][guard][data_flow] ERROR flow={flow_name} data={df} error='Failed to parse data: {e}'", file=sys.stderr)
                total_errors += 1
                continue

            for i, item in enumerate(items):
                try:
                    validator.validate(item)
                except jsonschema.ValidationError as e:
                    # Safe ID extraction
                    item_id = safe_item_id(item, i)
                    msg = e.message
                    if len(msg) > 200: msg = msg[:200] + "..."
                    print(f"[wgx][guard][data_flow] FAIL flow={flow_name} schema={schema_rel_path} data={df} id={item_id} error='{msg}'", file=sys.stderr)
                    total_errors += 1
                except Exception as e:
                    # Catch unexpected validation crashes
                    item_id = safe_item_id(item, i)
                    exc_type = type(e).__name__
                    msg = str(e)
                    if len(msg) > 200: msg = msg[:200] + "..."
                    print(f"[wgx][guard][data_flow] ERROR flow={flow_name} schema={schema_rel_path} data={df} id={item_id} error='Validator error ({exc_type}): {msg}'", file=sys.stderr)
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

#!/usr/bin/env python3
"""
WGX Profile Parser (Fallback)

This script parses .wgx/profile.yml files when PyYAML is not available.
It implements a minimal subset of block-style YAML necessary for wgx profiles.
It does NOT support the full YAML specification (e.g. flow style, complex keys, anchors).
"""
import ast
import json
import os
import re
import shlex
import sys
from typing import Any, Dict, List, Optional, Tuple, Union

# --- YAML Parser (Minimal Subset) ---

def _parse_scalar(value: str) -> Any:
    text = value.strip()
    if text == "":
        return ""
    lowered = text.lower()
    if lowered in {"true", "yes", "on"}:
        return True
    if lowered in {"false", "no", "off"}:
        return False
    if lowered in {"null", "none", "~"}:
        return None
    try:
        return ast.literal_eval(text)
    except Exception:
        return text

def _convert_frame(frame: Dict[str, Any], kind: str) -> None:
    if frame["type"] == kind:
        return
    parent = frame["parent"]
    key = frame["key"]
    if kind == "list":
        new_value: List[Any] = []
        if parent is None:
            frame["container"] = new_value
        elif isinstance(parent, list):
            parent[key] = new_value
        else:
            parent[key] = new_value
        frame["container"] = new_value
        frame["type"] = "list"
    else:
        new_value_dict: Dict[str, Any] = {}
        if parent is None:
            frame["container"] = new_value_dict
        elif isinstance(parent, list):
            parent[key] = new_value_dict
        else:
            parent[key] = new_value_dict
        frame["container"] = new_value_dict
        frame["type"] = "dict"

def _strip_inline_comment(line: str) -> str:
    result: List[str] = []
    in_single = False
    in_double = False
    i = 0
    length = len(line)
    while i < length:
        ch = line[i]
        if in_single:
            result.append(ch)
            if ch == "'" and (i + 1 >= length or line[i + 1] != "'"):
                in_single = False
            elif ch == "'" and i + 1 < length and line[i + 1] == "'":
                result.append(line[i + 1])
                i += 1
            i += 1
            continue
        if in_double:
            result.append(ch)
            if ch == '"' and (i == 0 or line[i - 1] != "\\"):
                in_double = False
            i += 1
            continue
        if ch == "'":
            in_single = True
            result.append(ch)
            i += 1
            continue
        if ch == '"':
            in_double = True
            result.append(ch)
            i += 1
            continue
        if ch == '#':
            if i == 0 or line[i - 1] in " \t":
                break
        result.append(ch)
        i += 1
    return ''.join(result)

def _split_key_value(text: str) -> Optional[Tuple[str, str]]:
    in_single = False
    in_double = False
    escape = False
    i = 0
    length = len(text)
    while i < length:
        ch = text[i]
        if in_single:
            if ch == "'" and i + 1 < length and text[i + 1] == "'":
                i += 2
                continue
            if ch == "'":
                in_single = False
            i += 1
            continue
        if in_double:
            if escape:
                escape = False
                i += 1
                continue
            if ch == "\\":
                escape = True
                i += 1
                continue
            if ch == '"':
                in_double = False
            i += 1
            continue
        if ch == "'":
            in_single = True
            i += 1
            continue
        if ch == '"':
            in_double = True
            i += 1
            continue
        if ch == ":":
            if i + 1 >= length or text[i + 1] in " \t":
                return text[:i], text[i + 1 :]
        i += 1
    return None

def _parse_simple_yaml(path: str) -> Any:
    root: Dict[str, Any] = {}
    stack: List[Dict[str, Any]] = [
        {"indent": -1, "container": root, "parent": None, "key": None, "type": "dict"}
    ]

    with open(path, "r", encoding="utf-8") as handle:
        for raw_line in handle:
            line = raw_line.rstrip("\n")
            stripped = _strip_inline_comment(line).rstrip()
            if not stripped:
                continue
            indent = len(line) - len(line.lstrip(" "))
            content = stripped.lstrip()

            while len(stack) > 1 and indent <= stack[-1]["indent"]:
                stack.pop()

            frame = stack[-1]
            container = frame["container"]

            if content.startswith("- "):
                value_part = content[2:].strip()
                _convert_frame(frame, "list")
                container = frame["container"]
                if not value_part:
                    item: Dict[str, Any] = {}
                    container.append(item)
                    stack.append(
                        {
                            "indent": indent,
                            "container": item,
                            "parent": container,
                            "key": len(container) - 1,
                            "type": "dict",
                        }
                    )
                    continue
                split = _split_key_value(value_part)
                if split is not None:
                    key, rest = split
                    key = key.strip().strip("'\"")
                    rest = rest.strip()
                    item = {}
                    container.append(item)
                    frame_item = {
                        "indent": indent,
                        "container": item,
                        "parent": container,
                        "key": len(container) - 1,
                        "type": "dict",
                    }
                    stack.append(frame_item)
                    if rest:
                        item[key] = _parse_scalar(rest)
                    else:
                        item[key] = {}
                        stack.append(
                            {
                                "indent": indent,
                                "container": item[key],
                                "parent": item,
                                "key": key,
                                "type": "dict",
                            }
                        )
                    continue
                container.append(_parse_scalar(value_part))
                continue

            split = _split_key_value(content)
            if split is not None:
                key, value_part = split
                key = key.strip().strip("'\"")
                value_part = value_part.strip()
                _convert_frame(frame, "dict")
                container = frame["container"]
                if value_part == "":
                    container[key] = {}
                    stack.append(
                        {
                            "indent": indent,
                            "container": container[key],
                            "parent": container,
                            "key": key,
                            "type": "dict",
                        }
                    )
                else:
                    container[key] = _parse_scalar(value_part)
                continue

            if isinstance(container, list):
                container.append(_parse_scalar(content))
            elif isinstance(container, dict):
                container[content] = True

    return root

def _load_manifest(path: str) -> Any:
    _, ext = os.path.splitext(path)
    ext = ext.lower()
    if ext in {".yaml", ".yml"}:
        try:
            import yaml  # type: ignore
        except Exception:
            try:
                return _parse_simple_yaml(path)
            except Exception:
                return {}
        with open(path, "r", encoding="utf-8") as handle:
            return yaml.safe_load(handle) or {}
    if ext == ".json":
        with open(path, "r", encoding="utf-8") as handle:
            return json.load(handle) or {}
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle) or {}

# --- Platform Selection & Helpers ---

platform_keys = []
plat = sys.platform
if plat.startswith('darwin'):
    platform_keys.append('darwin')
elif plat.startswith('linux'):
    platform_keys.append('linux')
elif plat.startswith('win'):
    platform_keys.append('win32')
elif plat.startswith('cygwin') or plat.startswith('msys'):
    platform_keys.append('win32')
platform_keys.append('default')

def select_variant(value: Any) -> Any:
    if isinstance(value, dict):
        for key in platform_keys:
            if key in value and value[key] not in (None, ''):
                return value[key]
        for entry in value.values():
            if entry not in (None, ''):
                return entry
        return None
    return value

def as_bool(value: Any) -> bool:
    if isinstance(value, bool):
        return value
    if isinstance(value, int):
        return value != 0
    if isinstance(value, str):
        return value.strip().lower() in ("1", "true", "yes", "on")
    return False

def emit(line: str) -> None:
    sys.stdout.write(f"{line}\n")

def shell_quote(value: str) -> str:
    return shlex.quote(value)

def emit_var(name: str, value: Any) -> None:
    sval = '' if value is None else str(value)
    emit(f"{name}={shell_quote(sval)}")

def emit_env(prefix: str, mapping: Any) -> None:
    if not isinstance(mapping, dict):
        return
    for key, val in mapping.items():
        if key is None:
            continue
        skey = str(key)
        emit_var(f"{prefix}_{skey}", val)

def emit_caps(caps: Any) -> None:
    if not isinstance(caps, (list, tuple)):
        return
    for cap in caps:
        if cap is None:
            continue
        emit(f"WGX_REQUIRED_CAPS+=({shell_quote(str(cap))})")

# --- Configuration Logic ---

def get_config(data: Dict, wgx: Dict, key: str, default: Any = None, aliases: Optional[List[str]] = None, check_type: Any = None) -> Tuple[Any, bool]:
    """
    Retrieves a configuration value with priority:
    1. wgx[key]
    2. wgx[alias] (for each alias)
    3. root[key] (fallback)
    4. root[alias] (fallback)

    Returns (value, used_fallback_flag)
    """
    val = None
    fallback = False

    # Check wgx block
    if isinstance(wgx, dict):
        val = wgx.get(key)
        if val is None and aliases:
            for alias in aliases:
                val = wgx.get(alias)
                if val is not None:
                    break

    # Check root fallback
    if val is None and isinstance(data, dict):
        val = data.get(key)
        if val is not None:
            fallback = True
        elif aliases:
            for alias in aliases:
                val = data.get(alias)
                if val is not None:
                    fallback = True
                    break

    if val is None:
        val = default

    # Optional type check (if value is found but wrong type, revert to default)
    if check_type and val is not None:
        if not isinstance(val, check_type):
             # If root fallback failed type check, we don't count it as a valid usage?
             # But here we just want to ensure we return a safe type.
             # If we fell back to root and it was wrong type, we essentially didn't find a valid value.
             if fallback:
                 fallback = False # Reset flag if invalid
             val = default

    return val, fallback

def main():
    if len(sys.argv) < 2:
        sys.stderr.write("Usage: profile_parser.py <profile_file>\n")
        sys.exit(1)

    path = sys.argv[1]
    data = _load_manifest(path) or {}

    wgx = data.get('wgx')
    if not isinstance(wgx, dict):
        wgx = {}

    used_root_fallback = False

    # apiVersion
    api_version, _ = get_config(data, wgx, 'apiVersion', default='v1')
    emit_var("PROFILE_VERSION", api_version)

    # requiredWgx (supports aliases)
    req, fb = get_config(data, wgx, 'requiredWgx', aliases=['required-wgx'])
    if fb: used_root_fallback = True

    if isinstance(req, str):
        emit_var("WGX_REQUIRED_RANGE", req)
    elif isinstance(req, dict):
        emit_var("WGX_REQUIRED_RANGE", req.get('range'))
        emit_var("WGX_REQUIRED_MIN", req.get('min'))
        emit_caps(req.get('caps'))
    else:
        emit_caps([])

    # repoKind
    repo_kind, fb = get_config(data, wgx, 'repoKind', default='')
    if fb: used_root_fallback = True
    emit_var("WGX_REPO_KIND", repo_kind)

    # dirs
    dirs, fb = get_config(data, wgx, 'dirs', default={}, check_type=dict)
    if fb: used_root_fallback = True
    emit_var("WGX_DIR_WEB", dirs.get('web'))
    emit_var("WGX_DIR_API", dirs.get('api'))
    emit_var("WGX_DIR_DATA", dirs.get('data'))

    # envDefaults
    env_defaults, fb = get_config(data, wgx, 'envDefaults', default={}, check_type=dict)
    if fb: used_root_fallback = True
    emit_env('WGX_ENV_DEFAULT_MAP', env_defaults)

    # env (base)
    env_base, fb = get_config(data, wgx, 'env', default={}, check_type=dict)
    if fb: used_root_fallback = True
    emit_env('WGX_ENV_BASE_MAP', env_base)

    # envOverrides
    env_overrides, fb = get_config(data, wgx, 'envOverrides', default={}, check_type=dict)
    if fb: used_root_fallback = True
    emit_env('WGX_ENV_OVERRIDE_MAP', env_overrides)

    # workflows
    workflows, fb = get_config(data, wgx, 'workflows', default={}, check_type=dict)
    if fb: used_root_fallback = True

    for wf_name, wf_spec in workflows.items():
        steps = []
        if isinstance(wf_spec, dict):
            for step in wf_spec.get('steps') or []:
                if isinstance(step, dict):
                    task_name = step.get('task')
                    if task_name:
                        steps.append(str(task_name))
        safe_name = re.sub(r'[^A-Za-z0-9_]', '_', str(wf_name))
        emit_var(f"WGX_WORKFLOW_TASKS_{safe_name}", ' '.join(steps))

    # tasks
    tasks, fb = get_config(data, wgx, 'tasks', default={}, check_type=dict)
    # Special case: if tasks is empty dict, try fallback
    if not tasks:
        # Retry with force root lookup if main one failed/was empty
        root_tasks = data.get('tasks')
        if isinstance(root_tasks, dict) and root_tasks:
            tasks = root_tasks
            used_root_fallback = True
    elif fb:
         used_root_fallback = True

    seen_task_order = set()
    norm_to_name: Dict[str, str] = {}

    for raw_name, spec in tasks.items():
        name = str(raw_name)
        norm = re.sub(r'-+', '-', name.replace(' ', '').replace('_', '-').lower())

        if norm in norm_to_name and norm_to_name[norm] != name:
            sys.stderr.write(f"wgx: error: task name collision: '{norm_to_name[norm]}' vs '{name}'\n")
            sys.exit(3)
        norm_to_name[norm] = name

        safe_name = norm.replace('-', '_')
        if norm not in seen_task_order:
            emit(f"WGX_TASK_ORDER+=({shell_quote(norm)})")
            seen_task_order.add(norm)

        desc = ''
        group = ''
        safe = False
        cmd_value = spec
        args_value = None

        if isinstance(spec, dict):
            desc = spec.get('desc') or ''
            group = spec.get('group') or ''
            safe = as_bool(spec.get('safe'))
            cmd_value = spec.get('cmd')
            args_value = spec.get('args')

        selected_cmd = select_variant(cmd_value)

        tokens = []
        base_cmd = None
        use_array_format = False

        if isinstance(selected_cmd, (list, tuple)):
            tokens = [str(item) for item in selected_cmd]
            use_array_format = True
        elif isinstance(selected_cmd, str) and selected_cmd.strip():
            base_cmd = selected_cmd
        elif selected_cmd not in (None, ''):
            tokens = [str(selected_cmd)]

        appended_args = []
        if isinstance(args_value, (list, tuple)) and args_value:
            appended_args.extend(str(item) for item in args_value)
        elif isinstance(args_value, dict):
            variant = select_variant(args_value)
            if isinstance(variant, (list, tuple)):
                appended_args.extend(str(item) for item in variant)
            elif variant not in (None, ''):
                appended_args.append(str(variant))

        if use_array_format:
            if appended_args:
                tokens.extend(appended_args)
            payload = json.dumps(tokens, ensure_ascii=False)
            emit_var(f"WGX_TASK_CMDS_{safe_name}", 'ARRJSON:' + payload)
        else:
            if base_cmd is not None:
                command_parts = [base_cmd]
                if appended_args:
                    command_parts.extend(shlex.quote(str(a)) for a in appended_args)
                command = ' '.join(command_parts)
            else:
                all_parts = tokens + appended_args
                command = ' '.join(shlex.quote(str(p)) for p in all_parts)
            emit_var(f"WGX_TASK_CMDS_{safe_name}", 'STR:' + command)

        emit_var(f"WGX_TASK_DESC_{safe_name}", desc)
        emit_var(f"WGX_TASK_GROUP_{safe_name}", group)
        emit_var(f"WGX_TASK_SAFE_{safe_name}", '1' if safe else '0')

    if used_root_fallback and os.environ.get("WGX_PROFILE_DEPRECATION", "warn") != "quiet":
        print("wgx: note: using root-level profile keys for backwards compatibility; consider nesting under 'wgx.'", file=sys.stderr)

if __name__ == "__main__":
    main()

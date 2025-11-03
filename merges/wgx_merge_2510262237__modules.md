### 📄 modules/.gitkeep

**Größe:** 0 B | **md5:** `d41d8cd98f00b204e9800998ecf8427e`

```plaintext

```

### 📄 modules/doctor.bash

**Größe:** 820 B | **md5:** `a958c1fb9af2d24cdc5f1a53f9a751e4`

```bash
#!/usr/bin/env bash

# Doctor module: basic repository health checks

doctor_cmd() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    cat <<'USAGE'
Usage:
  wgx doctor

Description:
  Führt eine grundlegende Diagnose des Repositorys und der Umgebung durch.
  Prüft, ob 'git' installiert ist, ob der Befehl innerhalb eines Git-Worktrees
  ausgeführt wird und ob ein 'origin'-Remote konfiguriert ist.

Options:
  -h, --help    Diese Hilfe anzeigen.
USAGE
    return 0
  fi

  if ! command -v git >/dev/null 2>&1; then
    echo "❌ git fehlt." >&2
    return 1
  fi

  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "❌ nicht im Git-Repo." >&2
    return 1
  fi

  if ! git remote -v | grep -q '^origin'; then
    echo "⚠️ Kein origin-Remote." >&2
  fi

  echo "✅ WGX Doctor OK."
}
```

### 📄 modules/env.bash

**Größe:** 5 KB | **md5:** `375c3b2fac777ac9a2975ff139910daf`

```bash
#!/usr/bin/env bash
set -e
set -u
set -E
if ! set -o pipefail 2>/dev/null; then
  if [[ ${WGX_DEBUG:-0} != 0 ]]; then
    echo "env module: 'pipefail' wird nicht unterstützt; fahre ohne fort." >&2
  fi
fi

export LC_ALL="${LC_ALL:-C}"

# Environment inspection utilities.

env::_detect_platform() {
  local name
  if command -v uname >/dev/null 2>&1; then
    name="$(uname -s 2>/dev/null || echo unknown)"
  else
    name="unknown"
  fi
  printf '%s' "$name"
}

env::_is_termux() {
  [[ -n ${TERMUX_VERSION:-} ]] && return 0
  [[ ${PREFIX:-} == */com.termux/* ]] && return 0
  [[ -n ${ANDROID_ROOT:-} && -n ${ANDROID_DATA:-} ]] && [[ ${HOME:-} == */com.termux/* ]] && return 0
  return 1
}

env::_have() {
  command -v "$1" >/dev/null 2>&1
}

env::_tool_status() {
  local tool="$1" label="${2:-$1}"
  shift 2 || true
  if env::_have "$tool"; then
    local version=""
    if (($#)); then
      version="$("$@" 2>/dev/null | head -n1 | tr -d '\r')"
    fi
    if [[ -n $version ]]; then
      printf '• %s: available (%s)\n' "$label" "$version"
    else
      printf '• %s: available\n' "$label"
    fi
  else
    printf '• %s: missing\n' "$label"
  fi
}

env::_doctor_report() {
  local platform
  platform="$(env::_detect_platform)"
  printf '=== wgx env doctor (%s) ===\n' "$platform"
  printf 'WGX_DIR : %s\n' "${WGX_DIR:-$(pwd)}"
  printf 'OFFLINE : %s\n' "${OFFLINE:-0}"
  env::_tool_status git "git" git --version
  env::_tool_status gh "gh" gh --version
  env::_tool_status glab "glab" glab --version
  env::_tool_status node "node" node --version
  env::_tool_status npm "npm" npm --version
  env::_tool_status python3 "python3" python3 --version
  env::_tool_status uv "uv" uv --version
  env::_tool_status docker "docker" docker --version
  printf '\nPaths:\n'
  printf '  PATH: %s\n' "${PATH:-}"
}

env::_json_escape() {
  local s="${1-}"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '"%s"' "$s"
}

env::_doctor_json() {
  printf '{'
  printf '"platform":'
  env::_json_escape "$(env::_detect_platform)"
  printf ',"offline":'
  env::_json_escape "${OFFLINE:-0}"
  printf ',"tools":{'
  local first=1
  local tool
  for tool in git gh glab node npm python3 uv docker; do
    local have="missing" ver=""
    if env::_have "$tool"; then
      have="available"
      case "$tool" in
      git) ver="$(git --version 2>/dev/null | head -n1)" ;;
      gh) ver="$(gh --version 2>/dev/null | head -n1)" ;;
      glab) ver="$(glab --version 2>/dev/null | head -n1)" ;;
      node) ver="$(node --version 2>/dev/null | head -n1)" ;;
      npm) ver="$(npm --version 2>/dev/null | head -n1)" ;;
      python3) ver="$(python3 --version 2>/dev/null | head -n1)" ;;
      uv) ver="$(uv --version 2>/dev/null | head -n1)" ;;
      docker) ver="$(docker --version 2>/dev/null | head -n1)" ;;
      esac
    fi
    ((first)) || printf ','
    first=0
    printf '"%s":{' "$tool"
    printf '"status":'
    env::_json_escape "$have"
    printf ',"version":'
    env::_json_escape "$ver"
    printf '}'
  done
  printf '},"path":'
  env::_json_escape "${PATH:-}"
  printf '}'
  printf '\n'
}

env::_termux_fixups() {
  local rc=0
  if ! env::_have git; then
    warn "git is not available – unable to apply git defaults."
    return 1
  fi

  if git config --global --get core.filemode >/dev/null 2>&1; then
    log_info "git core.filemode already configured."
  else
    if git config --global core.filemode false >/dev/null 2>&1; then
      log_info "Configured git core.filemode=false for Termux."
    else
      warn "Failed to configure git core.filemode for Termux."
      rc=1
    fi
  fi

  return $rc
}

env::_fix_unsupported_msg() {
  printf '%s\n' "--fix is currently only supported on Termux"
}

env::_apply_fixes() {
  if env::_is_termux; then
    if env::_termux_fixups; then
      ok "Termux fixes applied."
      return 0
    fi
    warn "Some Termux fixes failed."
    return 1
  fi

  env::_fix_unsupported_msg
  return 0
}

env_cmd() {
  local sub="doctor" fix=0 strict=0 json=0
  local apply_fixes=0

  while (($#)); do
    case "$1" in
    doctor)
      sub="doctor"
      ;;
    --fix)
      fix=1
      ;;
    --strict)
      strict=1
      ;;
    --json)
      json=1
      ;;
    -h | --help)
      cat <<'USAGE'
Usage: wgx env doctor [--fix] [--strict] [--json]
  doctor     Inspect the local environment (default)
  --fix      Apply recommended platform specific tweaks (Termux only)
  --strict   Exit non-zero if essential tools are missing (e.g., git)
  --json     Machine-readable output (minimal JSON)
USAGE
      return 0
      ;;
    --)
      shift
      break
      ;;
    *)
      die "Usage: wgx env doctor [--fix] [--strict] [--json]"
      ;;
    esac
    shift
  done

  if ((fix)); then
    if env::_is_termux; then
      apply_fixes=1
    else
      env::_fix_unsupported_msg
    fi
  fi

  case "$sub" in
  doctor)
    if ((json)); then
      env::_doctor_json
    else
      env::_doctor_report
    fi
    if ((apply_fixes)); then
      env::_apply_fixes || return $?
    fi
    if [[ $strict -ne 0 ]]; then
      if ! env::_have git; then
        warn "git missing (strict mode)"
        return 2
      fi
    fi
    return 0
    ;;
  *)
    die "Usage: wgx env doctor [--fix] [--strict] [--json]"
    ;;
  esac
}

wgx_command_main() {
  env_cmd "$@"
}
```

### 📄 modules/guard.bash

**Größe:** 4 KB | **md5:** `3685345b73710f7536b20fb86df0915e`

```bash
#!/usr/bin/env bash

# Guard-Modul: Lint- und Testläufe (aus Monolith portiert)

_guard_command_available() {
  local name="$1"
  if declare -F "cmd_${name}" >/dev/null 2>&1; then
    return 0
  fi
  local base_dir="${WGX_DIR:-"$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"}"
  [[ -r "${base_dir}/cmd/${name}.bash" ]]
}

_guard_require_file() {
  local path="$1" message="$2"
  if [[ -f "$path" ]]; then
    printf '  • %s ✅\n' "$message"
    return 0
  fi
  printf '  ✗ %s missing\n' "$message" >&2
  return 1
}

guard_run() {
  local run_lint=0 run_test=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
    --lint) run_lint=1 ;;
    --test) run_test=1 ;;
    -h | --help)
      cat <<'USAGE'
Usage:
  wgx guard [--lint] [--test]

Description:
  Führt eine Reihe von Sicherheits- und Qualitätsprüfungen für das Repository aus.
  Dies ist ein Sicherheitsnetz, das vor dem Erstellen eines Pull Requests ausgeführt wird.
  Standardmäßig werden sowohl Linting als auch Tests ausgeführt.

Checks:
  - Sucht nach potentiellen Secrets im Staging-Bereich.
  - Sucht nach verbleibenden Konfliktmarkern im Code.
  - Prüft auf übergroße Dateien (>= 1MB).
  - Verifiziert das Vorhandensein von wichtigen Repository-Dateien (z.B. uv.lock).
  - Führt 'wgx lint' aus (falls --lint angegeben oder Standard).
  - Führt 'wgx test' aus (falls --test angegeben oder Standard).

Options:
  --lint        Nur die Linting-Prüfungen ausführen.
  --test        Nur die Test-Prüfungen ausführen.
  -h, --help    Diese Hilfe anzeigen.
USAGE
      return 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      return 1
      ;;
    esac
    shift
  done

  # Standard: beides
  if [[ $run_lint -eq 0 && $run_test -eq 0 ]]; then
    run_lint=1
    run_test=1
  fi

  # 1. Staged Secrets checken
  echo "▶ Checking for secrets..."
  if git diff --cached | grep -E "AKIA|SECRET|PASSWORD" >/dev/null; then
    echo "❌ Potentielles Secret im Commit gefunden!" >&2
    return 1
  fi

  # 2. Konfliktmarker checken
  echo "▶ Checking for conflict markers..."
  if grep -R -E '^(<<<<<<< |=======|>>>>>>> )' . --exclude-dir=.git >/dev/null 2>&1; then
    echo "❌ Konfliktmarker gefunden!" >&2
    return 1
  fi

  # 3. Bigfiles checken
  echo "▶ Checking for oversized files..."
  if git ls-files -z |
    xargs -0 du -sb 2>/dev/null |
    awk 'BEGIN { found = 0 } $1 >= 1048576 { print; found = 1 } END { exit(found ? 0 : 1) }'; then
    echo "❌ Zu große Dateien im Repo!" >&2
    return 1
  fi

  # 4. Repository Guard-Checks
  echo "▶ Verifying repository guard checklist..."
  local checklist_ok=1
  _guard_require_file "uv.lock" "uv.lock vorhanden" || checklist_ok=0
  _guard_require_file ".github/workflows/shell-docs.yml" "Shell/Docs CI-Workflow vorhanden" || checklist_ok=0
  _guard_require_file "templates/profile.template.yml" "Profile-Template vorhanden" || checklist_ok=0
  _guard_require_file "docs/Runbook.md" "Runbook dokumentiert" || checklist_ok=0
  if [[ $checklist_ok -eq 0 ]]; then
    echo "❌ Guard checklist failed." >&2
    return 1
  fi

  # 5. Lint (wenn gewünscht)
  if [[ $run_lint -eq 1 ]]; then
    if _guard_command_available lint; then
      echo "▶ Running lint checks..."
      ./wgx lint || return 1
    else
      echo "⚠️ lint command not available, skipping lint step." >&2
    fi
  fi

  # 6. Tests (wenn gewünscht)
  if [[ $run_test -eq 1 ]]; then
    if _guard_command_available test; then
      echo "▶ Running tests..."
      ./wgx test || return 1
    else
      echo "⚠️ test command not available, skipping test step." >&2
    fi
  fi

  echo "✔ Guard finished successfully."
}
```

### 📄 modules/json.bash

**Größe:** 445 B | **md5:** `77f7435663d5da94f27da6d5b902ec82`

```bash
#!/usr/bin/env bash

# shellcheck shell=bash

json_escape() {
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$1" <<'PY'
import json
import sys
print(json.dumps(sys.argv[1])[1:-1])
PY
  else
    printf '%s' "$1"
  fi
}

json_quote() {
  printf '"%s"' "$(json_escape "$1")"
}

json_bool_value() {
  [[ $1 == true || $1 == false ]] || die "invalid boolean: $1"
  printf '%s' "$1"
}

json_join() {
  local IFS=','
  printf '%s' "$*"
}
```

### 📄 modules/profile.bash

**Größe:** 31 KB | **md5:** `3ae38a282841f90aa903b41665abf4cd`

```bash
#!/usr/bin/env bash

# shellcheck shell=bash

PROFILE_FILE=""
PROFILE_VERSION=""
WGX_REQUIRED_RANGE=""
WGX_REQUIRED_MIN=""
WGX_REPO_KIND=""
WGX_DIR_WEB=""
WGX_DIR_API=""
WGX_DIR_DATA=""
WGX_PROFILE_LOADED=""

# shellcheck disable=SC2034
WGX_AVAILABLE_CAPS=(task-array status-dirs tasks-json validate env-defaults env-overrides workflows)

declare -ga WGX_REQUIRED_CAPS=()
declare -ga WGX_ENV_KEYS=()

declare -gA WGX_ENV_BASE_MAP=()
declare -gA WGX_ENV_DEFAULT_MAP=()
declare -gA WGX_ENV_OVERRIDE_MAP=()

declare -ga WGX_TASK_ORDER=()
declare -gA WGX_TASK_CMDS=()
declare -gA WGX_TASK_DESC=()
declare -gA WGX_TASK_GROUP=()
declare -gA WGX_TASK_SAFE=()

declare -gA WGX_WORKFLOW_TASKS=()

profile::_reset() {
  PROFILE_VERSION=""
  WGX_REQUIRED_RANGE=""
  WGX_REQUIRED_MIN=""
  WGX_REPO_KIND=""
  WGX_DIR_WEB=""
  WGX_DIR_API=""
  WGX_DIR_DATA=""
  WGX_REQUIRED_CAPS=()
  WGX_ENV_KEYS=()
  WGX_TASK_ORDER=()
  WGX_ENV_BASE_MAP=()
  WGX_ENV_DEFAULT_MAP=()
  WGX_ENV_OVERRIDE_MAP=()
  WGX_TASK_CMDS=()
  WGX_TASK_DESC=()
  WGX_TASK_GROUP=()
  WGX_TASK_SAFE=()
  WGX_WORKFLOW_TASKS=()
  WGX_PROFILE_LOADED=""
}

profile::_detect_file() {
  PROFILE_FILE=""
  local base
  for base in ".wgx/profile.yml" ".wgx/profile.yaml" ".wgx/profile.json"; do
    if [[ -f $base ]]; then
      PROFILE_FILE="$base"
      return 0
    fi
  done
  return 1
}

profile::_have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

profile::_abspath() {
  local p="$1" resolved=""
  if profile::_have_cmd python3; then
    if resolved="$(python3 - "$p" <<'PY' 2>/dev/null
import os
import sys

print(os.path.abspath(sys.argv[1]))
PY
)"; then
      if [[ -n $resolved ]]; then
        printf '%s\n' "$resolved"
        return 0
      fi
    fi
  fi
  if command -v readlink >/dev/null 2>&1; then
    resolved="$(readlink -f -- "$p" 2>/dev/null || true)"
    if [[ -n $resolved ]]; then
      printf '%s\n' "$resolved"
    else
      printf '%s\n' "$p"
    fi
    return 0
  fi
  printf '%s\n' "$p"
}

profile::_normalize_task_name() {
  local name="$1"
  name="${name//_/ -}"
  name="${name// /}"
  printf '%s' "${name,,}"
}

profile::_python_parse() {
  local file="$1" output
  profile::_have_cmd python3 || return 1
  output="$(
    python3 - "$file" <<'PY'
import ast
import json
import os
import shlex
import sys
from typing import Any, Dict, List


def _parse_scalar(value: str) -> Any:
    text = value.strip()
    if text == "":
        return ""
    lowered = text.lower()
    if lowered in {"true", "yes"}:
        return True
    if lowered in {"false", "no"}:
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
        new_value: Dict[str, Any] = {}
        if parent is None:
            frame["container"] = new_value
        elif isinstance(parent, list):
            parent[key] = new_value
        else:
            parent[key] = new_value
        frame["container"] = new_value
        frame["type"] = "dict"


def _parse_simple_yaml(path: str) -> Any:
    root: Dict[str, Any] = {}
    stack: List[Dict[str, Any]] = [
        {"indent": -1, "container": root, "parent": None, "key": None, "type": "dict"}
    ]

    with open(path, "r", encoding="utf-8") as handle:
        for raw_line in handle:
            line = raw_line.rstrip("\n")
            stripped = line.split("#", 1)[0].rstrip()
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
                if value_part.endswith(":") or ": " in value_part:
                    key, rest = value_part.split(":", 1)
                    key = key.strip()
                    rest = rest.strip()
                    item: Dict[str, Any] = {}
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

            if content.endswith(":") or ": " in content:
                key, value_part = content.split(":", 1)
                key = key.strip()
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


path = sys.argv[1]
data = _load_manifest(path) or {}

wgx = data.get('wgx')
if not isinstance(wgx, dict):
    wgx = {}

# Backwards compatibility: allow certain keys (e.g. tasks) at the top level.
# Older profiles stored "tasks" directly on the root object. Newer profiles nest
# them inside the "wgx" block. We support both to avoid breaking existing
# repositories.
root_tasks = data.get('tasks') if isinstance(data, dict) else None
root_repo_kind = data.get('repoKind') if isinstance(data, dict) else None
root_dirs = data.get('dirs') if isinstance(data, dict) else None
root_env = data.get('env') if isinstance(data, dict) else None
root_env_defaults = data.get('envDefaults') if isinstance(data, dict) else None
root_env_overrides = data.get('envOverrides') if isinstance(data, dict) else None
root_workflows = data.get('workflows') if isinstance(data, dict) else None

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

def select_variant(value):
    if isinstance(value, dict):
        for key in platform_keys:
            if key in value and value[key] not in (None, ''):
                return value[key]
        for entry in value.values():
            if entry not in (None, ''):
                return entry
        return None
    return value

def as_bool(value):
    if isinstance(value, bool):
        return value
    if isinstance(value, int):
        return value != 0
    if isinstance(value, str):
        return value.strip().lower() in ("1", "true", "yes", "on")
    return False

def normalize_list(value):
    if value is None:
        return []
    if isinstance(value, (list, tuple)):
        return [str(item) for item in value]
    if isinstance(value, dict):
        selected = select_variant(value)
        if isinstance(selected, (list, tuple)):
            return [str(item) for item in selected]
        if selected is None:
            return []
        return [str(selected)]
    return [str(value)]

def emit(line: str) -> None:
    sys.stdout.write(f"{line}\n")

def shell_quote(value: str) -> str:
    return shlex.quote(value)

def emit_env(prefix: str, mapping):
    if not isinstance(mapping, dict):
        return
    for key, val in mapping.items():
        if key is None:
            continue
        # env base/overrides werden 1:1 als STR übernommen
        skey = str(key)
        sval = '' if val is None else str(val)
        emit(f"{prefix}[{shell_quote(skey)}]={shell_quote(sval)}")

def emit_caps(caps):
    if not isinstance(caps, (list, tuple)):
        return
    for cap in caps:
        if cap is None:
            continue
        emit(f"WGX_REQUIRED_CAPS+=({shell_quote(str(cap))})")

# track if we used any root-level fallback (for a single deprecation note)
used_root_fallback = False

emit(f"PROFILE_VERSION={shell_quote(str(wgx.get('apiVersion') or ''))}")
req = wgx.get('requiredWgx')
if isinstance(req, str):
    emit(f"WGX_REQUIRED_RANGE={shell_quote(req)}")
elif isinstance(req, dict):
    rng = req.get('range')
    if rng:
        emit(f"WGX_REQUIRED_RANGE={shell_quote(str(rng))}")
    minimum = req.get('min')
    if minimum:
        emit(f"WGX_REQUIRED_MIN={shell_quote(str(minimum))}")
    emit_caps(req.get('caps'))
else:
    emit_caps([])

repo_kind = wgx.get('repoKind') if isinstance(wgx, dict) else None
if repo_kind is None:
    repo_kind = root_repo_kind
    if repo_kind is not None:
        used_root_fallback = True
emit(f"WGX_REPO_KIND={shell_quote(str(repo_kind or ''))}")

dirs = wgx.get('dirs') if isinstance(wgx, dict) else None
if not isinstance(dirs, dict):
    dirs = root_dirs if isinstance(root_dirs, dict) else {}
    if dirs:
        used_root_fallback = True
emit(f"WGX_DIR_WEB={shell_quote(str(dirs.get('web') or ''))}")
emit(f"WGX_DIR_API={shell_quote(str(dirs.get('api') or ''))}")
emit(f"WGX_DIR_DATA={shell_quote(str(dirs.get('data') or ''))}")

env_defaults = wgx.get('envDefaults') if isinstance(wgx, dict) else None
if not isinstance(env_defaults, dict):
    env_defaults = root_env_defaults if isinstance(root_env_defaults, dict) else {}
    if env_defaults:
        used_root_fallback = True
emit_env('WGX_ENV_DEFAULT_MAP', env_defaults)

env_base = wgx.get('env') if isinstance(wgx, dict) else None
if not isinstance(env_base, dict):
    env_base = root_env if isinstance(root_env, dict) else {}
    if env_base:
        used_root_fallback = True
emit_env('WGX_ENV_BASE_MAP', env_base)

env_overrides = wgx.get('envOverrides') if isinstance(wgx, dict) else None
if not isinstance(env_overrides, dict):
    env_overrides = root_env_overrides if isinstance(root_env_overrides, dict) else {}
    if env_overrides:
        used_root_fallback = True
emit_env('WGX_ENV_OVERRIDE_MAP', env_overrides)

workflows = wgx.get('workflows') if isinstance(wgx, dict) else None
if not isinstance(workflows, dict):
    workflows = root_workflows if isinstance(root_workflows, dict) else {}
    if workflows:
        used_root_fallback = True
if isinstance(workflows, dict):
    for wf_name, wf_spec in workflows.items():
        steps = []
        if isinstance(wf_spec, dict):
            for step in wf_spec.get('steps') or []:
                if isinstance(step, dict):
                    task_name = step.get('task')
                    if task_name:
                        steps.append(str(task_name))
        emit(f"WGX_WORKFLOW_TASKS[{shell_quote(str(wf_name))}]={shell_quote(' '.join(steps))}")

tasks = wgx.get('tasks') if isinstance(wgx, dict) else None
if not isinstance(tasks, dict) or not tasks:
    tasks = root_tasks if isinstance(root_tasks, dict) else {}
    if tasks:
        used_root_fallback = True
if isinstance(tasks, dict):
    seen_task_order = set()
    for raw_name, spec in tasks.items():
        name = str(raw_name)
        norm = name.replace(' ', '').replace('_', '-').lower()
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
        #
        # Build command preserving semantics:
        # - If manifest provided a STRING: keep it as-is (no re-quoting/splitting).
        #   Only append args (quoted) if present.
        # - If manifest provided an ARRAY: emit ARRJSON (and extend with args).
        # - Otherwise: coerce to string sensibly.
        #
        base_cmd = None
        tokens = []
        use_array_format = False

        if isinstance(selected_cmd, (list, tuple)):
            tokens = [str(item) for item in selected_cmd]
            use_array_format = True
        elif isinstance(selected_cmd, str) and selected_cmd.strip():
            base_cmd = selected_cmd  # preserve raw shell string
        elif selected_cmd not in (None, ''):
            # numbers/other scalars -> treat as a single token
            tokens = [str(selected_cmd)]

        # Normalize/collect args (list/dict with platform variants)
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
            emit(f"WGX_TASK_CMDS[{shell_quote(norm)}]={shell_quote('ARRJSON:' + payload)}")
        else:
            if base_cmd is not None:
                # keep base string as-is; only quote appended args
                if appended_args:
                    command = base_cmd + ' ' + ' '.join(shlex.quote(str(a)) for a in appended_args)
                else:
                    command = base_cmd
            else:
                # no base string; fall back to joined tokens/args
                all_parts = tokens + appended_args
                command = ' '.join(shlex.quote(str(p)) for p in all_parts)
            emit(f"WGX_TASK_CMDS[{shell_quote(norm)}]={shell_quote('STR:' + command)}")
        emit(f"WGX_TASK_DESC[{shell_quote(norm)}]={shell_quote(str(desc))}")
        emit(f"WGX_TASK_GROUP[{shell_quote(norm)}]={shell_quote(str(group))}")
        emit(f"WGX_TASK_SAFE[{shell_quote(norm)}]={shell_quote('1' if safe else '0')}")
        continue

if used_root_fallback and os.environ.get("WGX_PROFILE_DEPRECATION", "warn") != "quiet":
    print("wgx: note: using root-level profile keys for backwards compatibility; consider nesting under 'wgx.'", file=sys.stderr)

PY
  )"
  local status=$?
  if ((status != 0)); then
    return $status
  fi

  if [[ -z $output ]]; then
    return 0
  fi

  local line
  while IFS= read -r line; do
    [[ -n $line ]] || continue
    eval "$line"
  done <<<"$output"

  return 0
}

profile::_decode_json_array() {
  local json_payload="$1"
  profile::_have_cmd python3 || return 1
  python3 - "$json_payload" <<'PY'
import json
import sys

try:
    values = json.loads(sys.argv[1])
except Exception:
    sys.exit(1)

for entry in values:
    if entry is None:
        continue
    print(str(entry))
PY
}

profile::_flat_yaml_parse() {
  local file="$1" section="" line key value
  local current_task=""
  declare -A _task_seen=()

  while IFS= read -r line || [[ -n $line ]]; do
    line="$(printf '%s' "$line" | sed 's/#.*$//' | sed 's/[[:space:]]*$//' | sed 's/^[[:space:]]*//')"
    [[ -z $line ]] && continue
    if [[ $line == wgx:* ]]; then
      section="root"
      current_task=""
      continue
    fi
    if [[ $line =~ ^apiVersion:[[:space:]]*(.*)$ ]]; then
      value="${BASH_REMATCH[1]}"
      value="$(printf '%s' "$value" | sed 's/^"//' | sed 's/"$//')"
      PROFILE_VERSION="$value"
      continue
    fi
    if [[ $line =~ ^requiredWgx:[[:space:]]*(.*)$ ]]; then
      value="${BASH_REMATCH[1]}"
      value="$(printf '%s' "$value" | sed 's/^"//' | sed 's/"$//')"
      WGX_REQUIRED_RANGE="$value"
      continue
    fi
    if [[ $line =~ ^repoKind:[[:space:]]*(.*)$ ]]; then
      value="${BASH_REMATCH[1]}"
      value="$(printf '%s' "$value" | sed 's/^"//' | sed 's/"$//')"
      # shellcheck disable=SC2034
      WGX_REPO_KIND="$value"
      continue
    fi
    if [[ $line == dirs:* ]]; then
      section="dirs"
      current_task=""
      continue
    fi
    if [[ $line == tasks:* ]]; then
      section="tasks"
      current_task=""
      continue
    fi
    if [[ $line == env:* ]]; then
      section="env"
      current_task=""
      continue
    fi
    if [[ $section == tasks && $line =~ ^([a-zA-Z0-9_-]+):[[:space:]]*$ ]]; then
      key="${BASH_REMATCH[1]}"
      key="$(profile::_normalize_task_name "$key")"
      current_task="$key"
      if [[ -z ${_task_seen[$key]:-} ]]; then
        _task_seen[$key]=1
        WGX_TASK_ORDER+=("$key")
      fi
      [[ -n ${WGX_TASK_CMDS[$key]+_} ]] || WGX_TASK_CMDS["$key"]="STR:"
      [[ -n ${WGX_TASK_DESC[$key]+_} ]] || WGX_TASK_DESC["$key"]=""
      [[ -n ${WGX_TASK_GROUP[$key]+_} ]] || WGX_TASK_GROUP["$key"]=""
      [[ -n ${WGX_TASK_SAFE[$key]+_} ]] || WGX_TASK_SAFE["$key"]="0"
      continue
    fi
    if [[ $section == tasks && $line =~ ^cmd:[[:space:]]*(.*)$ ]]; then
      [[ -n $current_task ]] || continue
      value="${BASH_REMATCH[1]}"
      value="$(printf '%s' "$value" | sed 's/^"//' | sed 's/"$//')"
      WGX_TASK_CMDS["$current_task"]="STR:${value}"
      continue
    fi
    if [[ $section == tasks && $line =~ ^desc:[[:space:]]*(.*)$ ]]; then
      [[ -n $current_task ]] || continue
      value="${BASH_REMATCH[1]}"
      value="$(printf '%s' "$value" | sed 's/^"//' | sed 's/"$//')"
      WGX_TASK_DESC["$current_task"]="$value"
      continue
    fi
    if [[ $section == tasks && $line =~ ^group:[[:space:]]*(.*)$ ]]; then
      [[ -n $current_task ]] || continue
      value="${BASH_REMATCH[1]}"
      value="$(printf '%s' "$value" | sed 's/^"//' | sed 's/"$//')"
      WGX_TASK_GROUP["$current_task"]="$value"
      continue
    fi
    if [[ $section == tasks && $line =~ ^safe:[[:space:]]*(.*)$ ]]; then
      [[ -n $current_task ]] || continue
      value="${BASH_REMATCH[1]}"
      value="$(printf '%s' "$value" | sed 's/^"//' | sed 's/"$//')"
      case "${value,,}" in
      1|true|yes|on)
        WGX_TASK_SAFE["$current_task"]="1"
        ;;
      *)
        WGX_TASK_SAFE["$current_task"]="0"
        ;;
      esac
      continue
    fi
    if [[ $section == dirs && $line =~ ^([a-zA-Z0-9_-]+):[[:space:]]*(.*)$ ]]; then
      key="${BASH_REMATCH[1]}"
      value="${BASH_REMATCH[2]}"
      value="$(printf '%s' "$value" | sed 's/^"//' | sed 's/"$//')"
      # shellcheck disable=SC2034
      case "$key" in
      web) WGX_DIR_WEB="$value" ;;
      api) WGX_DIR_API="$value" ;;
      data) WGX_DIR_DATA="$value" ;;
      esac
      continue
    fi
    if [[ $section == tasks && $line =~ ^([a-zA-Z0-9_-]+):[[:space:]]*(.*)$ ]]; then
      key="${BASH_REMATCH[1]}"
      value="${BASH_REMATCH[2]}"
      value="$(printf '%s' "$value" | sed 's/^"//' | sed 's/"$//')"
      key="$(profile::_normalize_task_name "$key")"
      current_task="$key"
      if [[ -z ${_task_seen[$key]:-} ]]; then
        _task_seen[$key]=1
        WGX_TASK_ORDER+=("$key")
      fi
      [[ -n ${WGX_TASK_DESC[$key]+_} ]] || WGX_TASK_DESC["$key"]=""
      [[ -n ${WGX_TASK_GROUP[$key]+_} ]] || WGX_TASK_GROUP["$key"]=""
      [[ -n ${WGX_TASK_SAFE[$key]+_} ]] || WGX_TASK_SAFE["$key"]="0"
      [[ -n ${WGX_TASK_CMDS[$key]+_} ]] || WGX_TASK_CMDS["$key"]="STR:"
      if [[ -n $value ]]; then
        WGX_TASK_CMDS["$key"]="STR:${value}"
      fi
      continue
    fi
    if [[ $section == env && $line =~ ^([A-Z0-9_]+):[[:space:]]*(.*)$ ]]; then
      key="${BASH_REMATCH[1]}"
      value="${BASH_REMATCH[2]}"
      value="$(printf '%s' "$value" | sed 's/^"//' | sed 's/"$//')"
      WGX_ENV_BASE_MAP["$key"]="$value"
      continue
    fi
  done <"$file"
  [[ -z $PROFILE_VERSION ]] && PROFILE_VERSION="v1"
}

profile::_collect_env_keys() {
  local -A seen=()
  WGX_ENV_KEYS=()
  local key
  for key in "${!WGX_ENV_DEFAULT_MAP[@]}"; do
    if [[ -z ${seen[$key]:-} ]]; then
      seen[$key]=1
      WGX_ENV_KEYS+=("$key")
    fi
  done
  for key in "${!WGX_ENV_BASE_MAP[@]}"; do
    if [[ -z ${seen[$key]:-} ]]; then
      seen[$key]=1
      WGX_ENV_KEYS+=("$key")
    fi
  done
  for key in "${!WGX_ENV_OVERRIDE_MAP[@]}"; do
    if [[ -z ${seen[$key]:-} ]]; then
      seen[$key]=1
      WGX_ENV_KEYS+=("$key")
    fi
  done
}

profile::has_manifest() {
  profile::_detect_file
}

profile::load() {
  local file="${1:-}"
  if [[ -n $file ]]; then
    [[ -f $file ]] || return 1
    PROFILE_FILE="$file"
  else
    profile::_detect_file || return 1
    file="$PROFILE_FILE"
  fi
  local _norm_file
  _norm_file="$(profile::_abspath "$file")"
  if [[ ${WGX_PROFILE_LOADED:-} == "$_norm_file" ]]; then
    return 0
  fi
  profile::_reset
  local status=1
  if [[ $file == *.yml || $file == *.yaml || $file == *.json ]]; then
    if profile::_python_parse "$file"; then
      status=0
    else
      local rc=$?
      if ((rc == 3)); then
        status=3
      fi
    fi
  fi
  if ((status != 0)); then
    profile::_flat_yaml_parse "$file"
  fi
  profile::_collect_env_keys
  WGX_PROFILE_LOADED="$_norm_file"
  return 0
}

profile::ensure_loaded() {
  if ! profile::has_manifest; then
    profile::_reset
    PROFILE_FILE=""
    return 1
  fi
  profile::load "$PROFILE_FILE"
}

profile::available_caps() {
  printf '%s\n' "${WGX_AVAILABLE_CAPS[@]}"
}

profile::ensure_version() {
  [[ -z ${WGX_VERSION:-} ]] && return 0
  if [[ -z $WGX_REQUIRED_RANGE && -z $WGX_REQUIRED_MIN ]]; then
    return 0
  fi
  if ! declare -F semver_norm >/dev/null 2>&1; then
    source "${WGX_DIR:-.}/modules/semver.bash"
  fi
  local have="${WGX_VERSION:-0.0.0}"
  if [[ -n $WGX_REQUIRED_RANGE ]]; then
    if [[ $WGX_REQUIRED_RANGE == ^* ]]; then
      if ! semver_in_caret_range "$have" "$WGX_REQUIRED_RANGE"; then
        warn "wgx version ${have} outside required range ${WGX_REQUIRED_RANGE}"
        return 1
      fi
    else
      if ! semver_ge "$have" "$WGX_REQUIRED_RANGE"; then
        warn "wgx version ${have} < required ${WGX_REQUIRED_RANGE}"
        return 1
      fi
    fi
  fi
  if [[ -n $WGX_REQUIRED_MIN ]]; then
    if ! semver_ge "$have" "$WGX_REQUIRED_MIN"; then
      warn "wgx version ${have} < required minimum ${WGX_REQUIRED_MIN}"
      return 1

<<TRUNCATED: max_file_lines=800>>
```

### 📄 modules/semver.bash

**Größe:** 2 KB | **md5:** `c239edd57483125ab84868ba1f8bd4ef`

```bash
#!/usr/bin/env bash

# shellcheck shell=bash

# Minimal SemVer helper utilities.

semver_norm() {
  local v="${1#v}"
  local major minor patch
  IFS='.' read -r major minor patch <<<"$v"
  printf '%s.%s.%s' "${major:-0}" "${minor:-0}" "${patch:-0}"
}

semver_cmp() {
  local left right
  left="$(semver_norm "$1")"
  right="$(semver_norm "$2")"
  local l1 l2 l3 r1 r2 r3
  IFS='.' read -r l1 l2 l3 <<<"$left"
  IFS='.' read -r r1 r2 r3 <<<"$right"
  if ((l1 > r1)) || ((l1 == r1 && l2 > r2)) || ((l1 == r1 && l2 == r2 && l3 > r3)); then
    return 1
  elif ((l1 < r1)) || ((l1 == r1 && l2 < r2)) || ((l1 == r1 && l2 == r2 && l3 < r3)); then
    return 2
  fi
  return 0
}

semver_ge() {
  semver_cmp "$1" "$2"
  local cmp=$?
  [[ $cmp -eq 0 || $cmp -eq 1 ]]
}

semver_gt() {
  semver_cmp "$1" "$2"
  [[ $? -eq 1 ]]
}

semver_le() {
  semver_cmp "$1" "$2"
  local cmp=$?
  [[ $cmp -eq 0 || $cmp -eq 2 ]]
}

semver_lt() {
  semver_cmp "$1" "$2"
  [[ $? -eq 2 ]]
}

semver_in_caret_range() {
  local have="${1#v}" range="${2#^}"
  range="$(semver_norm "$range")"
  local major minor patch
  IFS='.' read -r major minor patch <<<"$range"
  local lower="$range"
  local upper

  if ((major > 0)); then
    local next_major=$((major + 1))
    upper="${next_major}.0.0"
  elif ((minor > 0)); then
    local next_minor=$((minor + 1))
    upper="0.${next_minor}.0"
  else
    # For 0.0.x ranges, caret semantics allow patch updates only, stopping before the next
    # patch release (e.g. ^0.0.3 allows versions >=0.0.3 and <0.0.4).
    local next_patch=$((patch + 1))
    upper="0.0.${next_patch}"
  fi

  semver_ge "$have" "$lower" && semver_lt "$have" "$upper"
}
```

### 📄 modules/status.bash

**Größe:** 2 KB | **md5:** `4331c2a095f32470a34e3b40cca682dd`

```bash
#!/usr/bin/env bash

# Status-Modul: Projektstatus anzeigen

status_cmd() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    cat <<'USAGE'
Usage:
  wgx status

Description:
  Zeigt einen kompakten Snapshot des Repository-Status an.
  Dies umfasst den aktuellen Branch, den Ahead/Behind-Status im Vergleich zum
  Upstream-Branch, erkannte Projektverzeichnisse (Web, API, etc.) und
  globale Flags wie den OFFLINE-Modus.

Options:
  -h, --help    Diese Hilfe anzeigen.
USAGE
    return 0
  fi

  profile::ensure_loaded || true

  echo "▶ Repo-Root: $(git rev-parse --show-toplevel 2>/dev/null || echo 'N/A')"
  echo "▶ Branch: $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'N/A')"

  if [[ -n ${WGX_REPO_KIND:-} ]]; then
    echo "▶ Repo-Kind: ${WGX_REPO_KIND}"
  fi
  if [[ -n ${PROFILE_VERSION:-} ]]; then
    echo "▶ Manifest-Version: ${PROFILE_VERSION}"
  fi
  local required=""
  if [[ -n ${WGX_REQUIRED_RANGE:-} ]]; then
    required+="range=${WGX_REQUIRED_RANGE}"
  fi
  if [[ -n ${WGX_REQUIRED_MIN:-} ]]; then
    [[ -n $required ]] && required+=" "
    required+="min=${WGX_REQUIRED_MIN}"
  fi
  if [[ -n $required ]]; then
    echo "▶ requiredWgx: ${required}"
  fi

  # Ahead/Behind
  if git rev-parse --abbrev-ref HEAD >/dev/null 2>&1; then
    local ahead behind
    ahead=$(git rev-list --right-only --count '@{u}'...HEAD 2>/dev/null || echo 0)
    behind=$(git rev-list --left-only --count '@{u}'...HEAD 2>/dev/null || echo 0)
    echo "▶ Ahead: $ahead | Behind: $behind"
  fi

  # Erkannte Projektteile
  local info_present=0
  if [[ -n ${WGX_DIR_WEB:-}${WGX_DIR_API:-}${WGX_DIR_DATA:-} ]]; then
    info_present=1
    for entry in WEB:"${WGX_DIR_WEB}" API:"${WGX_DIR_API}" DATA:"${WGX_DIR_DATA}"; do
      local label="${entry%%:*}"
      local path="${entry#*:}"
      [[ -n $path ]] || continue
      if [[ -d $path ]]; then
        echo "▶ ${label}: ${path} (ok)"
      else
        echo "▶ ${label}: ${path} (missing)"
      fi
    done
  fi
  if [ "$info_present" != "1" ]; then
    local fallback_present=0
    if [[ -d web ]]; then
      echo "▶ Web-Verzeichnis: web"
      fallback_present=1
    fi
    if [[ -d api ]]; then
      echo "▶ API-Verzeichnis: api"
      fallback_present=1
    fi
    if [[ -d crates ]]; then
      echo "▶ crates vorhanden"
      fallback_present=1
    fi

    if [ "$fallback_present" = "1" ]; then
      info_present=1
    fi
  fi

  # OFFLINE?
  [[ -n "${OFFLINE:-}" ]] && echo "▶ OFFLINE=1 aktiv"
}
```


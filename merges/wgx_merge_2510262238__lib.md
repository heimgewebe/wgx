### 📄 lib/audit.bash

**Größe:** 4 KB | **md5:** `249168f29a71f87b5c07850d6b599498`

```bash
#!/usr/bin/env bash

_audit_default_dir() {
  local base="${WGX_DIR:-"$(pwd)"}"
  printf '%s/.wgx/audit' "$base"
}

audit::_ledger_path() {
  local target="${WGX_AUDIT_LOG:-}"
  if [[ -z "$target" ]]; then
    target="$(_audit_default_dir)/ledger.jsonl"
  fi
  printf '%s' "$target"
}

audit::log() {
  local event="${1:-}"
  local payload
  payload="$2"
  if [[ -z "$payload" ]]; then
    payload="{}"
  fi
  if [[ -z "$event" ]]; then
    printf 'audit::log: missing event name\n' >&2
    return 1
  fi
  if ! command -v python3 >/dev/null 2>&1; then
    printf 'audit::log: python3 not available – skipping log.\n' >&2
    return 0
  fi
  local ledger
  ledger="$(audit::_ledger_path)" || return 1
  local dir
  dir="$(dirname "$ledger")"
  mkdir -p "$dir"
  local timestamp
  timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  local git_sha
  git_sha="$(git rev-parse HEAD 2>/dev/null || printf '%040d' 0)"
  local prev_line=""
  if [[ -s "$ledger" ]]; then
    prev_line="$(tail -n 1 "$ledger" 2>/dev/null || printf '')"
  fi
  AUDIT_EVENT="$event" \
  AUDIT_PAYLOAD="$payload" \
  AUDIT_TIMESTAMP="$timestamp" \
  AUDIT_SHA="$git_sha" \
  AUDIT_PREV_LINE="$prev_line" \
  python3 - "$ledger" <<'PY'
import json
import os
import sys
import hashlib
from pathlib import Path

ledger_path = Path(sys.argv[1])
event = os.environ.get("AUDIT_EVENT", "")
payload_raw = os.environ.get("AUDIT_PAYLOAD", "{}")
timestamp = os.environ.get("AUDIT_TIMESTAMP") or ""
git_sha = os.environ.get("AUDIT_SHA") or ""
prev_line = os.environ.get("AUDIT_PREV_LINE", "").strip()
prev_hash = "0" * 64
if prev_line:
    try:
        prev_hash = json.loads(prev_line).get("hash", "0" * 64)
        if not isinstance(prev_hash, str) or len(prev_hash) != 64:
            raise ValueError
    except Exception:
        prev_hash = hashlib.sha256(prev_line.encode("utf-8")).hexdigest()
try:
    payload = json.loads(payload_raw)
except Exception:
    payload = {"raw": payload_raw}
entry = {
    "timestamp": timestamp,
    "event": event,
    "git_sha": git_sha,
    "payload": payload,
    "prev_hash": prev_hash,
}
body = json.dumps(entry, sort_keys=True, separators=(",", ":"))
entry["hash"] = hashlib.sha256(body.encode("utf-8")).hexdigest()
with ledger_path.open("a", encoding="utf-8") as fh:
    fh.write(json.dumps(entry, sort_keys=True, separators=(",", ":")))
    fh.write("\n")
PY
}

audit::verify() {
  local strict=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --strict)
        strict=1
        shift
        ;;
      --help|-h)
        cat <<'USAGE'
audit::verify [--strict]
  Prüft die Hash-Kette in .wgx/audit/ledger.jsonl.
  Rückgabewert 0 bei gültiger Kette.
  Mit --strict (oder AUDIT_VERIFY_STRICT=1) führt eine Verletzung zu exit != 0.
USAGE
        return 0
        ;;
      --*)
        printf 'audit::verify: unknown option %s\n' "$1" >&2
        return 1
        ;;
      *)
        break
        ;;
    esac
  done
  if ! command -v python3 >/dev/null 2>&1; then
    printf 'audit::verify: python3 not available.\n' >&2
    return 0
  fi
  local ledger
  ledger="$(audit::_ledger_path)" || return 1
  if [[ ! -s "$ledger" ]]; then
    printf 'audit::verify: ledger empty (%s).\n' "$ledger"
    return 0
  fi
  local output
  if output=$(AUDIT_STRICT_MODE="$strict" python3 - "$ledger" <<'PY'
import json
import os
import sys
import hashlib
from pathlib import Path

ledger_path = Path(sys.argv[1])
prev_hash = "0" * 64
line_no = 0
for raw in ledger_path.read_text(encoding="utf-8").splitlines():
    line = raw.strip()
    if not line:
        continue
    line_no += 1
    try:
        entry = json.loads(line)
    except Exception:
        print(f"invalid_json line={line_no}")
        sys.exit(1)
    if entry.get("prev_hash") != prev_hash:
        print(f"prev_hash_mismatch line={line_no}")
        sys.exit(1)
    data = dict(entry)
    digest = data.pop("hash", None)
    body = json.dumps(data, sort_keys=True, separators=(",", ":"))
    expected = hashlib.sha256(body.encode("utf-8")).hexdigest()
    if digest != expected:
        print(f"hash_mismatch line={line_no}")
        sys.exit(1)
    prev_hash = digest or "0" * 64
print("OK")
PY
); then
    printf '%s\n' "$output"
    return 0
  else
    local rc=$?
    if [[ -n "$output" ]]; then
      printf '%s\n' "$output" >&2
    fi
    if ((strict)) || [[ ${AUDIT_VERIFY_STRICT:-0} != 0 ]]; then
      return $rc
    fi
    printf 'audit::verify: non-strict mode, treating failure as warning.\n' >&2
    return 0
  fi
}
```

### 📄 lib/core.bash

**Größe:** 9 KB | **md5:** `24861ddfdeeb3be3ef2aeef9a77bea4e`

```bash
#!/usr/bin/env bash

# ---------- Logging ----------

: "${WGX_NO_EMOJI:=0}"
: "${WGX_QUIET:=0}"
: "${WGX_INFO_STDERR:=0}"

if [[ "$WGX_NO_EMOJI" != 0 ]]; then
  _OK="[OK]"
  _WARN="[WARN]"
  _ERR="[ERR]"
  _DOT="*"
else
  _OK="✅"
  _WARN="⚠️"
  _ERR="❌"
  _DOT="•"
fi

if ! type -t debug >/dev/null 2>&1; then
  debug() {
    [[ ${WGX_DEBUG:-0} != 0 ]] || return 0
    [[ ${WGX_QUIET:-0} != 0 ]] && return
    printf 'DEBUG %s\n' "$*" >&2
  }
fi

if ! type -t info >/dev/null 2>&1; then
  info() {
    # Default: STDOUT (wie bisher). Für CI/quiet-Logs optional auf STDERR umleitbar.
    [[ ${WGX_QUIET:-0} != 0 ]] && return
    if [[ ${WGX_INFO_STDERR:-0} != 0 ]]; then
      printf '%s %s\n' "$_DOT" "$*" >&2
    else
      printf '%s %s\n' "$_DOT" "$*"
    fi
  }
fi

if ! type -t ok >/dev/null 2>&1; then
  ok() {
    [[ ${WGX_QUIET:-0} != 0 ]] && return
    printf '%s %s\n' "$_OK" "$*" >&2
  }
fi

if ! type -t warn >/dev/null 2>&1; then
  warn() {
    printf '%s %s\n' "$_WARN" "$*" >&2
  }
fi

if ! type -t die >/dev/null 2>&1; then
  die() {
    printf '%s %s\n' "$_ERR" "$*" >&2
    exit 1
  }
fi

# ---------- Env / Defaults ----------
: "${WGX_VERSION:=2.0.3}"
: "${WGX_BASE:=main}"

# ── Module autoload ─────────────────────────────────────────────────────────
_load_modules() {
  local base="${WGX_DIR:-}"
  if [ -z "$base" ]; then
    base="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  fi
  local d="${base}/modules"
  if [ -d "$d" ]; then
    for f in "$d"/*.bash; do
      # shellcheck source=/dev/null
      [ -r "$f" ] && source "$f"
    done
  fi
}

# ---------- Git helpers ----------
git_current_branch() { git rev-parse --abbrev-ref HEAD 2>/dev/null || echo ""; }
git_is_repo_root() {
  # We intentionally use `pwd` instead of `pwd -P` to avoid resolving
  # symlinks, which simplifies behavior and aligns with the project's focus on
  # straightforward, common use cases.
  local top
  top=$(git rev-parse --show-toplevel 2>/dev/null) || return 1
  [ "$(pwd)" = "$top" ]
}
git_has_remote() {
  local remote="${1:-origin}"
  git remote 2>/dev/null | grep -qx "$remote"
}

# Hard Reset auf origin/$WGX_BASE + Cleanup
git_workdir_dirty() {
  git status --porcelain=v1 --untracked-files=normal 2>/dev/null | grep -q .
}

git_workdir_status_short() {
  git status --short 2>/dev/null || true
}

# Helper: Finde den ersten existierenden Remote-Branch aus einer Kandidatenliste
_git_resolve_branch() {
  local remote="$1"
  shift
  local candidate
  for candidate in "$@"; do
    [ -z "$candidate" ] && continue
    if git rev-parse --verify "${remote}/${candidate}" >/dev/null 2>&1; then
      printf '%s' "$candidate"
      return 0
    fi
  done
  return 1
}

_git_parse_remote_branch_spec() {
  local spec="$1"
  local default_remote="${2:-origin}"
  local remote="$default_remote"
  local branch="$spec"

  if [ -z "$branch" ]; then
    printf '%s %s\n' "$remote" ""
    return 0
  fi

  if [[ "$spec" == */* ]]; then
    local candidate_remote="${spec%%/*}"
    local candidate_branch="${spec#*/}"
    if git remote 2>/dev/null | grep -qx "$candidate_remote"; then
      remote="$candidate_remote"
      branch="$candidate_branch"
    fi
  fi

  printf '%s %s\n' "$remote" "$branch"
}

git_hard_reload() {
  if ! git remote -v | grep -q . 2>/dev/null; then
    die "Kein Remote-Repository konfiguriert."
  fi

  # 1. Argumente parsen
  local dry_run=0 base=""
  while [ $# -gt 0 ]; do
    case "$1" in
    --dry-run | -n)
      dry_run=1
      ;;
    --)
      shift
      break
      ;;
    -*)
      die "git_hard_reload: unerwartetes Argument '$1'"
      ;;
    *)
      if [ -z "$base" ]; then
        base="$1"
      else
        die "git_hard_reload: zu viele Argumente"
      fi
      ;;
    esac
    shift
  done

  debug "git_hard_reload: dry_run=${dry_run} base='${base}'"

  if ((dry_run)); then
    local remote target_branch base_branch full_ref
    if [ -n "$base" ]; then
      read -r remote base_branch < <(_git_parse_remote_branch_spec "$base" "origin")
      [ -z "$remote" ] && remote="origin"
      if [ -z "$base_branch" ]; then
        die "git_hard_reload: Ungültiger Basis-Branch '${base}'."
      fi
      target_branch="$base_branch"
    else
      local upstream
      upstream="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"
      if [ -n "$upstream" ]; then
        remote="${upstream%%/*}"
        target_branch="${upstream#*/}"
      else
        remote="origin"
        target_branch="${WGX_BASE:-main}"
      fi
    fi

    full_ref="${remote}/${target_branch}"
    info "[DRY-RUN] Geplante Schritte:"
    info "[DRY-RUN] git fetch --all --prune"
    info "[DRY-RUN] git reset --hard ${full_ref}"
    info "[DRY-RUN] git clean -fdx"
    ok "[DRY-RUN] Reload fertig (${full_ref})."
    return 0
  fi

  info "Fetch von allen Remotes (inkl. prune)…"
  debug "git_hard_reload: running 'git fetch --all --prune'"
  git fetch --all --prune || die "git fetch fehlgeschlagen"

  local remote target_branch base_branch
  if [ -n "$base" ]; then
    read -r remote base_branch < <(_git_parse_remote_branch_spec "$base" "origin")
    debug "git_hard_reload: parsed base spec '${base}' -> remote='${remote}' branch='${base_branch}'"
    if [ -z "$base_branch" ]; then
      die "git_hard_reload: Ungültiger Basis-Branch '${base}'."
    fi
    target_branch="$(_git_resolve_branch "$remote" "$base_branch")"
    if [ -z "$target_branch" ]; then
      die "git_hard_reload: Branch '${base}' nicht auf '${remote}' gefunden."
    fi
  else
    local upstream
    upstream="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"
    if [ -n "$upstream" ]; then
      remote="${upstream%%/*}"
      target_branch="${upstream#*/}"
    else
      remote="origin"
      target_branch="$(_git_resolve_branch "$remote" "$WGX_BASE" "main" "master")"
    fi
  fi

  if [ -z "$target_branch" ]; then
    die "git_hard_reload: Konnte keinen gültigen Ziel-Branch finden."
  fi

  local full_ref="${remote}/${target_branch}"
  debug "git_hard_reload: resolved remote ref '${full_ref}'"

  info "Kompletter Reset auf ${full_ref}… (alle lokalen Änderungen gehen verloren)"
  debug "git_hard_reload: running 'git reset --hard ${full_ref}'"
  git reset --hard "${full_ref}" || die "git reset --hard fehlgeschlagen"

  info "Untracked & ignorierte Dateien/Verzeichnisse bereinigen (clean -fdx)…"
  debug "git_hard_reload: running 'git clean -fdx'"
  git clean -fdx || die "git clean fehlgeschlagen"

  ok "Reload fertig (${full_ref})."
  return 0
}

# Optional: Safety Snapshot (Stash), nicht default-aktiv
snapshot_make() {
  git stash push -u -m "wgx snapshot $(date -u +%FT%TZ)" >/dev/null 2>&1 || true
  info "Snapshot (Stash) erstellt."
}

# ---------- Router ----------
wgx_command_files() {
  [ -d "$WGX_DIR/cmd" ] || return 0
  for f in "$WGX_DIR/cmd"/*.bash; do
    [ -r "$f" ] || continue
    printf '%s\n' "$f"
  done
}

wgx_available_commands() {
  local -a cmds
  cmds=(help)
  local file name
  while IFS= read -r file; do
    name=$(basename "$file")
    name=${name%.bash}
    cmds+=("$name")
  done < <(wgx_command_files)

  printf '%s\n' "${cmds[@]}" | sort -u
}

wgx_print_command_list() {
  while IFS= read -r cmd; do
    printf '  %s\n' "$cmd"
  done < <(wgx_available_commands)
}

wgx_usage() {
  cat <<USAGE
wgx — Workspace Helper

Usage:
  wgx <command> [args]

Commands:
$(wgx_print_command_list)

Env:
  WGX_BASE       Basis-Branch für reload (default: main)

More:
  wgx --list     Nur verfügbare Befehle anzeigen

USAGE
}

# ── Command dispatcher ──────────────────────────────────────────────────────
wgx_main() {
  if (($# == 0)); then
    wgx_usage
    return 1
  fi

  local sub="$1"
  shift || true

  case "$sub" in
  help | -h | --help)
    wgx_usage
    return 0
    ;;
  --list | commands)
    wgx_available_commands
    return 0
    ;;
  esac

  _load_modules

  # 1) Direkter Funktionsaufruf: cmd_<sub>
  if declare -F "cmd_${sub}" >/dev/null 2>&1; then
    "cmd_${sub}" "$@"
    return
  fi

  # 2) Datei sourcen und erneut versuchen
  local f="${WGX_DIR}/cmd/${sub}.bash"
  if [ -r "$f" ]; then
    # shellcheck source=/dev/null
    source "$f"
    if declare -F "cmd_${sub}" >/dev/null 2>&1; then
      "cmd_${sub}" "$@"
    elif declare -F "wgx_command_main" >/dev/null 2>&1; then
      wgx_command_main "$@"
    else
      echo "❌ Befehl '${sub}': weder cmd_${sub} noch wgx_command_main definiert." >&2
      return 127
    fi
    return
  fi

  echo "❌ Unbekannter Befehl: ${sub}" >&2
  wgx_usage >&2
  return 1
}
```

### 📄 lib/hauski.bash

**Größe:** 1002 B | **md5:** `9acf403404b3bf719ec29f5317b0802c`

```bash
#!/usr/bin/env bash

hauski::enabled() {
  [[ ${HAUSKI_ENABLE:-0} != 0 ]]
}

hauski::emit() {
  hauski::enabled || return 0
  local event="${1:-}" payload="${2:-{}}"
  if [[ -z "$event" ]]; then
    return 1
  fi
  if ! command -v curl >/dev/null 2>&1; then
    return 0
  fi
  if ! command -v python3 >/dev/null 2>&1; then
    return 0
  fi
  local timestamp
  timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  local body
  body=$(python3 - "$event" "$payload" "$timestamp" <<'PY'
import json
import sys

event = sys.argv[1]
payload_raw = sys.argv[2]
timestamp = sys.argv[3]
try:
    payload = json.loads(payload_raw)
except Exception:
    payload = {"raw": payload_raw}
print(json.dumps({"event": event, "timestamp": timestamp, "payload": payload}))
PY
)
  curl -fsS -X POST -H 'Content-Type: application/json' \
    --connect-timeout 1 \
    --max-time 2 \
    --retry 0 \
    --data "$body" \
    http://127.0.0.1:7070/v1/events >/dev/null 2>&1 && \
    printf 'hauski: delivered %s\n' "$event" >&2
}
```


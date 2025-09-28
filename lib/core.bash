#!/usr/bin/env bash

# ---------- Logging ----------

_err() {
  printf '❌ %s\n' "$*" >&2
}

_ok() {
  printf '✅ %s\n' "$*" >&2
}

_warn() {
  printf '⚠️  %s\n' "$*" >&2
}

if ! type -t info >/dev/null 2>&1; then
  info() {
    printf '• %s\n' "$*"
  }
fi

if ! type -t ok >/dev/null 2>&1; then
  ok() {
    _ok "$@"
  }
fi

if ! type -t warn >/dev/null 2>&1; then
  warn() {
    _warn "$@"
  }
fi

if ! type -t die >/dev/null 2>&1; then
  die() {
    _err "$*"
    exit 1
  }
fi

log_info() {
  printf '[INFO] %s\n' "$*" >&2
}

log_warn() {
  printf '[WARN] %s\n' "$*" >&2
}

log_error() {
  printf '[ERROR] %s\n' "$*" >&2
}

# ---------- Env / Defaults ----------
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
  local top
  top=$(git rev-parse --show-toplevel 2>/dev/null) || return 1
  [ "$(pwd -P)" = "$top" ]
}
git_has_remote() { git remote -v | grep -q '^origin' 2>/dev/null; }

# Hard Reset auf origin/$WGX_BASE + Cleanup
git_hard_reload() {
  git_has_remote || die "Kein origin-Remote gefunden."
  local base="${1:-$WGX_BASE}"

  log_info "Fetch von origin…"
  git fetch --prune origin || die "git fetch fehlgeschlagen"

  log_info "Kompletter Reset auf origin/${base}… (alle lokalen Änderungen gehen verloren)"
  git reset --hard "origin/${base}" || die "git reset --hard fehlgeschlagen"

  log_info "Untracked/ignored aufräumen (clean -fdx)…"
  git clean -fdx || die "git clean fehlgeschlagen"

  log_info "Reload fertig."
}

# Optional: Safety Snapshot (Stash), nicht default-aktiv
snapshot_make() {
  git stash push -u -m "wgx snapshot $(date -u +%FT%TZ)" >/dev/null 2>&1 || true
  log_info "Snapshot (Stash) erstellt."
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
"$(wgx_print_command_list)"

Env:
  WGX_BASE       Basis-Branch für reload (default: main)

More:
  wgx --list     Nur verfügbare Befehle anzeigen

USAGE
}

# ── Command dispatcher ──────────────────────────────────────────────────────
wgx_main() {
  local sub="${1:-help}"
  shift || true

  case "$sub" in
  help | -h | --help)
    wgx_usage
    return
    ;;
  --list | commands)
    wgx_available_commands
    return
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
  return 127
}

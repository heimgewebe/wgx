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
  local top
  top=$(git rev-parse --show-toplevel 2>/dev/null) || return 1
  [ "$(pwd -P)" = "$top" ]
}
git_has_remote() { git remote -v | grep -q '^origin' 2>/dev/null; }

# Hard Reset auf origin/$WGX_BASE + Cleanup
git_workdir_dirty() {
  git status --porcelain=v1 --untracked-files=normal 2>/dev/null | grep -q .
}

git_workdir_status_short() {
  git status --short 2>/dev/null || true
}

git_hard_reload() {
  if ! git remote -v | grep -q . 2>/dev/null; then
    die "Kein Remote-Repository konfiguriert."
  fi

  local dry_run=0 base="" explicit_branch=0

  while [ $# -gt 0 ]; do
    case "$1" in
    --dry-run|-n)
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
        explicit_branch=1
      else
        die "git_hard_reload: unerwartetes Argument '$1'"
      fi
      ;;
    esac
    shift
  done

  local remote="origin" target_branch="${base}"
  if [ -z "$target_branch" ]; then
    local upstream
    upstream="$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || true)"
    if [ -n "$upstream" ]; then
      remote="${upstream%%/*}"
      target_branch="${upstream#*/}"
    fi
  fi

  if [ -z "$target_branch" ]; then
    target_branch="$WGX_BASE"
  fi

  if [ -z "$target_branch" ]; then
    target_branch="main"
  fi

  local prefix=""
  if ((dry_run)); then
    prefix="[DRY-RUN] "
  fi

  log_info "${prefix}Fetch von allen Remotes (inkl. prune)…"
  if ((dry_run)); then
    :
  else
    git fetch --all --prune || die "git fetch fehlgeschlagen"
  fi

  if ! git rev-parse --verify "${remote}/${target_branch}" >/dev/null 2>&1; then
    if ((explicit_branch)); then
      die "git_hard_reload: ${remote}/${target_branch} nicht gefunden."
    fi

    remote="origin"
    local candidate=""
    for candidate in "$target_branch" "$WGX_BASE" main master; do
      [ -z "$candidate" ] && continue
      if git rev-parse --verify "origin/${candidate}" >/dev/null 2>&1; then
        target_branch="$candidate"
        break
      fi
    done
  fi

  if [ -z "$target_branch" ] || ! git rev-parse --verify "${remote}/${target_branch}" >/dev/null 2>&1; then
    die "git_hard_reload: Konnte Ziel-Branch nicht bestimmen."
  fi

  log_info "${prefix}Kompletter Reset auf ${remote}/${target_branch}… (alle lokalen Änderungen gehen verloren)"
  if ((dry_run)); then
    :
  else
    git reset --hard "${remote}/${target_branch}" || die "git reset --hard fehlgeschlagen"
  fi

  log_info "${prefix}Untracked/ignored aufräumen (clean -fdx)…"
  if ((dry_run)); then
    :
  else
    git clean -fdx || die "git clean fehlgeschlagen"
  fi

  log_info "${prefix}Reload fertig (${remote}/${target_branch})."
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
  validate)
    _load_modules
    # shellcheck source=/dev/null
    source "${WGX_DIR}/cmd/validate.bash"
    validate::run "$@"
    return
    ;;
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

#!/usr/bin/env bash

# Rolle: WGX-Kernbibliothek
# Diese Datei stellt zentrale, von allen Subkommandos genutzte Funktionen
# bereit. Dazu gehören Logging, Git-Helfer, Environment-Handling und der
# Dispatcher (`wgx_main`), der die Subkommandos aus `cmd/` aufruft.

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

function debug() {
  [[ ${WGX_DEBUG:-0} != 0 ]] || return 0
  [[ ${WGX_QUIET:-0} != 0 ]] && return
  printf 'DEBUG %s\n' "$*" >&2
}

function info() {
  [[ ${WGX_QUIET:-0} != 0 ]] && return
  # Log info to stderr by default to keep stdout clean for pipes/data,
  # unless specifically asked otherwise (legacy behavior is to stdout, but
  # let's standardize on stderr for logs).
  printf '%s %s\n' "$_DOT" "$*" >&2
}

function ok() {
  [[ ${WGX_QUIET:-0} != 0 ]] && return
  printf '%s %s\n' "$_OK" "$*" >&2
}

function warn() {
  printf '%s %s\n' "$_WARN" "$*" >&2
}

function die() {
  printf '%s %s\n' "$_ERR" "$*" >&2
  exit 1
}

# ---------- Env / Defaults ----------
: "${WGX_VERSION:=2.0.3}"
: "${WGX_BASE:=main}"

# ── Module autoload ─────────────────────────────────────────────────────────
_load_modules() {
  local MODULE_DIR="${WGX_PROJECT_ROOT:-$WGX_DIR}/modules"
  if [ -d "$MODULE_DIR" ]; then
    for f in "$MODULE_DIR"/*.bash; do
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
  local CMD_DIR="${WGX_PROJECT_ROOT:-$WGX_DIR}/cmd"
  [ -d "$CMD_DIR" ] || return 0
  for f in "$CMD_DIR"/*.bash; do
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
  local CMD_DIR="${WGX_PROJECT_ROOT:-$WGX_DIR}/cmd"
  local f="${CMD_DIR}/${sub}.bash"
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

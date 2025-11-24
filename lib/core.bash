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
: "${OFFLINE:=0}"
: "${WGX_PR_LABELS:=}"
: "${WGX_AUTO_BRANCH:=0}"
: "${ASSUME_YES:=0}"

# ---------- Utilities ----------

# Check if a command exists
has() {
  command -v "$1" >/dev/null 2>&1
}

# Trim whitespace from a string
trim() {
  local s="$*"
  s="${s#"${s%%[![:space:]]*}"}"
  printf "%s" "${s%"${s##*[![:space:]]}"}"
}

# Check if inside a Git repository
is_git_repo() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1
}

# Require to be inside a Git repository
require_repo() {
  has git || die "git nicht installiert."
  is_git_repo || die "Nicht im Git-Repo."
}

# ---------- Git Remote Helpers ----------

# Parse the remote URL to extract host and path
remote_host_path() {
  local u
  u="$(git remote get-url origin 2>/dev/null || true)"
  [[ -z "$u" ]] && { echo ""; return; }
  case "$u" in
    http*://*/*)
      local rest="${u#*://}"
      local host="${rest%%/*}"
      local path="${rest#*/}"
      echo "$host $path"
      ;;
    ssh://git@*/*)
      local rest="${u#ssh://git@}"
      local host="${rest%%/*}"
      local path="${rest#*/}"
      echo "$host $path"
      ;;
    git@*:*/*)
      local host="${u#git@}"
      host="${host%%:*}"
      local path="${u#*:}"
      echo "$host $path"
      ;;
    *)
      echo ""
      ;;
  esac
}

# Detect the kind of hosting platform (github, gitlab, etc.)
host_kind() {
  local hp host
  hp="$(remote_host_path || true)"
  host="${hp%% *}"
  case "$host" in
    github.com) echo "github" ;;
    gitlab.com) echo "gitlab" ;;
    codeberg.org) echo "codeberg" ;;
    *)
      if [[ "$host" == *gitea* || "$host" == *forgejo* ]]; then
        echo "gitea"
      else
        echo "unknown"
      fi
      ;;
  esac
}

# Generate a compare URL for the current branch vs base
compare_url() {
  local hp host path
  hp="$(remote_host_path || true)"
  [[ -z "$hp" ]] && { echo ""; return; }
  host="${hp%% *}"
  path="${hp#* }"
  path="${path%.git}"
  local branch
  branch="$(git_current_branch)"
  case "$(host_kind)" in
    github) echo "https://$host/$path/compare/${WGX_BASE}...${branch}" ;;
    gitlab) echo "https://$host/$path/-/compare/${WGX_BASE}...${branch}" ;;
    codeberg | gitea) echo "https://$host/$path/compare/${WGX_BASE}...${branch}" ;;
    *) echo "" ;;
  esac
}

# ---------- Auto Scope / Labels ----------

# Automatically detect the scope based on changed files
auto_scope() {
  local files="$1" major="repo" m_web=0 m_api=0 m_docs=0 m_infra=0 m_devx=0 total=0
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    ((++total))
    case "$f" in
      apps/web/*) ((++m_web)) ;;
      apps/api/* | crates/*) ((++m_api)) ;;
      infra/* | deploy/*) ((++m_infra)) ;;
      scripts/* | wgx | .wgx.conf) ((++m_devx)) ;;
      docs/* | *.md | styles/* | .vale.ini) ((++m_docs)) ;;
    esac
  done <<<"$files"
  ((total == 0)) && { echo "repo"; return; }
  local max=$m_docs
  major="docs"
  ((m_web > max)) && { max=$m_web; major="web"; }
  ((m_api > max)) && { max=$m_api; major="api"; }
  ((m_infra > max)) && { max=$m_infra; major="infra"; }
  ((m_devx > max)) && { max=$m_devx; major="devx"; }
  ((max * 100 >= 70 * total)) && echo "$major" || echo "meta"
}

# Derive labels based on branch prefix and scope
derive_labels() {
  local branch scope="$1"
  branch="$(git_current_branch)"
  local pref="${branch%%/*}"
  local L=()
  case "$pref" in
    feat) L+=("feature") ;;
    fix | hotfix) L+=("bug") ;;
    docs) L+=("docs") ;;
    refactor) L+=("refactor") ;;
    test | tests) L+=("test") ;;
    ci) L+=("ci") ;;
    perf) L+=("performance") ;;
    chore) L+=("chore") ;;
    build) L+=("build") ;;
  esac
  case "$scope" in
    web) L+=("area:web") ;;
    api) L+=("area:api") ;;
    infra) L+=("area:infra") ;;
    devx) L+=("area:devx") ;;
    docs) L+=("area:docs") ;;
    meta) L+=("area:meta") ;;
    repo) L+=("area:repo") ;;
  esac
  # Add user-specified labels from ENV
  if [[ -n "${WGX_PR_LABELS-}" ]]; then
    local IFS=','
    local add
    read -ra add <<<"$WGX_PR_LABELS"
    local a
    for a in "${add[@]}"; do
      a="$(trim "$a")"
      [[ -n "$a" ]] && L+=("$a")
    done
  fi
  # Deduplicate
  local out=() seen="" x
  for x in "${L[@]}"; do
    [[ ",$seen," == *",$x,"* ]] && continue
    seen="$seen,$x"
    out+=("$x")
  done
  local IFS=','
  printf "%s" "${out[*]}"
}

# Sanitize a CSV string (trim, dedupe)
_sanitize_csv() {
  local csv="$1" parts=()
  local IFS=','
  read -ra parts <<<"$csv"
  local out=() seen="" p
  for p in "${parts[@]}"; do
    p="$(trim "$p")"
    [[ -z "$p" ]] && continue
    [[ ",$seen," == *",$p,"* ]] && continue
    seen="${seen},$p"
    out+=("$p")
  done
  IFS=','
  printf "%s" "${out[*]}"
}

# ---------- CODEOWNERS Helpers ----------

_codeowners_file() {
  if [[ -f ".github/CODEOWNERS" ]]; then
    echo ".github/CODEOWNERS"
  elif [[ -f "CODEOWNERS" ]]; then
    echo "CODEOWNERS"
  else
    echo ""
  fi
}

# Read file paths from stdin and extract reviewer usernames from CODEOWNERS
_codeowners_reviewers() {
  local cof
  cof="$(_codeowners_file)"
  [[ -z "$cof" ]] && return 0

  local -a CODEOWNERS_PATTERNS=()
  local -a CODEOWNERS_OWNERS=()
  local default_owners=() line

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="$(trim "$line")"
    [[ -z "$line" || "${line:0:1}" == "#" ]] && continue
    line="${line%%#*}"
    line="$(trim "$line")"
    [[ -z "$line" ]] && continue
    local pat rest
    pat="${line%%[[:space:]]*}"
    rest="${line#"$pat"}"
    rest="$(trim "$rest")"
    [[ -z "$pat" || -z "$rest" ]] && continue
    local -a arr
    read -r -a arr <<<"$rest"
    if [[ "$pat" == "*" ]]; then
      default_owners=("${arr[@]}")
    else
      CODEOWNERS_PATTERNS+=("$pat")
      CODEOWNERS_OWNERS+=("$(printf "%s " "${arr[@]}")")
    fi
  done <"$cof"

  local files=() f
  while IFS= read -r f; do
    [[ -n "$f" ]] && files+=("$f")
  done

  # Enable globstar for CODEOWNERS patterns
  local had_globstar=0
  if shopt -q globstar 2>/dev/null; then had_globstar=1; fi
  shopt -s globstar 2>/dev/null || true

  local seen="," i p matchOwners o
  for f in "${files[@]}"; do
    matchOwners=""
    for ((i = 0; i < ${#CODEOWNERS_PATTERNS[@]}; i++)); do
      p="${CODEOWNERS_PATTERNS[$i]}"
      [[ "$p" == /* ]] && p="${p:1}"
      case "$f" in
        $p) matchOwners="${CODEOWNERS_OWNERS[$i]}" ;;
      esac
    done
    [[ -z "$matchOwners" && ${#default_owners[@]} -gt 0 ]] && matchOwners="$(printf "%s " "${default_owners[@]}")"
    for o in $matchOwners; do
      [[ "$o" == @* ]] && o="${o#@}"
      [[ -z "$o" || "$o" == */* ]] && continue # Skip teams (org/team)
      [[ ",$seen," == *,"$o",* ]] && continue
      seen="${seen}${o},"
      printf "%s\n" "$o"
    done
  done

  if ((! had_globstar)); then shopt -u globstar 2>/dev/null || true; fi
}

# ---------- PR Body Rendering ----------

# Render PR body from template
# Note: title argument is kept for API compatibility but short is used as the heading
render_pr_body() {
  local _title="$1" short="$2" why="$3" tests="$4" issue="$5" notes="$6"
  cat <<EOF
## ${short}

### Warum?
${why}

### Tests
${tests}

### Notizen
${notes:-"—"}
EOF
  if [[ -n "$issue" ]]; then
    printf '\n### Verknüpfte Issues\n'
    printf 'Closes #%s\n' "$issue"
  fi
}

# ---------- Fetch Helpers ----------

_WGX_FETCH_DONE=""

# Fetch from origin once per session
# Uses global OFFLINE variable (defaults to 0, set in env/defaults section)
_fetch_once() {
  [[ -n "${_WGX_FETCH_DONE-}" ]] && return 0
  ((OFFLINE)) && { debug "offline: skip fetch"; return 0; }
  if git fetch -q --prune origin 2>/dev/null; then
    _WGX_FETCH_DONE=1
    return 0
  else
    warn "git fetch origin fehlgeschlagen"
    return 1
  fi
}

# Guard function for fetch (alias for _fetch_once)
_fetch_guard() {
  _fetch_once
}

# ---------- Sync Command ----------

# Sync local branch with remote (pull --rebase)
cmd_sync() {
  require_repo
  local sign="" scope="" base="$WGX_BASE"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --sign) sign="--gpg-sign" ;;
      --scope) shift; scope="${1:-}" ;;
      --base) shift; base="${1:-$WGX_BASE}" ;;
      *) ;;
    esac
    shift || true
  done

  _fetch_once || true

  local br
  br="$(git_current_branch)"

  if ((WGX_AUTO_BRANCH)) && [[ "$br" == "$base" ]]; then
    local ts
    ts="$(date +%y%m%d%H%M)"
    local nb="feat/wgx-$ts"
    git switch -c "$nb" || return 1
    ok "Neuer Arbeits-Branch: $nb"
  fi

  git pull --rebase --autostash --ff-only 2>/dev/null || {
    warn "Fast-Forward nicht möglich – versuche rebase auf origin/$base"
    git fetch -q origin "$base" 2>/dev/null || true
    git rebase "origin/$base" ${sign:+"$sign"} || {
      die "Rebase fehlgeschlagen – bitte wgx heal benutzen."
    }
  }
  ok "Sync abgeschlossen."
}

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

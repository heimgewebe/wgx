### 📄 archiv/wgx

**Größe:** 76 KB | **md5:** `1097bc36767964e98d5c39ddf0dbcfe2`

```plaintext
#!/usr/bin/env bash
# wgx – Weltgewebe CLI · Termux/WSL/macOS/Linux · origin-first
# Version: v2.0.0
# Lizenz: MIT (projektintern); Autorenteam: weltweberei.org
#
# RC-Codes:
#   0 = OK, 1 = WARN (fortsetzbar), 2 = BLOCKER (Abbruch)
#
# OFFLINE:  deaktiviert Netzwerkaktionen bestmöglich (fetch, npx pulls etc.)
# DRYRUN :  zeigt Kommandos an, führt sie aber nicht aus (wo sinnvoll)

# ─────────────────────────────────────────────────────────────────────────────
# SAFETY / SHELL MODE
# ─────────────────────────────────────────────────────────────────────────────
set -e
set -u
set -E
if ! set -o pipefail 2>/dev/null; then
  if [[ ${WGX_DEBUG:-0} != 0 ]]; then
    echo "archiv/wgx: 'pipefail' wird nicht unterstützt; fahre ohne fort." >&2
  fi
fi
IFS=$'\n\t'
umask 077
shopt -s extglob nullglob

# stabile Locale für Parser/Sort/Grep
export LC_ALL=C LANG=C

# optionaler Schreibschutz gegen versehentliches '>'
# (bewusst: wer überschreiben will, nutzt >|)
set -o noclobber

trap 'ec=$?; cmd=$BASH_COMMAND; line=${BASH_LINENO[0]}; fn=${FUNCNAME[1]:-MAIN}; \
      ((ec)) && printf "❌ wgx: Fehler in %s (Zeile %s): %s (exit=%s)\n" \
      "$fn" "$line" "$cmd" "$ec" >&2' ERR

WGX_VERSION="2.0.0"
RC_OK=0; RC_WARN=1; RC_BLOCK=2

# Früh-Exit für Versionsabfrage (auch ohne Git-Repo nutzbar)
if [[ "${1-}" == "--version" || "${1-}" == "-V" ]]; then
  printf "wgx v%s\n" "$WGX_VERSION"
  exit 0
fi

# ─────────────────────────────────────────────────────────────────────────────
# LOG / UI HELPERS
# ─────────────────────────────────────────────────────────────────────────────
_ok()   { printf "✅ %s\n" "$*"; }
_warn() { printf "⚠️  %s\n" "$*" >&2; }
_err()  { printf "❌ %s\n" "$*" >&2; }
info()  { printf "• %s\n"  "$*"; }
die()   { _err "$*"; exit 1; }
ok()    { _ok "$@"; }
warn()  { _warn "$@"; }
logv()  { ((VERBOSE)) && printf "… %s\n" "$*"; }
has()   { command -v "$1" >/dev/null 2>&1; }

trim()     { local s="$*"; s="${s#"${s%%[![:space:]]*}"}"; printf "%s" "${s%"${s##*[![:space:]]}"}"; }
to_lower() { tr '[:upper:]' '[:lower:]'; }

# Prompt liest vorzugsweise aus TTY (robust in Pipes/CI)
read_prompt() { # read_prompt var "Frage?" "default"
  local __v="$1"; shift
  local q="${1-}"; shift || true
  local d="${1-}"
  local ans
  if [[ -t 0 && -r /dev/tty ]]; then
    printf "%s " "$q"
    IFS= read -r ans < /dev/tty || ans="$d"
  else
    ans="$d"
  fi
  [[ -z "$ans" ]] && ans="$d"
  printf -v "$__v" "%s" "$ans"
}

# ─────────────────────────────────────────────────────────────────────────────
# GLOBAL DEFAULTS
# ─────────────────────────────────────────────────────────────────────────────
: "${ASSUME_YES:=0}"
: "${DRYRUN:=0}"
: "${TIMEOUT:=0}"      # 0 = kein Timeout
: "${NOTIMEOUT:=0}"    # 1 = Timeout unterdrücken
: "${VERBOSE:=0}"
: "${OFFLINE:=0}"

: "${WGX_BASE:=main}"
: "${WGX_SIGNING:=auto}"          # auto|ssh|gpg|off
: "${WGX_PREVIEW_DIFF_LINES:=120}"
: "${WGX_PR_LABELS:=}"
: "${WGX_CI_WORKFLOW:=CI}"
: "${WGX_AUTO_BRANCH:=0}"
: "${WGX_PM:=}"                   # pnpm|npm|yarn (leer = auto)

# ─────────────────────────────────────────────────────────────────────────────
# PLATFORM / ENV
# ─────────────────────────────────────────────────────────────────────────────
PLATFORM="linux"
case "$(uname -s 2>/dev/null || echo x)" in
  Darwin) PLATFORM="darwin" ;;
  *)      PLATFORM="linux"  ;;
esac
is_wsl() { uname -r 2>/dev/null | grep -qiE 'microsoft|wsl2?'; }
is_termux() {
  [[ "${PREFIX-}" == *"/com.termux/"* ]] && return 0
  command -v termux-setup-storage >/dev/null 2>&1 && return 0
  return 1
}
is_codespace() { [[ -n "${CODESPACE_NAME-}" ]]; }

# ─────────────────────────────────────────────────────────────────────────────
# REPO KONTEXT
# ─────────────────────────────────────────────────────────────────────────────
is_git_repo() { git rev-parse --is-inside-work-tree >/dev/null 2>&1; }
require_repo() {
  has git || die "git nicht installiert."
  is_git_repo || die "Nicht im Git-Repo (wgx benötigt ein Git-Repository)."
}

# Portables readlink -f
_root_resolve() {
  local here="$1"
  if command -v greadlink >/dev/null 2>&1; then greadlink -f "$here"
  elif command -v readlink >/dev/null 2>&1 && readlink -f / >/dev/null 2>&1; then readlink -f "$here"
  else
    local target="$here" link base
    while link="$(readlink "$target" 2>/dev/null)"; do
      case "$link" in
        /*) target="$link" ;;
        *)  base="$(cd "$(dirname "$target")" && pwd -P)"; target="$base/$link" ;;
      esac
    done
    printf "%s" "$target"
  fi
}

ROOT() {
  local here; here="$(_root_resolve "${BASH_SOURCE[0]}")"
  local fallback; fallback="$(cd "$(dirname "$here")/.." && pwd -P)"
  local r; r="$(git -C "${PWD}" rev-parse --show-toplevel 2>/dev/null || true)"
  [[ -n "$r" ]] && printf "%s" "$r" || printf "%s" "$fallback"
}

# Repo-Root heuristisch (wgx liegt i.d.R. als cli/wgx/wgx)
if r="$(git rev-parse --show-toplevel 2>/dev/null)"; then
  ROOT_DIR="$r"
else
  here="${BASH_SOURCE[0]}"
  base="$(cd "$(dirname "$here")" && pwd -P)"
  if [[ "$(basename "$base")" == "wgx" && "$(basename "$(dirname "$base")")" == "cli" ]]; then
    ROOT_DIR="$(cd "$base/../.." && pwd -P)"
  else
    ROOT_DIR="$(cd "$base/.." && pwd -P)"
  fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# CONFIG (.wgx.conf) EINLESEN – eval-frei & strikt
# ─────────────────────────────────────────────────────────────────────────────
# Erlaubte Schlüssel: nur A–Z, 0–9 und _
# Werte: CR abschneiden, keine Command-Substitution/Backticks/Nullbytes
if [[ -f "$ROOT_DIR/.wgx.conf" ]]; then
  while IFS='=' read -r k v; do
    k="$(trim "$k")"
    [[ -z "$k" || "$k" =~ ^# ]] && continue
    if [[ "$k" =~ ^[A-Z0-9_]+$ ]]; then
      v="${v%$'\r'}"
      [[ "$v" == *'$('* || "$v" == *'`'* || "$v" == *$'\0'* ]] && { warn ".wgx.conf: unsicherer Wert für $k ignoriert"; continue; }
      printf -v _sanitized "%s" "$v"
      declare -x "$k=$_sanitized"
    else
      warn ".wgx.conf: ungültiger Schlüssel '%s' ignoriert" "$k"
    fi
  done < "$ROOT_DIR/.wgx.conf"
fi

# ─────────────────────────────────────────────────────────────────────────────
# KLEINE PORTABILITÄTS-HELFER
# ─────────────────────────────────────────────────────────────────────────────
file_size_bytes() { # Linux/macOS/Busybox
  local f="$1" sz=0
  if   stat -c %s "$f" >/dev/null 2>&1; then sz=$(stat -c %s "$f")
  elif stat -f%z "$f" >/dev/null 2>&1;      then sz=$(stat -f%z "$f")
  else sz=$(wc -c < "$f" 2>/dev/null || echo 0); fi
  printf "%s" "$sz"
}

git_supports_magic() { git -C "$1" ls-files -z -- ':(exclude)node_modules/**' >/dev/null 2>&1; }

mktemp_portable() {
  local p="${1:-wgx}"
  if has mktemp; then
    mktemp -t "${p}.XXXXXX" 2>/dev/null || { local f="${TMPDIR:-/tmp}/${p}.$$.tmp"; : > "$f" && printf "%s" "$f"; }
  else
    local f="${TMPDIR:-/tmp}/${p}.$(date +%s).$$"
    : > "$f" || die "Konnte temporäre Datei nicht erstellen: $f"
    printf "%s" "$f"
  fi
}
now_ts() { date +"%Y-%m-%d %H:%M"; }

# Validierung & Flag-Ermittlung für Commit-Signing
maybe_sign_flag() {
  case "${WGX_SIGNING}" in
    off)  return 1 ;;
    ssh)  has git && git config --get gpg.format 2>/dev/null | grep -qi 'ssh' && echo "-S" || return 1 ;;
    gpg)  has gpg && echo "-S" || return 1 ;;
    auto) git config --get user.signingkey >/dev/null 2>&1 && echo "-S" || return 1 ;;
    *)    return 1 ;;
  esac
}

# Optionaler Timeout-Wrapper
with_timeout() {
  local t="${TIMEOUT:-0}"
  (( NOTIMEOUT )) && exec "$@"
  (( t>0 )) && command -v timeout >/dev/null 2>&1 && timeout "$t" "$@" || exec "$@"
}

# ─────────────────────────────────────────────────────────────────────────────
# GIT HELPERS
# ─────────────────────────────────────────────────────────────────────────────
git_branch() { git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "HEAD"; }
git_in_progress() {
  [[ -d .git/rebase-merge || -d .git/rebase-apply || -f .git/MERGE_HEAD ]]
}

# OFFLINE-freundlich, mit sichtbarer Warnung bei Fehler
_fetch_guard() {
  ((OFFLINE)) && { logv "offline: skip fetch"; return 0; }
  if ! git fetch -q origin 2>/dev/null; then
    warn "git fetch origin fehlgeschlagen (Netz/Origin?)."
    return 1
  fi
}

remote_host_path() {
  local u; u="$(git remote get-url origin 2>/dev/null || true)"
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
      local host="${u#git@}"; host="${host%%:*}"
      local path="${u#*:}"
      echo "$host $path"
      ;;
    *) echo "";;
  esac
}
host_kind() { # erkannt: github, gitlab, codeberg, gitea (catch-all: gitea für fremde Hosts)
  local hp host; hp="$(remote_host_path || true)"; host="${hp%% *}"
  case "$host" in
    github.com) echo github ;;
    gitlab.com) echo gitlab ;;
    codeberg.org) echo codeberg ;;
    *)
      # Heuristik: beliebige eigene Gitea-Instanzen (host enthält gitea|forgejo?) → gitea
      if [[ "$host" == *gitea* || "$host" == *forgejo* ]]; then echo gitea; else echo unknown; fi
      ;;
  esac
}
compare_url() { # triple-dot base...branch (für github/gitlab/codeberg/gitea)
  local hp host path; hp="$(remote_host_path || true)"; [[ -z "$hp" ]] && { echo ""; return; }
  host="${hp%% *}"; path="${hp#* }"; path="${path%.git}"
  case "$(host_kind)" in
    github)   echo "https://$host/$path/compare/${WGX_BASE}...$(git_branch)";;
    gitlab)   echo "https://$host/$path/-/compare/${WGX_BASE}...$(git_branch)";;
    codeberg) echo "https://$host/$path/compare/${WGX_BASE}...$(git_branch)";;
    gitea)    echo "https://$host/$path/compare/${WGX_BASE}...$(git_branch)";;
    *)        echo "";;
  esac
}

git_ahead_behind() {
  local b="${1:-$(git_branch)}"
  ((OFFLINE)) || git fetch -q origin "$b" 2>/dev/null || true
  local ab; ab="$(git rev-list --left-right --count "origin/$b...$b" 2>/dev/null || echo "0 0")"
  local behind=0 ahead=0 IFS=' '
  read -r behind ahead <<<"$ab" || true
  printf "%s %s\n" "${behind:-0}" "${ahead:-0}"
}
ab_read() { local ref="$1" ab; ab="$(git_ahead_behind "$ref" 2>/dev/null || echo "0 0")"; set -- $ab; echo "${1:-0} ${2:-0}"; }

detect_web_dir() { for d in apps/web web; do [[ -d "$d" ]] && { echo "$d"; return; }; done; echo ""; }
detect_api_dir() { for d in apps/api api crates; do [[ -f "$d/Cargo.toml" ]] && { echo "$d"; return; }; done; echo ""; }

run_with_files_xargs0() {
  local title="$1"; shift
  if [[ -t 1 ]]; then info "$title"; fi
  if command -v xargs >/dev/null 2>&1; then
    xargs -0 "$@" || return $?
  else
    local buf=() f
    while IFS= read -r -d '' f; do buf+=("$f"); done
    [[ $# -gt 0 ]] && "$@" "${buf[@]}"
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# GLOBAL FLAG PARSER (bis SUB-Kommando)
# ─────────────────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes) ASSUME_YES=1 ;;
    --dry-run) DRYRUN=1 ;;
    --timeout) shift; [[ "${1-}" =~ ^[0-9]+$ ]] || die "--timeout braucht Zahl"; TIMEOUT="$1" ;;
    --no-timeout) NOTIMEOUT=1 ;;
    --verbose) VERBOSE=1 ;;
    --base) shift; WGX_BASE="${1-}" ;;
    --offline) OFFLINE=1 ;;
    --no-color) : ;; # wir nutzen Emojis → no-op
    send|sync|guard|heal|reload|clean|doctor|init|setup|lint|start|release|hooks|version|env|quick|config|test|selftest|help|-h|--help|status)
      break ;;
    *) warn "Unbekanntes globales Argument ignoriert: $1" ;;
  esac
  shift || true
done
SUB="${1-}"; shift || true

# ─────────────────────────────────────────────────────────────────────────────
# STATUS (kompakt)
# ─────────────────────────────────────────────────────────────────────────────
status_cmd() {
  if ! is_git_repo; then
    echo "=== wgx status ==="
    echo "root : $ROOT_DIR"
    echo "repo : (kein Git-Repo)"
    ok "Status OK"
    return $RC_OK
  fi
  local br web api behind=0 ahead=0
  br="$(git_branch)"; web="$(detect_web_dir || true)"; api="$(detect_api_dir || true)"
  local IFS=' '; read -r behind ahead < <(git_ahead_behind "$br") || true
  echo "=== wgx status ==="
  echo "root : $ROOT_DIR"
  echo "branch: $br (ahead:$ahead behind:$behind)  base:$WGX_BASE"
  echo "web  : ${web:-nicht gefunden}"
  echo "api  : ${api:-nicht gefunden}"
  (( OFFLINE )) && echo "mode : offline"
  ok "Status OK"
}

# ─────────────────────────────────────────────────────────────────────────────
# VALE / SPRACHE (optional)
# ─────────────────────────────────────────────────────────────────────────────
vale_maybe() {
  [[ -f ".vale.ini" ]] || return 0
  has vale || { warn "Vale nicht installiert – Sprach-Checks übersprungen."; return 0; }
  local staged=0; [[ "${1-}" == "--staged" ]] && staged=1
  if (( staged )); then
    if ! git diff --cached --name-only -z -- '*.md' 2>/dev/null | { IFS= read -r -d '' _; }; then
      return 0
    fi
    git diff --cached --name-only -z -- '*.md' 2>/dev/null \
      | run_with_files_xargs0 "Vale (staged)" vale
    return $?
  else
    if [[ -z "$(git ls-files -z -- '*.md' 2>/dev/null | head -c1)" ]]; then
      return 0
    fi
    git ls-files -z -- '*.md' 2>/dev/null \
      | run_with_files_xargs0 "Vale (alle .md)" vale
    return $?
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# PREFLIGHT / GUARD (inkl. Secrets, Conflicts, Big Files)
# ─────────────────────────────────────────────────────────────────────────────
changed_files_cached() { require_repo; git diff --cached --name-only -z | tr '\0' '\n' | sed '/^$/d'; }

# NUL-sicher inkl. Renames
changed_files_all() {
  require_repo
  local rec status path
  git status --porcelain -z \
  | while IFS= read -r -d '' rec; do
      status="${rec:0:2}"
      path="${rec:3}"
      if [[ "$status" =~ ^R ]]; then
        IFS= read -r -d '' path || true
      fi
      [[ -n "$path" ]] && printf '%s\n' "$path"
    done
}

auto_scope() {
  local files="$1" major="repo" m_web=0 m_api=0 m_docs=0 m_infra=0 m_devx=0 total=0
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    ((++total))
    case "$f" in
      apps/web/*) ((++m_web));;
      apps/api/*|crates/*) ((++m_api));;
      infra/*|deploy/*) ((++m_infra));;
      scripts/*|wgx|.wgx.conf) ((++m_devx));;
      docs/*|*.md|styles/*|.vale.ini) ((++m_docs));;
    esac
  done <<< "$files"
  (( total==0 )) && { echo "repo"; return; }
  local max=$m_docs; major="docs"
  (( m_web>max ))  && { max=$m_web;  major="web"; }
  (( m_api>max ))  && { max=$m_api;  major="api"; }
  (( m_infra>max ))&& { max=$m_infra; major="infra"; }
  (( m_devx>max )) && { max=$m_devx; major="devx"; }
  (( max * 100 >= 70 * total )) && echo "$major" || echo "meta"
}

# Basis-Branch verifizieren (nicht-blockierend, aber warnend)
validate_base_branch() {
  ((OFFLINE)) && return 0
  git rev-parse --verify "refs/remotes/origin/$WGX_BASE" >/dev/null 2>&1 || {
    warn "Basis-Branch origin/%s fehlt oder ist nicht erreichbar." "$WGX_BASE"
    return 1
  }
}

guard_run() {
  require_repo
  local FIX=0 LINT_OPT=0 TEST_OPT=0 DEEP_SCAN=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --fix) FIX=1;;
      --lint) LINT_OPT=1;;
      --test) TEST_OPT=1;;
      --deep-scan) DEEP_SCAN=1;;
      *) ;;
    esac
    shift || true
  done

  local rc=$RC_OK br; br="$(git_branch)"
  echo "=== Preflight (branch: $br, base: $WGX_BASE) ==="

  _fetch_guard || (( rc=rc<RC_WARN ? RC_WARN : rc ))
  validate_base_branch || (( rc=rc<RC_WARN ? RC_WARN : rc ))

  if git_in_progress; then
    echo "[BLOCKER] rebase/merge läuft → wgx heal --continue | --abort"
    rc=$RC_BLOCK
  fi
  [[ "$br" == "HEAD" ]] && { echo "[WARN] Detached HEAD – Branch anlegen."; (( rc==RC_OK )) && rc=$RC_WARN; }

  local behind=0 ahead=0 IFS=' '
  read -r behind ahead < <(git_ahead_behind "$br") || true
  if (( behind>0 )); then
    echo "[WARN] Branch $behind hinter origin/$br → rebase auf origin/$WGX_BASE"
    if (( FIX )); then
      git fetch -q origin "$WGX_BASE" 2>/dev/null || true
      git rebase "origin/$WGX_BASE" || rc=$RC_BLOCK
    fi
    (( rc==RC_OK )) && rc=$RC_WARN
  fi

  # Konfliktmarker in modifizierten Dateien
  local with_markers=""
  while IFS= read -r -d '' f; do
    [[ -z "$f" ]] && continue
    grep -Eq '<<<<<<<|=======|>>>>>>>' -- "$f" 2>/dev/null && with_markers+="$f"$'\n'
  done < <(git ls-files -m -z)
  if [[ -n "$with_markers" ]]; then
    echo "[BLOCKER] Konfliktmarker:"
    printf '%s' "$with_markers" | sed 's/^/  - /'
    rc=$RC_BLOCK
  fi

  # Secret-/Größen-Checks auf staged
  local staged; staged="$(changed_files_cached || true)"
  if [[ -n "$staged" ]]; then
    local secrets
    secrets="$(printf "%s\n" "$staged" | grep -Ei '\.env(\.|$)|(^|/)(id_rsa|id_ed25519)(\.|$)|\.pem$|\.p12$|\.keystore$' || true)"
    if [[ -n "$secrets" ]]; then
      echo "[BLOCKER] mögliche Secrets im Commit (Dateinamen-Match):"
      printf "%s\n" "$secrets" | sed 's/^/  - /'
      if (( FIX )); then
        while IFS= read -r s; do
          [[ -n "$s" ]] && git restore --staged -- "$s" 2>/dev/null || true
        done <<< "$secrets"
        echo "→ Secrets aus dem Index entfernt (Dateien bleiben lokal)."
      fi
      rc=$RC_BLOCK
    fi

    if (( DEEP_SCAN )); then
      local leaked
      leaked="$(git diff --cached -U0 \
        | grep -Ei 'BEGIN (RSA|EC|OPENSSH) PRIVATE KEY|AKIA[A-Z0-9]{16}|ghp_[A-Za-z0-9]{36}|glpat-[A-Za-z0-9_-]{20,}|AWS_ACCESS_KEY_ID|SECRET(_KEY)?|TOKEN|AUTHORIZATION:|PASSWORD' \
        || true)"
      if [[ -n "$leaked" ]]; then
        echo "[BLOCKER] möglicher Secret-Inhalt im Diff:"
        echo "$leaked" | sed 's/^/  > /'
        rc=$RC_BLOCK
      fi
    fi

    # Big Files > 10MB (portabel)
    local big=0; while IFS= read -r f; do
      [[ -f "$f" ]] || continue
      sz="$(file_size_bytes "$f")"
      if (( sz>10485760 )); then
        ((big++))
        printf '  - %s (%s B)\n' "$f" "$sz"
      fi
    done <<< "$staged"
    if (( big>0 )); then
      echo "[WARN] >10MB im Commit (siehe Liste oben)."
      (( rc==RC_OK )) && rc=$RC_WARN
    fi
  fi

  # Lockfile-Mix
  if git ls-files --error-unmatch pnpm-lock.yaml >/dev/null 2>&1 &&
     git ls-files --error-unmatch package-lock.json >/dev/null 2>&1; then
    echo "[WARN] pnpm-lock.yaml UND package-lock.json im Repo – Policy klären."
    (( rc==RC_OK )) && rc=$RC_WARN
  fi

  # Vale (nur Rückgabecode bewerten)
  if [[ -f ".vale.ini" ]]; then
    vale_maybe --staged || (( rc==RC_OK )) && rc=$RC_WARN
  fi

  case "$rc" in
    0) ok "Preflight sauber.";;
    1) warn "Preflight mit Warnungen.";;
    2) die "Preflight BLOCKER → bitte Hinweise beachten.";;
  esac
  printf "%s\n" "$rc"
}

# ─────────────────────────────────────────────────────────────────────────────
# SNAPSHOT (git stash)
# ─────────────────────────────────────────────────────────────────────────────
snapshot_make() {
  require_repo
  if [[ -z "$(git status --porcelain -z 2>/dev/null | head -c1)" ]]; then
    info "Kein Snapshot nötig (Arbeitsbaum sauber)."
    return 0
  fi
  local msg="snapshot@$(date +%s) $(git_branch)"
  git stash push -u -m "$msg" >/dev/null 2>&1 || true
  info "Snapshot erstellt (git stash list)."
}

# ─────────────────────────────────────────────────────────────────────────────
# LINT / TEST
# ─────────────────────────────────────────────────────────────────────────────
pm_detect() {
  local wd="$1"
  if [[ -n "${WGX_PM-}" ]]; then
    if has "$WGX_PM"; then echo "$WGX_PM"; return 0
    else warn "WGX_PM=$WGX_PM nicht gefunden, Auto-Detect aktiv."; fi
  fi
  if   [[ -f "$wd/pnpm-lock.yaml" ]] && has pnpm; then echo "pnpm"
  elif [[ -f "$wd/package-lock.json" ]] && has npm;  then echo "npm"
  elif [[ -f "$wd/yarn.lock"      ]] && has yarn; then echo "yarn"
  elif [[ -f "$wd/package.json"   ]]; then
    has pnpm && echo "pnpm" || has npm && echo "npm" || has yarn && echo "yarn" || echo ""
  else
    echo ""
  fi
}

run_soft() {
  local title="$1"; shift || true
  local rc=0
  if (( DRYRUN )); then
    if [[ $# -gt 0 ]]; then
      printf "DRY: %s → %q" "$title" "$1"; shift || true
      while [[ $# -gt 0 ]]; do printf " %q" "$1"; shift || true; done
      echo
    else
      printf "DRY: %s (kein Befehl übergeben)\n" "$title"
    fi
    return 0
  fi
  info "$title"
  if "$@"; then ok "$title ✓"; rc=0; else warn "$title ✗"; rc=1; fi
  printf "%s\n" "$rc"; return 0
}

lint_cmd() {
  require_repo
  local rc_total=$RC_OK

  # Vale
  vale_maybe || rc_total=$RC_WARN

  # Markdownlint (wenn vorhanden)
  if has markdownlint; then
    if [[ -n "$(git ls-files -z -- '*.md' 2>/dev/null | head -c1)" ]]; then
      git ls-files -z -- '*.md' 2>/dev/null \
        | run_with_files_xargs0 "markdownlint" markdownlint || rc_total=$RC_WARN
    fi
  fi

  # Web (Prettier/ESLint)
  local wd; wd="$(detect_web_dir || true)"
  if [[ -n "$wd" ]]; then
    local pm; pm="$(pm_detect "$wd")"
    local prettier_cmd="" eslint_cmd=""
    case "$pm" in
      pnpm) prettier_cmd="pnpm -s exec prettier"; eslint_cmd="pnpm -s exec eslint" ;;
      yarn) prettier_cmd="yarn -s prettier";     eslint_cmd="yarn -s eslint" ;;
      npm|"") prettier_cmd="npx --yes prettier"; eslint_cmd="npx --yes eslint" ;;
    esac

    if (( OFFLINE )); then
      [[ "$pm" == "npm" || "$pm" == "" ]] && warn "Offline: npx evtl. nicht verfügbar → Prettier/ESLint ggf. übersprungen."
    fi

    local has_gnu_find=0
    if find --version >/dev/null 2>&1; then
      find --version 2>/dev/null | grep -q GNU && has_gnu_find=1
    fi

    # Prettier Check (große Dateimengen effizient, node_modules/dist/build ausgeschlossen)
    if (( ! OFFLINE )); then
      if git_supports_magic "$wd" && (( has_gnu_find )); then
        git -C "$wd" ls-files -z \
          -- ':(exclude)node_modules/**' ':(exclude)dist/**' ':(exclude)build/**' \
             '*.js' '*.ts' '*.tsx' '*.jsx' '*.json' '*.css' '*.scss' '*.md' '*.svelte' 2>/dev/null \
        | run_with_files_xargs0 "Prettier Check" \
            sh -c 'cd "$1"; shift; '"$prettier_cmd"' -c -- "$@"' _ "$wd" \
        || run_with_files_xargs0 "Prettier Check (fallback npx)" \
            sh -c 'cd "$1"; shift; npx --yes prettier -c -- "$@"' _ "$wd" \
        || rc_total=$RC_WARN
      else
        find "$wd" \( -path "$wd/node_modules" -o -path "$wd/dist" -o -path "$wd/build" \) -prune -o \
             -type f \( -name '*.js' -o -name '*.ts' -o -name '*.tsx' -o -name '*.jsx' -o -name '*.json' -o -name '*.css' -o -name '*.scss' -o -name '*.md' -o -name '*.svelte' \) -print0 \
        | while IFS= read -r -d '' f; do rel="${f#$wd/}"; printf '%s\0' "$rel"; done \
        | run_with_files_xargs0 "Prettier Check" \
            sh -c 'cd "$1"; shift; '"$prettier_cmd"' -c -- "$@"' _ "$wd" \
        || { 
             if (( ! OFFLINE )); then
               run_with_files_xargs0 "Prettier Check (fallback npx)" \
                 sh -c 'cd "$1"; shift; npx --yes prettier -c -- "$@"' _ "$wd"
             fi
           } \
        || rc_total=$RC_WARN
      fi
    fi

    # ESLint (nur wenn Konfig vorhanden)
    local has_eslint_cfg=0
    [[ -f "$wd/.eslintrc" || -f "$wd/.eslintrc.js" || -f "$wd/.eslintrc.cjs" || -f "$wd/.eslintrc.json" \
       || -f "$wd/eslint.config.js" || -f "$wd/eslint.config.mjs" || -f "$wd/eslint.config.cjs" ]] && has_eslint_cfg=1
    if (( has_eslint_cfg )); then
      run_soft "ESLint" bash -c "cd '$wd' && $eslint_cmd -v >/dev/null 2>&1 && $eslint_cmd . --ext .js,.cjs,.mjs,.ts,.tsx,.svelte" \
      || { if (( OFFLINE )); then warn "ESLint übersprungen (offline)"; false; \
           else run_soft "ESLint (fallback npx)" \
                  bash -c "cd '$wd' && npx --yes eslint . --ext .js,.cjs,.mjs,.ts,.tsx,.svelte"; fi; } \
      || rc_total=$RC_WARN
    fi
  fi

  # Rust (fmt + clippy, falls vorhanden)
  local ad; ad="$(detect_api_dir || true)"
  if [[ -n "$ad" && -f "$ad/Cargo.toml" ]] && has cargo; then
    run_soft "cargo fmt --check" bash -lc "cd '$ad' && cargo fmt --all -- --check" || rc_total=$RC_WARN
    if rustup component list 2>/dev/null | grep -q 'clippy.*(installed)'; then
      run_soft "cargo clippy (Hinweise)" bash -lc "cd '$ad' && cargo clippy --all-targets --all-features -q" || rc_total=$RC_WARN
    else
      warn "clippy nicht installiert – übersprungen."
    fi
  fi

  # Shell / Dockerfiles / Workflows
  if has shellcheck; then
    if [[ -n "$(git ls-files -z -- '*.sh' 2>/dev/null | head -c1)" || -f "./wgx" || -d "./scripts" ]]; then
      { git ls-files -z -- '*.sh' 2>/dev/null; git ls-files -z -- 'wgx' 'scripts/*' 2>/dev/null; } \
        | run_with_files_xargs0 "shellcheck" shellcheck || rc_total=$RC_WARN
    fi
  fi
  if has hadolint; then
    if [[ -n "$(git ls-files -z -- '*Dockerfile*' 2>/dev/null | head -c1)" ]]; then
      git ls-files -z -- '*Dockerfile*' 2>/dev/null \
        | run_with_files_xargs0 "hadolint" hadolint || rc_total=$RC_WARN
    fi
  fi
  if has actionlint && [[ -d ".github/workflows" ]]; then run_soft "actionlint" actionlint || rc_total=$RC_WARN; fi

  (( rc_total==RC_OK )) && ok "Lint OK" || warn "Lint mit Hinweisen (rc=$rc_total)."
  printf "%s\n" "$rc_total"; return 0
}

pm_test() {
  local wd="$1"; local pm; pm="$(pm_detect "$wd")"
  case "$pm" in
    pnpm) (cd "$wd" && pnpm -s test -s) ;;
    npm)  (cd "$wd" && npm test -s) ;;
    yarn) (cd "$wd" && yarn -s test) ;;
    *)    return 0 ;;
  esac
}

test_cmd() {
  require_repo
  local rc_web=0 rc_api=0 wd ad pid_web= pid_api=
  trap '[[ -n "${pid_web-}" ]] && kill "$pid_web" 2>/dev/null || true; [[ -n "${pid_api-}" ]] && kill "$pid_api" 2>/dev/null || true' INT
  wd="$(detect_web_dir || true)"; ad="$(detect_api_dir || true)"
  if [[ -n "$wd" && -f "$wd/package.json" ]]; then
    info "Web-Tests…"; ( pm_test "$wd" ) & pid_web=$!
  fi
  if [[ -n "$ad" && -f "$ad/Cargo.toml" ]] && has cargo; then
    info "Rust-Tests…"; ( cd "$ad" && cargo test --all --quiet ) & pid_api=$!
  fi
  if [[ -n "${pid_web-}" ]]; then wait "$pid_web" || rc_web=1; fi
  if [[ -n "${pid_api-}" ]]; then wait "$pid_api" || rc_api=1; fi
  (( rc_web==0 && rc_api==0 )) && ok "Tests OK" || {
    [[ $rc_web -ne 0 ]] && warn "Web-Tests fehlgeschlagen."
    [[ $rc_api -ne 0 ]] && warn "Rust-Tests fehlgeschlagen."
    return 1
  }
}
# ─────────────────────────────────────────────────────────────────────────────
# Block 2 – Sicherheitsshims & Defaults (nur wirksam, wenn upstream fehlt)
# ─────────────────────────────────────────────────────────────────────────────
: "${WGX_BASE:=main}"
: "${WGX_PREVIEW_DIFF_LINES:=120}"
: "${WGX_CI_WORKFLOW:=CI}"
: "${OFFLINE:=0}"
: "${ASSUME_YES:=0}"
: "${DRYRUN:=0}"

# Mini-Logger & Guards
if ! type -t has >/dev/null 2>&1; then
  has() {
    command -v "$1" >/dev/null 2>&1
  }
fi
if ! type -t info >/dev/null 2>&1; then
  info() {
    printf '• %s\n' "$*"
  }
fi
if ! type -t ok >/dev/null 2>&1; then
  ok() {
    printf '✅ %s\n' "$*"
  }
fi
if ! type -t warn >/dev/null 2>&1; then
  warn() {
    printf '⚠️  %s\n' "$*" >&2
  }
fi
if ! type -t die >/dev/null 2>&1; then
  die() {
    printf '❌ %s\n' "$*" >&2
    exit 1
  }
fi

# Utils
if ! type -t trim >/dev/null 2>&1; then
  trim() {
    local s="$*"
    s="${s#"${s%%[![:space:]]*}"}"
    printf "%s" "${s%"${s##*[![:space:]]}"}"
  }
fi
if ! type -t to_lower >/dev/null 2>&1; then
  to_lower() {
    printf '%s' "$*" | tr '[:upper:]' '[:lower:]'
  }
fi

# Git-Hilfen
if ! type -t git_branch >/dev/null 2>&1; then
  git_branch() {
    git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "HEAD"
  }
fi
if ! type -t git_ahead_behind >/dev/null 2>&1; then
  git_ahead_behind() {
    local b="${1:-$(git_branch)}"
    git rev-list --left-right --count "origin/$b...$b" 2>/dev/null | awk '{print ($1?$1:0), ($2?$2:0)}'
  }
fi
if ! type -t compare_url >/dev/null 2>&1; then
  compare_url() {
    echo ""
  }
fi
if ! type -t host_kind >/dev/null 2>&1; then
  host_kind() {
    echo ""

<<TRUNCATED: max_file_lines=800>>
```


#!/usr/bin/env bash
# shellcheck shell=bash
set -euo pipefail
IFS=$'\n\t'

# --------------------------------------------------------------------
# wgx validate: Lint-/Style-Checks für Shell-Dateien
#  - Bash-Syntaxcheck
#  - shfmt-Formatprüfung (diff only)
#  - ShellCheck (Level: style)
# Optionen:
#   -c   Nur geänderte Dateien (gegen HEAD) prüfen
#   -q   Ruhiger Modus (nur Fehler)
#   -h   Hilfe
# --------------------------------------------------------------------

log() { printf '%s\n' "$*" >&2; }
die() {
  log "ERR: $*"
  exit 1
}
need() { command -v "$1" >/dev/null 2>&1 || die "Fehlt Tool: $1"; }

quiet=0
changed_only=0
while getopts ':cqh' opt; do
  case "$opt" in
  c) changed_only=1 ;;
  q) quiet=1 ;;
  h)
    cat <<'USAGE'
wgx validate [-c] [-q]
  -c   Nur geänderte Dateien prüfen (gegen HEAD)
  -q   Ruhiger Modus (nur Fehlerausgabe)
USAGE
    exit 0
    ;;
  \?) die "Unbekannte Option: -$OPTARG (nutze -h)" ;;
  esac
done
shift $((OPTIND - 1))

# benötigte Tools
need git
need bash
need shfmt
need shellcheck

# Dateien einsammeln (robust, null-terminiert, kein Word-Splitting)
files=()
collect_all() {
  # git ls-files garantiert nur versionierte Dateien
  # Wir filtern auf shell-Dateien
  while IFS= read -r -d '' f; do
    files+=("$f")
  done < <(git ls-files -z -- '*.sh' '*.bash')
}

collect_changed() {
  # A: Added, C: Copied, M: Modified, R: Renamed, T: Type, U: Unmerged, X,B: special
  while IFS= read -r -d '' f; do
    case "$f" in
    *.sh | *.bash) files+=("$f") ;;
    esac
  done < <(git diff --name-only -z --diff-filter=ACMRTUXB HEAD --)
}

if ((changed_only)); then
  collect_changed
else
  collect_all
fi

if ((${#files[@]} == 0)); then
  log "Keine passenden Shell-Dateien gefunden."
  exit 0
fi

((quiet)) || {
  log "Dateien:"
  printf ' - %s\n' "${files[@]}" >&2
}

rc=0

# 1) Bash Syntax (ohne Ausführung)
if ! bash -n "${files[@]}"; then
  rc=1
fi

# 2) shfmt – nur Diff anzeigen (kein Auto-Write hier)
if ! shfmt -d "${files[@]}"; then
  rc=1
fi

# 3) ShellCheck – striktes Quoting & Stil
#    -S style ist recht streng, mit guter Signalstärke
if ! shellcheck -S style "${files[@]}"; then
  rc=1
fi

exit "$rc"

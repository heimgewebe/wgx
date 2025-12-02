#!/usr/bin/env bash

# Guard-Modul: Lint- und Testläufe (aus Monolith portiert)
# Konfigurierbare Umgebungsvariablen:
#   WGX_GUARD_MAX_BYTES        Schwelle für Bigfile-Check (Bytes, Default 1048576)
#   WGX_GUARD_CHECKLIST_STRICT Schaltet Checkliste auf Warnmodus, wenn "0"

_guard_command_available() {
  local name="$1"
  if declare -F "cmd_${name}" >/dev/null 2>&1; then
    return 0
  fi
  # Ermittle das Projekt-Root relativ zum Speicherort DIESES Skripts.
  local project_root
  project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  [[ -r "${project_root}/cmd/${name}.bash" ]]
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

type _guard_gitgrep_pcre_supported >/dev/null 2>&1 ||
  _guard_gitgrep_pcre_supported() {
    local rc
    # 0/1 = Option -P vorhanden (Match egal), 2 = Fehler/fehlendes PCRE
    git grep -P -n 'a' -- . >/dev/null 2>&1
    rc=$?
    [[ $rc -ne 2 ]]
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
  - Prüft auf das Vorhandensein eines .wgx/profile.yml.
  - Sucht nach verbleibenden Konfliktmarkern im Code.
  - Prüft auf übergroße Dateien (>= 1MB, konfigurierbar via WGX_GUARD_MAX_BYTES).
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

  local profile_missing=0
  # 0. Profile check
  info "Checking for wgx profile..."
  if profile::has_manifest; then
    # We use indented info for substeps
    printf '  • %s\n' "Profile found." >&2
  else
    warn "No .wgx/profile.yml or .wgx/profile.example.yml found."
    # Nicht sofort abbrechen – andere Checks (v.a. Oversize) sollen trotzdem laufen.
    profile_missing=1
  fi

  # 1. Bigfiles checken (vor dem Secret-Scan, damit große Dateien deterministisch gemeldet werden)
  local max_bytes="${WGX_GUARD_MAX_BYTES:-1048576}"
  if [[ ! "$max_bytes" =~ ^[0-9]+$ ]]; then
    warn "Ungültiger Wert für WGX_GUARD_MAX_BYTES ('$max_bytes'), verwende 1048576."
    max_bytes=1048576
  fi
  info "Checking for oversized files (≥ ${max_bytes} Bytes)..."
  # Portabler Check per wc -c; prüft nur getrackte Dateien, Schwelle via WGX_GUARD_MAX_BYTES konfigurierbar.
  local oversized
  oversized=$(
    git ls-files -z | while IFS= read -r -d '' f; do
      [ -e "$f" ] || continue
      local sz
      sz=$(wc -c <"$f" 2>/dev/null || echo 0)
      if [ "$sz" -ge "$max_bytes" ]; then
        printf '%s\t%s\n' "$sz" "$f"
      fi
    done
  )
  if [ -n "$oversized" ]; then
    # Die Test-Assertion erwartet die exakte Zeichenkette "Oversized files detected" auf STDOUT.
    echo "Oversized files detected"
    warn "The following tracked files exceed the size limit of ${max_bytes} Bytes:"
    while IFS= read -r line; do
      printf '   - %s\n' "$line" >&2
    done <<<"$oversized"
    return 1
  fi

  # 2. Konfliktmarker checken
  info "Checking for conflict markers..."
  # Beschränkt auf getrackte Inhalte via git grep, vermeidet unnötige Scans.
  if git grep -I -n -E '^(<<<<<<< |=======|>>>>>>> )' -- . >/dev/null 2>&1; then
    die "Konfliktmarker in getrackten Dateien gefunden!"
    return 1
  fi

  # 3. Lint (wenn gewünscht)
  if [[ $run_lint -eq 1 ]]; then
    if [[ -n "${BATS_TEST_FILENAME:-}" ]]; then
      info "bats context detected, skipping 'wgx lint' run."
    elif _guard_command_available lint; then
      info "Running lint checks..."
      wgx lint || return 1
    else
      info "lint command not available, skipping lint step."
    fi
  fi

  # 6. Tests (wenn gewünscht)
  if [[ $run_test -eq 1 ]]; then
    if [[ -n "${BATS_TEST_FILENAME:-}" ]]; then
      info "bats context detected, skipping recursive 'wgx test' run."
    elif _guard_command_available test; then
      info "Running tests..."
      wgx test || return 1
    else
      info "test command not available, skipping test step."
    fi
  fi

  # Wenn wir bis hier keinen harten Fehler hatten, aber das Profil fehlt,
  # schlagen wir jetzt (wie im Test erwartet) mit Status 1 fehl.
  if ((profile_missing)); then
    return 1
  fi

  echo "✔ Guard finished successfully."
}

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

_guard_find_wgx() {
  if command -v wgx >/dev/null 2>&1; then
    command -v wgx
    return 0
  fi

  local -a candidates=()
  local base
  for base in "${WGX_DIR:-}" "${WGX_PROJECT_ROOT:-}"; do
    [[ -n "$base" ]] || continue
    candidates+=("$base/wgx" "$base/cli/wgx")
  done

  local bin
  for bin in "${candidates[@]}"; do
    if [[ -x "$bin" ]]; then
      printf '%s\n' "$bin"
      return 0
    fi
  done

  return 1
}

# Contracts Meta Guard (keeps contracts strict-validator friendly)
_guard_contracts_meta() {
  local project_root
  project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  if [[ -d "contracts/events" ]] && command -v python3 >/dev/null 2>&1; then
    # strict: fail on unresolved $ref and x-* keys
    python3 "${project_root}/guards/contracts_meta_guard.py" --strict --require-meta-fields
  fi
}

# Insights Guard (validates insight streams against local contract)
_guard_insights() {
  local project_root
  project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

  # Check if relevant files exist before invoking Python (reduce noise)
  local has_schema=0
  [[ -f "contracts/insights.schema.json" || -f "contracts/events/insights.schema.json" ]] && has_schema=1

  local has_data=0
  if [[ -f "artifacts/insights.daily.json" || -f "artifacts/insights.json" ]]; then
    has_data=1
  elif compgen -G "insights/*.json" >/dev/null || compgen -G "events/insights/*.json" >/dev/null; then
    has_data=1
  fi

  if [[ $has_schema -eq 1 || $has_data -eq 1 ]]; then
    if command -v python3 >/dev/null 2>&1; then
      python3 "${project_root}/guards/insights_guard.py"
    else
      warn "Skipping insights guard (python3 not found)"
    fi
  fi
}

# Integrity Guard (strict-light -> strict-hard rollout)
_guard_integrity() {
  local project_root
  project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  local guard_script="${project_root}/guards/integrity.guard.sh"

  if [[ -x "$guard_script" ]]; then
    info "Running integrity guard..."
    "$guard_script"
  else
    warn "Integrity guard script not found or not executable: $guard_script"
  fi
}

# CI Deps Guard (static analysis for broken specs and interactive usage)
_guard_ci_deps() {
  local project_root
  project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  local guard_script="${project_root}/guards/ci-deps.guard.sh"

  if [[ -x "$guard_script" ]]; then
    info "Running CI deps guard..."
    # Runs in current working directory (target repo)
    "$guard_script" || return 1
  else
    warn "CI deps guard script not found or not executable: $guard_script"
    return 1
  fi
}

# Contracts Ownership Guard
_guard_contracts_ownership() {
  local project_root
  project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  local guard_script="${project_root}/guards/contracts_ownership.guard.sh"

  if [[ -x "$guard_script" ]]; then
    info "Running contracts ownership guard..."
    "$guard_script" || return 1
  else
    warn "Contracts ownership guard script not found or not executable: $guard_script"
    return 1
  fi
}

# Data Flow Guard (validates artifacts against contracts)
_guard_data_flow() {
  local project_root
  project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

  if command -v python3 >/dev/null 2>&1; then
    # The python script itself handles skipping if files/deps are missing.
    python3 "${project_root}/guards/data_flow_guard.py" || return 1
  else
    warn "Skipping data flow guard (python3 not found)"
  fi
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

  local wgx_bin=""
  wgx_bin="$(_guard_find_wgx)" || wgx_bin=""

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
  # Portabler Check: Python (falls verfügbar) ist viel schneller als Bash-Loop.
  local oversized
  if command -v python3 >/dev/null 2>&1; then
    local project_root
    project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    # rc capturing via || rc=$? prevents 'set -e' from aborting on exit code 1 (oversized found)
    local rc=0
    oversized=$(git ls-files -z | python3 "${project_root}/modules/check_filesize.py" "$max_bytes") || rc=$?
    if [[ $rc -ne 0 && $rc -ne 1 ]]; then
      die "Filesize check failed (internal error, exit code $rc)."
      return 1
    fi
  else
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
  fi
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

  # 2.1 Checking for CI dependencies
  _guard_ci_deps || return 1

  # 2.2 Contracts Ownership
  _guard_contracts_ownership || return 1

  # 2.5 Contracts Meta (nur wenn contracts/events existiert)
  if [[ -d "contracts/events" ]]; then
    info "Running contracts meta guard..."
    _guard_contracts_meta || return 1
  fi

  # 2.6 Insights Guard (runs if relevant files exist)
  _guard_insights || return 1

  # 2.7 Integrity Guard
  _guard_integrity || return 1

  # 2.8 Data Flow Guard
  _guard_data_flow || return 1

  # 3. Lint (wenn gewünscht)
  if [[ $run_lint -eq 1 ]]; then
    if [[ -n "${BATS_TEST_FILENAME:-}" ]]; then
      info "bats context detected, skipping 'wgx lint' run."
    elif _guard_command_available lint; then
      info "Running lint checks..."
      if [[ -z "$wgx_bin" ]]; then
        die "wgx executable not found; cannot run lint step."
      fi
      "$wgx_bin" lint || return 1
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
      if [[ -z "$wgx_bin" ]]; then
        die "wgx executable not found; cannot run test step."
      fi
      "$wgx_bin" test || return 1
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

#!/usr/bin/env bash

# Guard-Modul: Lint- und Testläufe (aus Monolith portiert)
# Konfigurierbare Umgebungsvariablen:
#   WGX_GUARD_MAX_BYTES        Schwelle für Bigfile-Check (Bytes, Default 1048576)
#   WGX_GUARD_CHECKLIST_STRICT Schaltet Checkliste auf Warnmodus, wenn "0"

# Importiere Heimgeist-Komponenten (werden relativ zum Modul erwartet)
# Da diese im selben 'modules/' Verzeichnis liegen, und 'modules/guard.bash'
# vermutlich via 'source' geladen wird, hoffen wir, dass der Pfad stimmt.
# Falls nicht, müssen wir den Pfad dynamisch ermitteln.
# Wir nehmen an, dass 'wgx' (das CLI) den 'modules/' Pfad kennt oder
# wir laden sie hier explizit.
_guard_load_heimgeist() {
  local dir
  dir="$(dirname "${BASH_SOURCE[0]}")"
  # Wenn wir bereits gesourced sind, könnte BASH_SOURCE[0] das Hauptskript sein,
  # aber bei direktem Aufruf oder korrektem Sourcing zeigt es auf guard.bash.
  # Wir versuchen es relativ.
  if [[ -f "$dir/chronik.bash" && -f "$dir/archivist.bash" ]]; then
    source "$dir/chronik.bash"
    source "$dir/archivist.bash"
  else
    warn "Heimgeist modules not found in $dir"
  fi
}
_guard_load_heimgeist

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

  # --- Heimgeist: Insight Archivierung ---
  # Generiere ID
  local insight_id
  if command -v uuidgen >/dev/null 2>&1; then
    insight_id="$(uuidgen | tr '[:upper:]' '[:lower:]')"
  elif [ -f /proc/sys/kernel/random/uuid ]; then
    insight_id="$(cat /proc/sys/kernel/random/uuid)"
  else
    # Fallback: Python
    insight_id="$(python3 -c 'import uuid; print(str(uuid.uuid4()))')"
  fi

  # Sammle Status
  local status="success"
  # Da wir hier sind, war alles erfolgreich (sonst return 1 vorher).
  # Wir können noch weitere Metadaten sammeln.

  # Daten payload bauen
  local data_json
  data_json="$(python3 -c "import json; print(json.dumps({
    'status': '$status',
    'checks': {
        'lint': '$run_lint',
        'test': '$run_test',
        'profile_missing': '$profile_missing'
    }
  }))")"

  # Archivieren via Archivist
  # Rolle: "guard"
  if ! archivist::archive_insight "$insight_id" "guard" "$data_json"; then
    die "Failed to archive insight via Heimgeist."
    return 1
  fi

  echo "✔ Guard finished successfully."
}

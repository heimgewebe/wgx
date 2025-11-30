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
  echo "▶ Checking for wgx profile..."
  if profile::has_manifest; then
    echo "  • Profile found."
  else
    echo "❌ No .wgx/profile.yml or .wgx/profile.example.yml found." >&2
    # Nicht sofort abbrechen – andere Checks (v.a. Oversize) sollen trotzdem laufen.
    profile_missing=1
  fi

  # 1. Bigfiles checken (vor dem Secret-Scan, damit große Dateien deterministisch gemeldet werden)
  local max_bytes="${WGX_GUARD_MAX_BYTES:-1048576}"
  if [[ ! "$max_bytes" =~ ^[0-9]+$ ]]; then
    echo "⚠️ Ungültiger Wert für WGX_GUARD_MAX_BYTES ('$max_bytes'), verwende 1048576." >&2
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
    warn "The following tracked files exceed the size limit of ${max_bytes} Bytes:" >&2
    while IFS= read -r line; do
      echo "   - $line" >&2
    done <<< "$oversized"
    return 1
  fi

  # 2. Staged Secrets checken
  # if [[ $run_secrets -eq 1 ]]; then
  #   echo "▶ Checking for secrets..."
  #   # Scannt den Index (--cached), ignoriert Binärdateien (-I), case-insensitive (-i)
  #   # und nutzt echte Wortgrenzen, wenn PCRE (-P) verfügbar ist. Fallback simuliert Grenzen.
  #   type -t _wgx_guard_gitgrep_has_pcre >/dev/null 2>&1 ||
  #     _wgx_guard_gitgrep_has_pcre() {
  #       git grep -P -n 'a' -- . >/dev/null 2>&1
  #       local rc=$?
  #       [[ $rc -ne 2 ]]
  #     }

  #   local _secret_hit=1
  #   if _wgx_guard_gitgrep_has_pcre; then
  #     git grep --cached -I -n -P -i \
  #       -e 'AKIA[0-9A-Z]{16}' \
  #       -e 'BEGIN [A-Z ]*PRIVATE KEY' \
  #       -e 'ghp_[A-Za-z0-9]{36}' \
  #       -e 'xox[aboprs]-[A-Za-z0-9-]{10,}' \
  #       -e 'AIza[0-9A-Za-z_-]{35}' \
  #       -e '(?<![A-Za-z0-9_])(pass(?:word)?|secret|api[_-]?key|token|authorization)(?![A-Za-z0-9_])' \
  #       -- . >/dev/null 2>&1
  #     _secret_hit=$?
  #   else
  #     git grep --cached -I -n -E -i \
  #       -e 'AKIA[0-9A-Z]{16}' \
  #       -e 'BEGIN [A-Z ]*PRIVATE KEY' \
  #       -e 'ghp_[A-Za-z0-9]{36}' \
  #       -e 'xox[aboprs]-[A-Za-z0-9-]{10,}' \
  #       -e 'AIza[0-9A-Za-z_-]{35}' \
  #       -e '(^|[^[:alnum:]_])(pass(word)?|secret|api[_-]?key|token|authorization)([^[:alnum:]_]|$)' \
  #       -- . >/dev/null 2>&1
  #     _secret_hit=$?
  #   fi

  #   if [[ $_secret_hit -eq 0 ]]; then
  #     echo "❌ Potentielles Secret im Commit gefunden (Index-Scan)!" >&2
  #     echo "   Tipp: Prüfe bewusst, whiteliste ggf. gezielt oder verwende gitleaks." >&2
  #     return 1
  #   fi
  #   unset -v _secret_hit
  # fi

  # 3. Konfliktmarker checken
  echo "▶ Checking for conflict markers..."
  # Beschränkt auf getrackte Inhalte via git grep, vermeidet unnötige Scans.
  if git grep -I -n -E '^(<<<<<<< |=======|>>>>>>> )' -- . >/dev/null 2>&1; then
    echo "❌ Konfliktmarker in getrackten Dateien gefunden!" >&2
    return 1
  fi

  # 4. Repository Guard-Checks
  # echo "▶ Verifying repository guard checklist..."
  # local checklist_ok=1
  # # Mit WGX_GUARD_CHECKLIST_STRICT=0 lässt sich ein Warnmodus aktivieren.
  # local checklist_strict="${WGX_GUARD_CHECKLIST_STRICT:-1}"
  # _guard_require_file "uv.lock" "uv.lock vorhanden" || checklist_ok=0
  # _guard_require_file ".github/workflows/shell-docs.yml" "Shell/Docs CI-Workflow vorhanden" || checklist_ok=0
  # _guard_require_file "templates/profile.template.yml" "Profile-Template vorhanden" || checklist_ok=0
  # _guard_require_file "docs/Runbook.md" "Runbook dokumentiert" || checklist_ok=0
  # if [[ $checklist_ok -eq 0 ]]; then
  #   if [[ "$checklist_strict" == "0" ]]; then
  #     echo "⚠️ Guard checklist issues detected (non-strict mode)." >&2
  #   else
  #     echo "❌ Guard checklist failed." >&2
  #     return 1
  #   fi
  # fi

  # 5. Lint (wenn gewünscht)
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

#!/usr/bin/env bash

# Guard-Modul: Lint- und Testläufe (aus Monolith portiert)

_guard_command_available() {
  local name="$1"
  if declare -F "cmd_${name}" >/dev/null 2>&1; then
    return 0
  fi
  local base_dir="${WGX_DIR:-"$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"}"
  [[ -r "${base_dir}/cmd/${name}.bash" ]]
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

guard_run() {
  local run_lint=0 run_test=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
    --lint) run_lint=1 ;;
    --test) run_test=1 ;;
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

  # 1. Staged Secrets checken
  echo "▶ Checking for secrets..."
  if git diff --cached | grep -E "AKIA|SECRET|PASSWORD" >/dev/null; then
    echo "❌ Potentielles Secret im Commit gefunden!" >&2
    return 1
  fi

  # 2. Konfliktmarker checken
  echo "▶ Checking for conflict markers..."
  if grep -R -E '^(<<<<<<< |=======|>>>>>>> )' . --exclude-dir=.git >/dev/null 2>&1; then
    echo "❌ Konfliktmarker gefunden!" >&2
    return 1
  fi

  # 3. Bigfiles checken
  echo "▶ Checking for oversized files..."
  if git ls-files -z |
    xargs -0 du -sb 2>/dev/null |
    awk 'BEGIN { found = 0 } $1 >= 1048576 { print; found = 1 } END { exit(found ? 0 : 1) }'; then
    echo "❌ Zu große Dateien im Repo!" >&2
    return 1
  fi

  # 4. Repository Guard-Checks
  echo "▶ Verifying repository guard checklist..."
  local checklist_ok=1
  _guard_require_file "uv.lock" "uv.lock vorhanden" || checklist_ok=0
  _guard_require_file ".github/workflows/shell-docs.yml" "Shell/Docs CI-Workflow vorhanden" || checklist_ok=0
  _guard_require_file "templates/profile.template.yml" "Profile-Template vorhanden" || checklist_ok=0
  _guard_require_file "docs/Runbook.md" "Runbook dokumentiert" || checklist_ok=0
  if [[ $checklist_ok -eq 0 ]]; then
    echo "❌ Guard checklist failed." >&2
    return 1
  fi

  # 5. Lint (wenn gewünscht)
  if [[ $run_lint -eq 1 ]]; then
    if _guard_command_available lint; then
      echo "▶ Running lint checks..."
      ./wgx lint || return 1
    else
      echo "⚠️ lint command not available, skipping lint step." >&2
    fi
  fi

  # 6. Tests (wenn gewünscht)
  if [[ $run_test -eq 1 ]]; then
    if _guard_command_available test; then
      echo "▶ Running tests..."
      ./wgx test || return 1
    else
      echo "⚠️ test command not available, skipping test step." >&2
    fi
  fi

  echo "✔ Guard finished successfully."
}

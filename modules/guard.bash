#!/usr/bin/env bash
# Guard-Modul: Lint- und Testläufe (aus Monolith portiert)

guard_run() {
  local run_lint=0 run_test=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --lint) run_lint=1 ;;
      --test) run_test=1 ;;
      *) echo "Unknown option: $1" >&2; return 1 ;;
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
  if git ls-files -z | xargs -0 du -sh 2>/dev/null | grep -E '^[1-9][0-9]{2,}[KMG]'; then
    echo "❌ Zu große Dateien im Repo!" >&2
    return 1
  fi

  # 4. Lint (wenn gewünscht)
  if [[ $run_lint -eq 1 ]]; then
    if command -v lint_cmd >/dev/null 2>&1 || command -v cmd_lint >/dev/null 2>&1; then
      echo "▶ Running lint checks..."
      ./wgx lint || return 1
    else
      echo "⚠️ lint command not available, skipping lint step." >&2
    fi
  fi

  # 5. Tests (wenn gewünscht)
  if [[ $run_test -eq 1 ]]; then
    if command -v test_cmd >/dev/null 2>&1 || command -v cmd_test >/dev/null 2>&1; then
      echo "▶ Running tests..."
      ./wgx test || return 1
    else
      echo "⚠️ test command not available, skipping test step." >&2
    fi
  fi

  echo "✔ Guard finished successfully."
}

#!/usr/bin/env bash

task::_check_python_runtime() {
  if ! command -v python3 >/dev/null 2>&1; then
    die "Python 3 is required for parsing .wgx/profile.yml but is not installed. See README section \"Laufzeitabhängigkeiten\" / \"Runtime dependencies\"."
  fi
  if [[ ${WGX_DEBUG:-0} != 0 ]]; then
    if ! python3 -c "import yaml" >/dev/null 2>&1; then
      echo "WGX: PyYAML not available; using built-in minimal YAML parser." >&2
    fi
  fi
}

cmd_task() {
  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || $# -eq 0 ]]; then
    cat <<'USAGE'
Usage:
  wgx task <name> [--] [args...]

Description:
  Führt genau einen Task aus, der im Profil des Ziel-Repositories deklariert
  ist. Der Runner protokolliert oder versendet dabei keine impliziten Events;
  beobachtbare Nebenwirkungen stammen ausschließlich aus dem deklarierten Task.

Example:
  wgx task test -- --verbose

Options:
  -h, --help    Diese Hilfe anzeigen.
USAGE
    return 0
  fi

  local name="$1"
  shift || true

  if [[ ${1:-} == -- ]]; then
    shift
  fi

  local -a forwarded=()
  if (($#)); then
    forwarded=("$@")
  fi

  local target_root="${WGX_TARGET_ROOT:-$PWD}"
  if [[ ! -d "$target_root" ]]; then
    die "Target root not found: $target_root"
  fi

  if ! profile::has_manifest; then
    die $'No tracked wgx profile found. Commit one of:\n  • .wgx/profile.yml          (preferred for production config)\n  • .wgx/profile.example.yml  (placeholder for CI)'
  fi

  task::_check_python_runtime

  if ! profile::ensure_loaded; then
    die "Failed to parse .wgx/profile.yml. Please check its syntax."
  fi

  if ! profile::ensure_version; then
    die "Profile requirements not met (see warnings above)."
  fi

  local key spec
  key="$(profile::_normalize_task_name "$name")"
  spec="$(profile::_task_spec "$key")"
  if [[ -z $spec ]]; then
    warn "Task not defined: $name"
    return 1
  fi

  local rc had_errexit=0
  if [[ $- == *e* ]]; then
    had_errexit=1
    set +o errexit
  fi
  profile::run_task "$name" "${forwarded[@]}"
  rc=$?
  if ((had_errexit)); then
    set -o errexit
  fi
  return "$rc"
}

wgx_command_main() {
  cmd_task "$@"
}

#!/usr/bin/env bash

cmd_task() {
  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || $# -eq 0 ]]; then
    cat <<'USAGE'
Usage:
  wgx task <name> [--] [args...]

Description:
  Führt einen Task aus, der in der '.wgx/profile.yml'-Datei des Repositorys
  definiert ist. Alle Argumente nach dem Task-Namen (und einem optionalen '--')
  werden an den Task weitergegeben.

Example:
  wgx task test -- --verbose

Options:
  -h, --help    Diese Hilfe anzeigen.
USAGE
    return 0
  fi

  if ! profile::ensure_loaded; then
    die ".wgx/profile.yml not found."
  fi

  local name="$1"
  shift || true

  if [[ ${1:-} == -- ]]; then
    shift
  fi

  local key
  key="$(profile::_normalize_task_name "$name")"
  local spec
  spec="$(profile::_task_spec "$key")"
  if [[ -z $spec ]]; then
    die "Task not defined: $name"
  fi

  if ! profile::run_task "$name" "$@"; then
    return 1
  fi
}

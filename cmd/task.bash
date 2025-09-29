#!/usr/bin/env bash

cmd_task() {
  if (( $# == 0 )); then
    die "Usage: wgx task <name> [--] [args...]"
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

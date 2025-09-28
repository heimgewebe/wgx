#!/usr/bin/env bash

cmd_task() {
  if (($# == 0)); then
    die "Usage: wgx task <name> [--] [args...]"
  fi

  if ! profile::ensure_loaded; then
    die ".wgx/profile.yml not found."
  fi

  local name="$1"
  shift || true

  if ! profile::task_command "$name" >/dev/null; then
    die "Task not defined: $name"
  fi

  if ! profile::run_task "$name" "$@"; then
    return 1
  fi
}


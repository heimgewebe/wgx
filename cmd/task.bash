#!/usr/bin/env bash

cmd_task() {
  if (($# == 0)); then
    die "Usage: wgx task <name> [--] [args...]"
  fi

  if ! profile::ensure_loaded; then
    die ".wgx/profile.yml nicht gefunden."
  fi

  local name="$1"
  shift || true

  if ! profile::task_command "$name" >/dev/null; then
    die "Task nicht definiert: $name"
  fi

  if ! profile::run_task "$name" "$@"; then
    return 1
  fi
}


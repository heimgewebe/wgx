#!/usr/bin/env bash

cmd_tasks() {
  if ! profile::ensure_loaded; then
    warn ".wgx/profile.yml not found."
    return 1
  fi

  local output
  output="$(profile::tasks)"
  if [[ -z $output ]]; then
    warn "No tasks defined in manifest."
    return 0
  fi
  printf '%s\n' "$output"
}


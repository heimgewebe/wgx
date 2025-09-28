#!/usr/bin/env bash

cmd_tasks() {
  if ! profile::ensure_loaded; then
    warn ".wgx/profile.yml nicht gefunden."
    return 1
  fi

  local output
  output="$(profile::tasks)"
  if [[ -z $output ]]; then
    warn "Keine Tasks im Manifest definiert."
    return 0
  fi
  printf '%s\n' "$output"
}


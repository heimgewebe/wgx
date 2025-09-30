#!/usr/bin/env bash

# Wrapper to expose sync command via cmd/ dispatcher.
cmd_sync() {
  if ! type sync_cmd >/dev/null 2>&1; then
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local WGX_DIR_LOCAL="${WGX_DIR:-"$(cd "${script_dir}/.." && pwd)"}"
    # shellcheck source=/dev/null
    . "${WGX_DIR_LOCAL}/modules/sync.bash"
  fi
  sync_cmd "$@"
}

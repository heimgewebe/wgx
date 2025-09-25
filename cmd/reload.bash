#!/usr/bin/env bash

cmd_reload() {
  # Flags: --snapshot (optional)
  local do_snapshot=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --snapshot) do_snapshot=1; shift ;;
      *) break ;;
    esac
  done

  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    die "Bitte innerhalb eines Git-Repositories ausführen (kein Git-Repository erkannt)."
  fi

  [ "$do_snapshot" -eq 1 ] && snapshot_make

  local base="${1:-$WGX_BASE}"
  [ -z "$base" ] && base="main"
  git_hard_reload "$base"
}

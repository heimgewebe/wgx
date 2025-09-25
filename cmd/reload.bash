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

  if ! git_is_repo_root; then
    die "Bitte im Repo-Root ausführen (kein Git-Root erkannt)."
  fi

  [ "$do_snapshot" -eq 1 ] && snapshot_make

  local base="${1:-$WGX_BASE}"
  [ -z "$base" ] && base="main"
  git_hard_reload "$base"
}

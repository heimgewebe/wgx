#!/usr/bin/env bash

cmd_reload() {
  local do_snapshot=0 force=0 dry_run=0

  while [ $# -gt 0 ]; do
    case "$1" in
    --snapshot)
      do_snapshot=1
      ;;
    --force|-f)
      force=1
      ;;
    --dry-run|-n)
      dry_run=1
      ;;
    --)
      shift
      break
      ;;
    -*)
      printf 'unbekannte Option: %s\n' "$1" >&2
      return 2
      ;;
    *)
      break
      ;;
    esac
    shift
  done

  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    die "Bitte innerhalb eines Git-Repositories ausführen (kein Git-Repository erkannt)."
  fi

  local base="${1:-$WGX_BASE}"
  [ -z "$base" ] && base="main"

  if git_workdir_dirty; then
    local status
    status="$(git_workdir_status_short)"
    if ((force)); then
      warn "Arbeitsverzeichnis enthält uncommittete Änderungen – --force (-f) aktiv, Änderungen können verloren gehen."
      if [ -n "$status" ]; then
        while IFS= read -r line; do
          printf '    %s\n' "$line" >&2
        done <<<"$status"
      fi
    else
      warn "Arbeitsverzeichnis enthält uncommittete Änderungen – reload abgebrochen."
      if [ -n "$status" ]; then
        while IFS= read -r line; do
          printf '    %s\n' "$line" >&2
        done <<<"$status"
      fi
      warn "Nutze 'wgx reload --force/-f' (oder sichere mit --snapshot), wenn du wirklich alles verwerfen möchtest."
      return 1
    fi
  fi

  if ((do_snapshot)); then
    if ((dry_run)); then
      log_info "[DRY-RUN] Snapshot (Stash) würde erstellt."
    else
      snapshot_make
    fi
  fi

  if ((dry_run)); then
    git_hard_reload --dry-run "$base"
  else
    git_hard_reload "$base"
  fi
}

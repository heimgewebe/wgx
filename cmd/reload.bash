#!/usr/bin/env bash

cmd_reload() {
  local do_snapshot=0 force=0 dry_run=0

  while [ $# -gt 0 ]; do
    case "$1" in
    --snapshot)
      do_snapshot=1
      ;;
    --force | -f)
      force=1
      ;;
    --dry-run | -n)
      dry_run=1
      ;;
    -h | --help)
      cat <<'USAGE'
Usage:
  wgx reload [--snapshot] [--force] [--dry-run] [<base_branch>]

Description:
  Setzt den Workspace hart auf den Stand des remote 'origin'-Branches zurück.
  Standardmäßig wird der in der Konfiguration festgelegte Basis-Branch ($WGX_BASE)
  oder 'main' verwendet.
  Dies ist ein destruktiver Befehl, der lokale Änderungen verwirft.

Options:
  --snapshot    Erstellt vor dem Reset einen Git-Stash als Sicherung.
  --force, -f   Erzwingt den Reset, auch wenn das Arbeitsverzeichnis unsauber ist.
  --dry-run, -n Zeigt nur die auszuführenden Befehle an, ohne Änderungen vorzunehmen.
  <base_branch> Der Branch, auf den zurückgesetzt werden soll (Standard: $WGX_BASE oder 'main').
  -h, --help    Diese Hilfe anzeigen.
USAGE
      return 0
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

  debug "cmd_reload: force=${force} dry_run=${dry_run} snapshot=${do_snapshot} base='${base}'"

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
      info "[DRY-RUN] Snapshot (Stash) würde erstellt."
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

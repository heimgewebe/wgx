#!/usr/bin/env bash

# reload_cmd (from archiv/wgx)
reload_cmd_updated() {
  local force=0 dry_run=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --force)
        force=1
        ;;
      --dry-run)
        dry_run=1
        ;;
      -*)
        die "reload: Unerwartetes Argument '$1'"
        ;;
      *)
        # positional args not supported in this version
        ;;
    esac
    shift || true
  done

  if git_workdir_dirty && ((force == 0)); then
    die "reload abgebrochen: Arbeitsverzeichnis enthält ungespeicherte Änderungen."
  fi

  if ((dry_run)); then
    info "[DRY-RUN] Geplante Schritte:"
    info "[DRY-RUN] git reset --hard origin/$WGX_BASE"
    info "[DRY-RUN] git clean -fdx"
    ok "[DRY-RUN] Reload wäre jetzt abgeschlossen."
    return 0
  fi

  git_hard_reload
}

reload_cmd() {
  reload_cmd_updated "$@"
}

cmd_reload() {
    reload_cmd "$@"
}

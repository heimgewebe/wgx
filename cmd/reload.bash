#!/usr/bin/env bash

# Vereinfachte 'reload'-Implementierung
cmd_reload() {
  local force=0 dry_run=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
    --force)
      force=1
      ;;
    --dry-run)
      dry_run=1
      ;;
    -h | --help)
      cat <<'USAGE'
Usage:
  wgx reload [--force] [--dry-run]

Description:
  Setzt das Arbeitsverzeichnis hart auf den Stand des Upstream-Branches zurück.
  WARNUNG: Alle lokalen Änderungen, auch ungetrackte Dateien, gehen verloren.

Options:
  --force       Führt den Reset auch bei ungespeicherten Änderungen aus.
  --dry-run     Zeigt nur an, was getan würde, ohne Änderungen vorzunehmen.
  -h, --help    Diese Hilfe anzeigen.
USAGE
      return 0
      ;;
    -*)
      die "reload: Unerwartetes Argument '$1'"
      ;;
    *) ;; # Positional args ignorieren
    esac
    shift || true
  done

  # Der Dry-Run wird jetzt direkt von der zugrundeliegenden Git-Funktion
  # unterstützt, was die Logik hier vereinfacht.
  if ((dry_run)); then
    git_hard_reload --dry-run
    return $?
  fi

  if git_workdir_dirty && ((force == 0)); then
    warn "reload abgebrochen: Arbeitsverzeichnis enthält ungespeicherte Änderungen."
    return 1
  fi

  git_hard_reload
}

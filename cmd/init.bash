#!/usr/bin/env bash

cmd_init() {
  local wizard=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --wizard)
        wizard=1
        ;;
      -h|--help)
        cat <<'USAGE'
Usage:
  wgx init [--wizard]

Description:
  Initialisiert die 'wgx'-Konfiguration im Repository. Mit `--wizard` wird
  ein interaktiver Assistent gestartet, der `.wgx/profile.yml` erstellt.

Options:
  --wizard      Interaktiven Profil-Wizard starten.
  -h, --help    Diese Hilfe anzeigen.
USAGE
        return 0
        ;;
      --)
        shift
        break
        ;;
      --*)
        printf 'Unknown option: %s\n' "$1" >&2
        return 1
        ;;
      *)
        break
        ;;
    esac
    shift || true
  done

  if ((wizard)); then
    "$WGX_DIR/cmd/init/wizard.sh"
    return $?
  fi

  echo "FEHLER: Der 'init'-Befehl ist noch nicht vollständig implementiert." >&2
  echo "Eine Beschreibung der geplanten Funktionalität finden Sie in 'docs/Command-Reference.de.md'." >&2
  return 1
}

wgx_command_main() {
  cmd_init "$@"
}

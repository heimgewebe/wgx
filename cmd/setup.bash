#!/usr/bin/env bash

cmd_setup() {
  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    cat <<'USAGE'
Usage:
  wgx setup

Description:
  Hilft bei der Erstinstallation von 'wgx' und seinen Abhängigkeiten,
  insbesondere in Umgebungen wie Termux.
  Prüft auf das Vorhandensein von Kernpaketen (git, gh, glab, jq, etc.)
  und gibt Hinweise zur Installation.
  Die vollständige Implementierung dieses Befehls ist noch in Arbeit.

Options:
  -h, --help    Diese Hilfe anzeigen.
USAGE
    return 0
  fi

  echo "FEHLER: Der 'setup'-Befehl ist noch nicht vollständig implementiert." >&2
  echo "Eine Beschreibung der geplanten Funktionalität finden Sie in 'docs/Command-Reference.de.md'." >&2
  return 1
  # setup_cmd "$@"
}

wgx_command_main() {
  cmd_setup "$@"
}

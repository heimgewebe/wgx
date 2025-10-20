#!/usr/bin/env bash

cmd_heal() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    cat <<'USAGE'
Usage:
  wgx heal [ours|theirs|ff-only|--continue|--abort]

Description:
  Hilft bei der Lösung von Merge- oder Rebase-Konflikten.
  Die vollständige Implementierung dieses Befehls ist noch in Arbeit.
  Für eine detaillierte Beschreibung der geplanten Funktionalität,
  siehe 'docs/Command-Reference.de.md'.

Options:
  -h, --help    Diese Hilfe anzeigen.
USAGE
    return 0
  fi

  echo "FEHLER: Der 'heal'-Befehl ist noch nicht vollständig implementiert." >&2
  echo "Eine Beschreibung der geplanten Funktionalität finden Sie in 'docs/Command-Reference.de.md'." >&2
  return 1
  # heal_cmd "$@"
}

wgx_command_main() {
  cmd_heal "$@"
}

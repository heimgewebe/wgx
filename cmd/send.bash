#!/usr/bin/env bash

cmd_send() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    cat <<'USAGE'
Usage:
  wgx send [--draft] [--title <title>] [--why <reason>] [...]

Description:
  Erstellt einen Pull/Merge Request (PR/MR) auf GitHub oder GitLab.
  Vor dem Senden werden 'wgx guard' und 'wgx sync' ausgeführt.
  Die vollständige Implementierung dieses Befehls ist noch in Arbeit.
  Für eine detaillierte Beschreibung der geplanten Funktionalität,
  siehe 'docs/Command-Reference.de.md'.

Options:
  --draft       Erstellt den PR/MR als Entwurf.
  --title <t>   Setzt den Titel des PR/MR.
  --why <r>     Setzt den "Warum"-Teil im PR/MR-Body.
  --ci          Löst einen CI-Workflow aus (falls konfiguriert).
  --open        Öffnet den erstellten PR/MR im Browser.
  -h, --help    Diese Hilfe anzeigen.
USAGE
    return 0
  fi

  echo "FEHLER: Der 'send'-Befehl ist noch nicht vollständig implementiert." >&2
  echo "Eine Beschreibung der geplanten Funktionalität finden Sie in 'docs/Command-Reference.de.md'." >&2
  return 1
  # send_cmd "$@"
}

wgx_command_main() {
  cmd_send "$@"
}

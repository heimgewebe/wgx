#!/usr/bin/env bash

cmd_release() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    cat <<'USAGE'
Usage:
  wgx release [--version <tag>] [--auto-version <bump>] [...]

Description:
  Erstellt SemVer-Tags und GitHub/GitLab-Releases.
  Die vollständige Implementierung dieses Befehls ist noch in Arbeit.
  Für eine detaillierte Beschreibung der geplanten Funktionalität,
  siehe 'docs/Command-Reference.de.md'.

Options:
  --version <tag>    Die genaue Version für das Release (z.B. v1.2.3).
  --auto-version     Erhöht die Version automatisch (patch, minor, major).
  -h, --help         Diese Hilfe anzeigen.
USAGE
    return 0
  fi

  echo "FEHLER: Der 'release'-Befehl ist noch nicht vollständig implementiert." >&2
  echo "Eine Beschreibung der geplanten Funktionalität finden Sie in 'docs/Command-Reference.de.md'." >&2
  return 1
  # release_cmd "$@"
}

wgx_command_main() {
  cmd_release "$@"
}

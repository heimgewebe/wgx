#!/usr/bin/env bash

cmd_version() {
  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    cat <<'USAGE'
Usage:
  wgx version [bump <level>] [set <version>]

Description:
  Zeigt die aktuelle Version von 'wgx' an oder manipuliert die Version
  in Projektdateien wie 'package.json' oder 'Cargo.toml'.
  Die Implementierung der Unterbefehle 'bump' und 'set' ist noch in Arbeit.

Subcommands:
  bump <level>   Erhöht die Version ('patch', 'minor', 'major').
  set <version>  Setzt die Version auf einen exakten Wert.

Options:
  -h, --help     Diese Hilfe anzeigen.
USAGE
    return 0
  fi

  if [ -n "${WGX_VERSION:-}" ]; then
    printf '%s\n' "$WGX_VERSION"
    return
  fi

  if [ -f "$WGX_DIR/VERSION" ]; then
    cat "$WGX_DIR/VERSION"
    return
  fi

  if git rev-parse --git-dir >/dev/null 2>&1; then
    git describe --tags --always 2>/dev/null || git rev-parse --short HEAD
  else
    printf 'wgx (unversioned)\n'
  fi
}

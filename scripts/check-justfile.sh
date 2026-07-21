#!/usr/bin/env bash
set -euo pipefail

expected_version=${WGX_JUST_VERSION:-1.42.4}
justfile=${1:-Justfile}

if ! command -v just > /dev/null 2>&1; then
  echo "check-justfile: just fehlt" >&2
  exit 1
fi

actual_version=$(just --version)
if [[ "$actual_version" != "just $expected_version" ]]; then
  echo "check-justfile: erwartet just $expected_version, gefunden $actual_version" >&2
  exit 1
fi

if [[ ! -f "$justfile" ]]; then
  echo "check-justfile: Datei fehlt: $justfile" >&2
  exit 1
fi

just --justfile "$justfile" --summary > /dev/null

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
cat > "$tmp" << 'BROKEN'
broken:
    echo {{
BROKEN

if just --justfile "$tmp" --summary > /dev/null 2>&1; then
  echo "check-justfile: negativer Parser-Selbsttest wurde unerwartet akzeptiert" >&2
  exit 1
fi

printf 'check-justfile: PASS (%s)\n' "$actual_version"

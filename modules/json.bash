#!/usr/bin/env bash

# shellcheck shell=bash

json_escape() {
  local s="${1-}" escaped="" rc=0

  # --- Shell-Zustand sichern & lokal entschärfen ----------------------------
  # In Bats laufen Tests i.d.R. mit -euo pipefail. Pipes/Command Substitution
  # können dann bei harmlosen Non-Zero-Exits (z.B. aus jq Filtern) hart abbrechen.
  # Wir toggeln lokal 'errexit' und 'pipefail' aus und stellen danach wieder her.
  local _had_errexit=0 _had_pipefail=0
  [[ $- == *e* ]] && _had_errexit=1 && set +e
  # 'set -o' ist portabel genug, um den pipefail-Status zu erkennen.
  # Wir nutzen Bash-Regex statt grep, um in minimalen Umgebungen zu laufen.
  if [[ "$(set -o)" =~ pipefail[[:space:]]+on ]]; then
    _had_pipefail=1
    set +o pipefail
  fi

  if command -v python3 >/dev/null 2>&1; then
    # Kein Pipe-Konstrukt: per -c und argv arbeiten, das kann auch Newlines tragen.
    escaped="$(python3 -c 'import json,sys; sys.stdout.write(json.dumps(sys.argv[1])[1:-1])' "$s")"
    rc=$?
  elif command -v jq >/dev/null 2>&1; then
    # WICHTIG: Variable per --arg übergeben, um Probleme mit stdin/pipes zu vermeiden.
    # @json liefert korrekt escapten JSON-String; .[1:-1] entfernt Außen-Quotes.
    # -r (raw output) ist entscheidend, um die finalen Quotes zu entfernen.
    escaped="$(jq -rn --arg s "$s" '$s | @json | .[1:-1]')"
    rc=$?
  else
    rc=2
    escaped=""
  fi

  # Ursprünglichen Shell-Zustand wiederherstellen
  ((_had_pipefail)) && set -o pipefail
  ((_had_errexit))  && set -e

  # Ergebnis/Fehlerbehandlung
  if (( rc == 0 )); then
    printf '%s' "$escaped"
    return 0
  fi
  if command -v die >/dev/null 2>&1; then
    die "json_escape: requires python3 or jq"
  else
    printf 'json_escape: requires python3 or jq\n' >&2
  fi
  return 2
}

json_quote() {
  printf '"%s"' "$(json_escape "$1")"
}

json_bool_value() {
  if [[ $1 != true && $1 != false ]]; then
    printf 'invalid boolean: %s\n' "$1" >&2
    return 2
  fi
  printf '%s' "$1"
}

json_join() {
  local IFS=','
  printf '%s' "$*"
}

json_emit() {
  local status="${1:-error}" msg="${2:-}" details="${3:-}"
  printf '{"status":%s,"message":%s,"details":%s}\n' \
    "$(json_quote "$status")" \
    "$(json_quote "$msg")" \
    "$(json_quote "$details")"
}

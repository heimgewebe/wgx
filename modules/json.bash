#!/usr/bin/env bash

# shellcheck shell=bash

json_escape() {
  local s="${1-}" escaped=""
  if command -v python3 >/dev/null 2>&1; then
    escaped="$(printf '%s' "$s" | python3 -c 'import json, sys; sys.stdout.write(json.dumps(sys.stdin.read())[1:-1])')"
    printf '%s' "$escaped"
    return 0
  elif command -v jq >/dev/null 2>&1; then
    escaped="$(jq -Rr @json <<<"$s")"
    printf '%s' "${escaped:1:-1}"
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
  [[ $1 == true || $1 == false ]] || die "invalid boolean: $1"
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

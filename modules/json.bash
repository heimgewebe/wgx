#!/usr/bin/env bash

# shellcheck shell=bash

json_escape() {
  local s="${1-}" escaped=""
  if command -v python3 >/dev/null 2>&1; then
    if escaped="$(printf '%s' "$s" | python3 -c 'import json, sys; sys.stdout.write(json.dumps(sys.stdin.read())[1:-1])')"; then
      printf '%s' "$escaped"
      return 0
    fi
  fi
  if command -v jq >/dev/null 2>&1; then
    if escaped="$(printf '%s' "$s" | jq -Rr '@json | .[1:-1]')"; then
      printf '%s' "$escaped"
      return 0
    fi
  fi
  printf 'json_escape: requires python3 or jq\n' >&2
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

#!/usr/bin/env bash

# shellcheck shell=bash

json_escape() {
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$1" <<'PY'
import json
import sys
print(json.dumps(sys.argv[1])[1:-1])
PY
  else
    printf '%s' "$1"
  fi
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

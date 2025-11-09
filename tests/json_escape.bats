#!/usr/bin/env bats

export LC_ALL=C LANG=C

load test_helper

@test "json_emit produces escaped JSON" {
  run bash -lc 'source modules/json.bash; json_emit ok "a \"quote\"" "{}"'
  assert_success
  assert_output '{"status":"ok","message":"a \"quote\"","details":"{}"}'
}

@test "json_escape falls back to jq when python3 unavailable" {
  export value=$'line\nbreak'
  run bash -lc '
set -euo pipefail
if ! command -v jq >/dev/null 2>&1; then exit 80; fi
tmp=$(mktemp -d)
rm_bin=$(command -v rm)
ln -s "$(command -v jq)" "$tmp/jq"
PATH="$tmp"
trap "$rm_bin -rf \"$tmp\"" EXIT
source modules/json.bash
json_escape "$value"
'
  if [[ "$status" -eq 80 ]]; then
    skip "jq not available"
  fi
  assert_success
  assert_output $'line\\nbreak'
}

@test "json_escape fails loudly without python3 or jq" {
  run bash -lc '
set -euo pipefail
tmp=$(mktemp -d)
rm_bin=$(command -v rm)
PATH="$tmp"
trap "$rm_bin -rf \"$tmp\"" EXIT
source modules/json.bash
json_escape "boom" 2>&1
'
  assert_equal "$status" 2
  assert_equal "$output" 'json_escape: requires python3 or jq'
}

#!/usr/bin/env bats

setup() {
  load 'test_helper/bats-support/load'
  load 'test_helper/bats-assert/load'
  export WGX_DIR="$(pwd)"
  export PATH="$WGX_DIR/cli:$PATH"
  TMPDIR="$(mktemp -d)"
  # Werkzeug-Check: jq wird von den Tests benötigt
  if ! command -v jq >/dev/null 2>&1; then
    skip "jq nicht gefunden – Tests werden übersprungen"
  fi
}

teardown() {
  rm -rf "$TMPDIR"
  # Aufräumen, falls im Repo-Root geschrieben wurde
  rm -f metrics.json
  rm -rf snapshots
}

@test "metrics snapshot creates file at default path (metrics.json) with required keys" {
  run scripts/wgx-metrics-snapshot.sh
  assert_success
  [ -f metrics.json ]
  # required top-level keys present
  run jq -e 'has("ts") and has("host") and has("updates") and has("backup") and has("drift")' metrics.json
  assert_success
}

@test "metrics snapshot respects WGX_METRICS_OUTPUT env" {
  export WGX_METRICS_OUTPUT="$TMPDIR/from-env.json"
  run scripts/wgx-metrics-snapshot.sh
  assert_success
  [ -f "$WGX_METRICS_OUTPUT" ]
  run jq -e 'has("ts") and has("host")' "$WGX_METRICS_OUTPUT"
  assert_success
}

@test "metrics snapshot errors on unknown option" {
  run scripts/wgx-metrics-snapshot.sh --definitely-unknown-flag
  assert_failure
  [[ "$output" =~ "Unbekannte Option" ]]
}

@test "metrics snapshot --output writes to custom path" {
  out="$TMPDIR/custom.json"
  run scripts/wgx-metrics-snapshot.sh --output "$out"
  assert_success
  [ -f "$out" ]
  run jq -e '.backup | has("last_ok") and has("age_days")' "$out"
  assert_success
}

@test "metrics snapshot --json prints valid JSON to stdout" {
  out="$TMPDIR/std.json"
  run scripts/wgx-metrics-snapshot.sh --json --output "$out"
  assert_success
  # stdout must be JSON and match file content structure-wise
  echo "$output" > "$TMPDIR/stdout.json"
  run jq -e type "$TMPDIR/stdout.json"
  assert_success
  run jq -e 'has("ts") and has("host") and has("updates") and has("backup") and has("drift")' "$TMPDIR/stdout.json"
  assert_success
}

@test "metrics snapshot fails on empty output path" {
  run scripts/wgx-metrics-snapshot.sh --output ""
  assert_failure
  [[ "$output" =~ "Der Ausgabe-Pfad darf nicht leer sein" ]]
}

@test "metrics snapshot creates parent directory for custom path" {
  nested="$TMPDIR/snapshots/metrics.json"
  run scripts/wgx-metrics-snapshot.sh --output "$nested"
  assert_success
  [ -f "$nested" ]
}

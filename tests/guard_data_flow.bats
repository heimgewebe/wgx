#!/usr/bin/env bats

load test_helper

setup() {
  export WGX_DIR="$BATS_TEST_DIRNAME/.."
  mkdir -p "$BATS_TEST_TMPDIR/repo"
  cd "$BATS_TEST_TMPDIR/repo"
  git init
  git config user.email "test@example.com"
  git config user.name "Test User"
  mkdir -p .wgx
  cat <<YAML > .wgx/profile.yml
wgx:
  version: 1
  tasks:
    test: echo "test passed"
YAML
  git add .wgx/profile.yml
  git commit -m "Add profile"

  # Satisfy ownership guard
  export HG_REPO_NAME="metarepo"
  mkdir -p fleet
  touch fleet/repos.yml
}

@test "guard data_flow: silent/skip when no files found" {
  # If no files exist, the guard runs but finds no active flows.

  run wgx guard --lint
  echo "Output: $output"
  [ "$status" -eq 0 ]

  if command -v python3 >/dev/null 2>&1; then
      [[ "$output" =~ "SKIP: No active flows detected" ]]
  else
      [[ "$output" =~ "Skipping data flow guard (python3 not found)" ]]
  fi
}

@test "guard data_flow: validates observatory flow successfully" {
  if ! command -v python3 >/dev/null 2>&1; then
    skip "python3 not available"
  fi

  mkdir -p contracts artifacts
  echo '{"type": "object"}' > contracts/knowledge.observatory.schema.json
  echo '{"id": "1", "val": "foo"}' > artifacts/knowledge.observatory.json
  git add contracts artifacts

  run wgx guard --lint
  echo "Output: $output"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Checking 'observatory'" ]]
  [[ "$output" =~ "OK:" ]]
}

@test "guard data_flow: fails on validation error" {
  if ! command -v python3 >/dev/null 2>&1; then
    skip "python3 not available"
  fi

  mkdir -p contracts artifacts
  echo '{"type": "object", "properties": {"val": {"type": "integer"}}}' > contracts/knowledge.observatory.schema.json
  echo '{"id": "1", "val": "foo"}' > artifacts/knowledge.observatory.json
  git add contracts artifacts

  run wgx guard --lint
  echo "Output: $output"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "FAILED: 1 error(s) found" ]]
}

@test "guard data_flow: checks ingest state" {
  if ! command -v python3 >/dev/null 2>&1; then
    skip "python3 not available"
  fi

  mkdir -p contracts data
  echo '{"type": "object"}' > contracts/heimlern.ingest.state.v1.schema.json
  echo '{"cursor": "123"}' > data/heimlern.cursor.json
  git add contracts data

  run wgx guard --lint
  echo "Output: $output"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Checking 'ingest_state'" ]]
}

@test "guard data_flow: checks multiple flows" {
  if ! command -v python3 >/dev/null 2>&1; then
    skip "python3 not available"
  fi

  mkdir -p contracts artifacts data reports/plexer
  echo '{"type": "object"}' > contracts/knowledge.observatory.schema.json
  echo '{"type": "object"}' > contracts/plexer.delivery.report.v1.schema.json

  echo '{}' > artifacts/knowledge.observatory.json
  echo '{}' > reports/plexer/delivery.report.json

  git add contracts artifacts reports

  run wgx guard --lint
  echo "Output: $output"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Checking 'observatory'" ]]
  [[ "$output" =~ "Checking 'delivery_report'" ]]
  [[ "$output" =~ "OK: 2 flow(s) checked" ]]
}

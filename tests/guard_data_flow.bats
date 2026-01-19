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

@test "guard data_flow: silent/skip when no config found" {
  run wgx guard --lint
  echo "Output: $output"
  [ "$status" -eq 0 ]
  # Depending on implementation, it might warn or just skip
  if command -v python3 >/dev/null 2>&1; then
      [[ "$output" =~ "No flow configuration found" ]] || [[ "$output" =~ "Skipping" ]]
  else
      [[ "$output" =~ "Skipping data flow guard" ]]
  fi
}

@test "guard data_flow: fails when data exists but schema missing" {
  if ! command -v python3 >/dev/null 2>&1; then
    skip "python3 not available"
  fi

  mkdir -p contracts artifacts

  # Create config (JSON for max portability in test env)
  cat <<JSON > contracts/flows.json
{
  "flows": {
    "test_flow": {
      "schema": "contracts/missing.schema.json",
      "data": ["artifacts/data.json"]
    }
  }
}
JSON

  echo '{"id": "1", "val": "foo"}' > artifacts/data.json
  git add contracts artifacts

  run wgx guard --lint
  echo "Output: $output"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "schema is missing" ]]
}

@test "guard data_flow: passes with valid strict schema" {
  if ! command -v python3 >/dev/null 2>&1; then
    skip "python3 not available"
  fi

  mkdir -p contracts artifacts

  cat <<JSON > contracts/flows.json
{
  "flows": {
    "strict_flow": {
      "schema": "contracts/strict.schema.json",
      "data": ["artifacts/strict.json"]
    }
  }
}
JSON

  # Strict schema: additionalProperties: false
  cat <<JSON > contracts/strict.schema.json
{
  "type": "object",
  "properties": {
    "id": { "type": "string" },
    "val": { "type": "string" }
  },
  "required": ["id"],
  "additionalProperties": false
}
JSON

  echo '{"id": "1", "val": "foo"}' > artifacts/strict.json
  git add contracts artifacts

  run wgx guard --lint
  echo "Output: $output"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Checking 'strict_flow'" ]]
  [[ "$output" =~ "OK" ]]
}

@test "guard data_flow: fails on strict schema violation" {
  if ! command -v python3 >/dev/null 2>&1; then
    skip "python3 not available"
  fi

  mkdir -p contracts artifacts

  cat <<JSON > contracts/flows.json
{
  "flows": {
    "strict_flow": {
      "schema": "contracts/strict.schema.json",
      "data": ["artifacts/strict.json"]
    }
  }
}
JSON

  cat <<JSON > contracts/strict.schema.json
{
  "type": "object",
  "properties": {
    "id": { "type": "string" }
  },
  "additionalProperties": false
}
JSON

  # 'extra' field should cause failure
  echo '{"id": "1", "extra": "forbidden"}' > artifacts/strict.json
  git add contracts artifacts

  run wgx guard --lint
  echo "Output: $output"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "FAILED" ]]
}

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
  [[ "$output" != *"FAILED"* ]]
}

@test "guard data_flow: fails when data exists but schema missing (via .wgx/flows.json)" {
  if ! command -v python3 >/dev/null 2>&1; then
    skip "python3 not available"
  fi

  mkdir -p contracts artifacts .wgx

  # Canonical config location
  cat <<JSON > .wgx/flows.json
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
  git add contracts artifacts .wgx

  run wgx guard --lint
  echo "Output: $output"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "flow=test_flow" ]]
  [[ "$output" =~ "Schema missing" ]]
}

@test "guard data_flow: passes with valid strict schema (via .wgx/flows.json)" {
  if ! command -v python3 >/dev/null 2>&1; then
    skip "python3 not available"
  fi

  mkdir -p contracts artifacts .wgx

  cat <<JSON > .wgx/flows.json
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
    "id": { "type": "string" },
    "val": { "type": "string" }
  },
  "required": ["id"],
  "additionalProperties": false
}
JSON

  echo '{"id": "1", "val": "foo"}' > artifacts/strict.json
  git add contracts artifacts .wgx

  run wgx guard --lint
  echo "Output: $output"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "CHECK flow=strict_flow" ]]
  [[ "$output" =~ "OK" ]]
}

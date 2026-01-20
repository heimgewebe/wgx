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
}

@test "guard data_flow: silent/skip when no config found" {
  run wgx guard --only data_flow
  echo "Output: $output"
  [ "$status" -eq 0 ]
  [[ "$output" != *"FAILED"* ]]
}

@test "guard data_flow: fails when data exists but schema missing (via .wgx/flows.json)" {
  if ! command -v python3 >/dev/null 2>&1; then
    skip "python3 not available"
  fi

  mkdir -p contracts artifacts .wgx

  # Array format
  cat <<JSON > .wgx/flows.json
[
  {
    "name": "test_flow",
    "schema_path": "contracts/missing.schema.json",
    "data_pattern": ["artifacts/data.json"]
  }
]
JSON

  echo '{"id": "1", "val": "foo"}' > artifacts/data.json
  git add contracts artifacts .wgx

  run wgx guard --only data_flow
  echo "Output: $output"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "flow=test_flow" ]]
  [[ "$output" =~ "Schema missing" ]]
}

@test "guard data_flow: passes with valid strict schema" {
  if ! command -v python3 >/dev/null 2>&1; then
    skip "python3 not available"
  fi

  mkdir -p contracts artifacts .wgx

  cat <<JSON > .wgx/flows.json
[
  {
    "name": "strict_flow",
    "schema_path": "contracts/strict.schema.json",
    "data_pattern": ["artifacts/strict.json"]
  }
]
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

  run wgx guard --only data_flow
  echo "Output: $output"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "CHECK flow=strict_flow" ]]
  [[ "$output" =~ "OK" ]]
}

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

@test "guard data_flow: fails with strict log format" {
  if ! command -v python3 >/dev/null 2>&1; then
    skip "python3 not available"
  fi

  mkdir -p contracts artifacts .wgx

  cat <<JSON > .wgx/flows.json
[
  {
    "name": "strict_log_flow",
    "schema_path": "contracts/strict.schema.json",
    "data_pattern": ["artifacts/data.json"]
  }
]
JSON

  # Create a schema that requires integer "val", but we give it a string
  cat <<JSON > contracts/strict.schema.json
{
  "type": "object",
  "properties": {
    "id": { "type": "string" },
    "val": { "type": "integer" }
  },
  "required": ["val"]
}
JSON

  echo '{"id": "item-1", "val": "not-an-int"}' > artifacts/data.json
  git add contracts artifacts .wgx

  run wgx guard --only data_flow
  echo "Output: $output"

  [ "$status" -eq 1 ]

  # Strict Log Format Check
  # Expected: [wgx][guard][data_flow] FAIL flow=strict_log_flow data=artifacts/data.json id=item-1 error='...'

  # 1. Check for presence of required fields
  [[ "$output" =~ "[wgx][guard][data_flow] FAIL flow=strict_log_flow" ]]
  [[ "$output" =~ "data=artifacts/data.json" ]]
  [[ "$output" =~ "id=item-1" ]]
  [[ "$output" =~ "error='" ]]

  # 2. Check for ABSENCE of forbidden fields (schema=...) in the FAIL line
  # We grep specifically for the FAIL line to ensure we don't match CHECK line which HAS schema=
  local fail_line
  fail_line=$(echo "$output" | grep "FAIL flow=")
  [[ "$fail_line" != *"schema="* ]]
}

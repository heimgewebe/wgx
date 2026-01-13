#!/usr/bin/env bats

load test_helper

setup() {
  export WGX_DIR="$BATS_TEST_DIRNAME/.."
  # Note: WGX_PROJECT_ROOT is set by test_helper to the actual repo root.
  # We want WGX_DIR to be the "source" for tools, but for `wgx guard` to work on the *current* directory (test repo),
  # we rely on how `wgx` determines the target.
  # `wgx` usually works in current dir.

  # Create a temp git repo
  mkdir -p "$BATS_TEST_TMPDIR/repo"
  cd "$BATS_TEST_TMPDIR/repo"
  git init
  git config user.email "test@example.com"
  git config user.name "Test User"

  # Create a valid profile (required for guard to pass profile check)
  mkdir -p .wgx
  cat <<YAML > .wgx/profile.yml
wgx:
  version: 1
  tasks:
    test: echo "test passed"
YAML
  git add .wgx/profile.yml
  git commit -m "Add profile"

  # Ensure contracts ownership guard passes
  # The 'insights' guard runs AFTER 'contracts_ownership' in the guard chain.
  # To test 'insights' logic in isolation without failing early, we must satisfy
  # the ownership guard by mocking a valid metarepo environment.
  export HG_REPO_NAME="metarepo"
  mkdir -p fleet
  touch fleet/repos.yml
}

@test "guard insights: silent when no files found (no invocation)" {
  run wgx guard --lint
  echo "Output: $output"
  [ "$status" -eq 0 ]
  # Should NOT see SKIP message because bash logic prevents invocation
  [[ ! "$output" =~ "SKIP: No schema found" ]]
  [[ ! "$output" =~ "SKIP: No insight data found" ]]
}

@test "guard insights: passes with valid schema and data (JSON)" {
  mkdir -p contracts artifacts
  cat <<JSON > contracts/insights.schema.json
{
  "\$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "properties": {
    "type": { "type": "string" },
    "relation": {
       "type": "object",
       "properties": {
         "thesis": { "type": "string" },
         "antithesis": { "type": "string" }
       }
    }
  },
  "required": ["type"]
}
JSON

  cat <<JSON > artifacts/insights.json
[
  { "type": "review.insight" },
  {
    "type": "insight.negation",
    "relation": { "thesis": "A", "antithesis": "B" }
  }
]
JSON

  git add contracts artifacts

  run wgx guard --lint
  echo "Output: $output"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "[wgx][guard][insights] OK" ]]
}

@test "guard insights: passes with valid schema and data (JSONL)" {
  mkdir -p contracts artifacts
  cat <<JSON > contracts/insights.schema.json
{
  "type": "object",
  "properties": { "type": { "type": "string" } },
  "required": ["type"]
}
JSON

  # JSONL format: one JSON object per line
  cat <<JSONL > artifacts/insights.json
{ "type": "review.insight" }
{ "type": "insight.negation", "relation": { "thesis": "A", "antithesis": "B" } }
JSONL

  git add contracts artifacts

  run wgx guard --lint
  echo "Output: $output"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "[wgx][guard][insights] OK" ]]
}

@test "guard insights: fails on schema violation" {
  mkdir -p contracts artifacts
  cat <<JSON > contracts/insights.schema.json
{
  "type": "object",
  "properties": { "foo": { "type": "string" } },
  "required": ["foo"]
}
JSON

  cat <<JSON > artifacts/insights.json
[ { "bar": 1 } ]
JSON

  git add contracts artifacts

  run wgx guard --lint
  echo "Output: $output"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "is a required property" ]]
}

@test "guard insights: fails on missing relation in insight.negation (manual check)" {
  # NOTE: This test verifies the "Defense-in-Depth" check.
  # Even if the schema is loose (doesn't mandate relation/thesis/antithesis),
  # the Guard enforces epistemological completeness for negations.
  mkdir -p contracts artifacts
  cat <<JSON > contracts/insights.schema.json
{
  "type": "object",
  "properties": { "type": { "type": "string" } }
}
JSON

  cat <<JSON > artifacts/insights.json
[
  { "type": "insight.negation" }
]
JSON

  git add contracts artifacts

  run wgx guard --lint
  echo "Output: $output"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "error: missing relation for insight.negation" ]]
}

@test "guard insights: no double error if schema catches missing relation" {
  mkdir -p contracts artifacts
  # Schema enforces 'relation'
  cat <<JSON > contracts/insights.schema.json
{
  "type": "object",
  "properties": {
    "type": { "type": "string" },
    "relation": { "type": "object" }
  },
  "required": ["relation"]
}
JSON

  cat <<JSON > artifacts/insights.json
[
  { "type": "insight.negation" }
]
JSON

  git add contracts artifacts

  run wgx guard --lint
  echo "Output: $output"
  [ "$status" -eq 1 ]
  # Should see schema error
  [[ "$output" =~ "is a required property" ]]
  # Should NOT see manual error (deduplication)
  [[ ! "$output" =~ "error: missing relation for insight.negation" ]]
}

@test "guard insights: fails on invalid JSON/JSONL (garbage content)" {
  mkdir -p contracts artifacts
  cat <<JSON > contracts/insights.schema.json
{ "type": "object" }
JSON

  # Random text, neither JSON list nor valid JSON lines
  echo "THIS IS NOT JSON" > artifacts/insights.json

  git add contracts artifacts

  run wgx guard --lint
  echo "Output: $output"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Failed to parse data" ]] || [[ "$output" =~ "neither valid JSON nor valid JSONL" ]]
}

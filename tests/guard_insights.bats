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
}

@test "guard insights: skips when no files found" {
  run wgx guard --lint
  echo "Output: $output"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "SKIP: No schema found" ]] || [[ "$output" =~ "SKIP: No insight data found" ]]
}

@test "guard insights: passes with valid schema and data" {
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

@test "guard insights: fails on missing relation in insight.negation" {
  mkdir -p contracts artifacts
  # Schema allows it (doesn't force relation), but Guard should enforce it!
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

@test "guard insights: fails on missing thesis in relation" {
  mkdir -p contracts artifacts
  cat <<JSON > contracts/insights.schema.json
{
  "type": "object",
  "properties": { "type": { "type": "string" }, "relation": { "type": "object" } }
}
JSON

  cat <<JSON > artifacts/insights.json
[
  {
    "type": "insight.negation",
    "relation": { "antithesis": "foo" }
  }
]
JSON

  git add contracts artifacts

  run wgx guard --lint
  echo "Output: $output"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "error: missing relation.thesis for insight.negation" ]]
}

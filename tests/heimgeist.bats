#!/usr/bin/env bats

load test_helper

# Explicitly load the heimgeist fixture logic since it's no longer sourced by wgx
load test_helper/heimgeist_fixture.bash

setup() {
    # Test-Umgebung vorbereiten
    WORKDIR="$BATS_TEST_TMPDIR/heimgeist-test"
    mkdir -p "$WORKDIR"
    cd "$WORKDIR"

    # Mock Chronik
    export WGX_CHRONIK_MOCK_FILE="$WORKDIR/chronik_events.log"

    # Create a local copy of the Metarepo Schema (Mocking the SSOT for test purposes)
    # Reflects Base-Envelope with producer required, role removed from meta
    cat > schema.json <<'EOF'
{
  "type": "object",
  "properties": {
    "kind": { "const": "heimgeist.insight" },
    "version": { "const": 1 },
    "id": { "type": "string", "pattern": "^evt-" },
    "meta": {
      "type": "object",
      "properties": {
        "occurred_at": { "type": "string" },
        "producer": { "const": "wgx.guard" }
      },
      "required": ["occurred_at", "producer"],
      "not": { "required": ["role"] }
    },
    "data": {
      "type": "object",
      "properties": {
         "origin": {
            "type": "object",
            "properties": {
               "role": { "type": "string" }
            }
         }
      }
    }
  },
  "required": ["kind", "version", "id", "meta", "data"]
}
EOF
}

teardown() {
    cd ..
    rm -rf "$WORKDIR"
    unset WGX_CHRONIK_MOCK_FILE
}

@test "heimgeist: fixture generates valid contract payload" {
    # We invoke the fixture function directly to simulate generating a contract-compliant event
    # This ensures wgx *can* produce valid events without doing so automatically in production

    local test_data='{"test": "true"}'

    # Generate event using the fixture
    # heimgeist::archive_insight <id> <role> <data>
    # Note: role defaults to 'wgx.guard' if not set
    run heimgeist::archive_insight "test-id" "" "$test_data"
    assert_success

    # Check existence
    [ -f "$WGX_CHRONIK_MOCK_FILE" ]

    # Check ID prefix consistency (key in file)
    run cat "$WGX_CHRONIK_MOCK_FILE"
    assert_output --partial "evt-test-id"

    # Validate against strict contract schema
    local value
    value=$(tail -n 1 "$WGX_CHRONIK_MOCK_FILE" | cut -d= -f2-)

    # Use the script with the provided schema
    run python3 "$BATS_TEST_DIRNAME/../scripts/validate_insight_schema.py" --schema schema.json <(echo "$value")
    assert_success
    assert_output --partial "Schema Validation Passed"
}

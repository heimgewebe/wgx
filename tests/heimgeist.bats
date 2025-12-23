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
    # Note: role defaults to 'archivist' if not set, or we can pass it
    run heimgeist::archive_insight "test-id" "archivist" "$test_data"
    assert_success

    # Check existence
    [ -f "$WGX_CHRONIK_MOCK_FILE" ]

    # Check ID prefix consistency (key in file)
    run cat "$WGX_CHRONIK_MOCK_FILE"
    assert_output --partial "evt-test-id"

    # Validate against strict contract schema
    local value
    value=$(tail -n 1 "$WGX_CHRONIK_MOCK_FILE" | cut -d= -f2-)

    # Use the script which now checks role and id strictness
    run python3 "$BATS_TEST_DIRNAME/../scripts/validate_insight_schema.py" <(echo "$value")
    assert_success
    assert_output --partial "Schema Validation Passed"
}

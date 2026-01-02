#!/usr/bin/env bats

load test_helper

setup() {
  # Set WGX_DIR for the test context
  export WGX_DIR="$WGX_PROJECT_ROOT"

  # Source modules/heimgeist.bash
  source "$WGX_DIR/modules/heimgeist.bash"
  export -f heimgeist::emit

  # Mock functions
  warn() { echo "WARN: $*" >&2; }
  info() { echo "INFO: $*" >&2; }
  export -f warn info
}

@test "heimgeist::emit prints JSON to stdout" {
  local payload='{"foo":"bar"}'
  run heimgeist::emit "test.type" "test.source" "$payload"

  assert_success
  assert_output --partial '"type": "test.type"'
  assert_output --partial '"source": "test.source"'
  assert_output --partial '"payload": {"foo": "bar"}'
}

@test "heimgeist::emit sends POST when PLEXER_URL is set" {
  export PLEXER_URL="http://mock-plexer/events"
  export PLEXER_TOKEN="mock-token"

  # Mock curl
  function curl() {
    # echo "DEBUG: curl called with $*" >&2

    # Simple check for arguments
    local args="$*"
    if [[ "$args" != *"$PLEXER_URL"* ]]; then echo "Missing URL" >&2; return 1; fi
    # Check for header
    if [[ "$args" != *"Authorization: Bearer mock-token"* ]]; then echo "Missing Token" >&2; return 1; fi

    # Simulate HTTP 201 Created
    echo "201"
    return 0
  }
  export -f curl

  local payload='{"foo":"bar"}'
  run heimgeist::emit "test.type" "test.source" "$payload"

  assert_success
  assert_output --partial '"type": "test.type"' # Still prints to stdout
  assert_output --partial "Event erfolgreich an Plexer gesendet"
}

@test "heimgeist::emit handles curl failure" {
  export PLEXER_URL="http://mock-plexer/events"

  function curl() {
    return 7 # Failed to connect
  }
  export -f curl

  local payload='{"foo":"bar"}'
  run heimgeist::emit "test.type" "test.source" "$payload"

  assert_failure
  assert_output --partial "Fehler beim Senden an Plexer (curl exit code 7)"
}

@test "heimgeist::emit handles HTTP error" {
  export PLEXER_URL="http://mock-plexer/events"

  function curl() {
    echo "500" # Internal Server Error
    return 0
  }
  export -f curl

  local payload='{"foo":"bar"}'
  run heimgeist::emit "test.type" "test.source" "$payload"

  assert_failure
  assert_output --partial "Fehler beim Senden an Plexer (HTTP 500)"
}

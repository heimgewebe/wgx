#!/usr/bin/env bats

load test_helper

setup() {
  export WGX_DIR="$BATS_TEST_DIRNAME/.."
  # Ensure WGX_PROJECT_ROOT is set cleanly for tests
  export WGX_PROJECT_ROOT="$WGX_DIR"
  export PATH="$WGX_DIR/cli:$PATH"
  # Use a unique temp directory
  export WGX_TARGET_ROOT="$BATS_TMPDIR/wgx-guard-integrity-$BASHPID"

  mkdir -p "$WGX_TARGET_ROOT"
  cd "$WGX_TARGET_ROOT"

  # Setup minimal valid environment
  git init >/dev/null 2>&1
  git config user.email "you@example.com"
  git config user.name "Your Name"

  write_valid_profile
  git add .wgx/profile.yml
  git commit -m "init" >/dev/null 2>&1
}

write_valid_profile() {
    local target="${1:-.wgx/profile.yml}"
    mkdir -p "$(dirname "$target")"
    cp "$WGX_DIR/templates/.wgx/profile.yml" "$target"
}

teardown() {
  rm -rf "$WGX_TARGET_ROOT"
}

@test "guard integrity: FAILS when artifacts/integrity/ contains files" {
  mkdir -p artifacts/integrity
  touch artifacts/integrity/forbidden.file
  git add artifacts/integrity/forbidden.file 2>/dev/null || true

  run wgx guard
  assert_failure
  assert_output --partial "Integrity artifacts must live under reports/integrity/. artifacts/integrity/ is forbidden."
}

@test "guard integrity: WARNS when reports/integrity/ exists but summary.json is missing" {
  mkdir -p reports/integrity

  run wgx guard
  assert_success
  assert_output --partial "Integrity task detected but no reports/integrity/summary.json produced."
}

@test "guard integrity: WARNS when integrity task exists but summary.json is missing" {
  # Modify profile to include integrity task.
  cat <<EOF > .wgx/profile.yml
wgx:
  apiVersion: v1
  requiredWgx: "^2.0"
  repoKind: "generic"
  tasks:
    integrity: "echo integrity"
    test: "echo test"
    lint: "echo lint"
EOF

  run wgx guard
  assert_success
  assert_output --partial "Integrity task detected but no reports/integrity/summary.json produced."
}

@test "guard integrity: FAILS when reports/integrity/event_payload.json has extra keys" {
  mkdir -p reports/integrity
  touch reports/integrity/summary.json
  echo '{"url": "https://example.com", "generated_at": "2024-01-01T00:00:00Z", "repo": "r", "status": "OK", "extra": "x"}' > reports/integrity/event_payload.json

  run wgx guard
  assert_failure
  assert_output --partial "Event payload contains forbidden keys: extra"
}

@test "guard integrity: FAILS when reports/integrity/event_payload.json has forbidden 'counts' key" {
  mkdir -p reports/integrity
  touch reports/integrity/summary.json
  echo '{"url": "https://example.com", "generated_at": "2024-01-01T00:00:00Z", "repo": "r", "status": "OK", "counts": {"foo": 1}}' > reports/integrity/event_payload.json

  run wgx guard
  assert_failure
  assert_output --partial "Event payload contains forbidden keys: counts"
}

@test "guard integrity: PASSES when everything is correct" {
  mkdir -p reports/integrity
  touch reports/integrity/summary.json
  echo '{"url": "https://example.com", "generated_at": "2024-01-01T00:00:00Z", "repo": "r", "status": "OK"}' > reports/integrity/event_payload.json

  run wgx guard
  assert_success
  assert_output --partial "Running integrity guard..."
  assert_output --partial "Integrity checks passed."
}

@test "guard integrity: PASSES when artifacts/integrity exists but is empty" {
  mkdir -p artifacts/integrity

  run wgx guard
  assert_success
  # Should not fail with forbidden message
  [[ ! "$output" =~ "artifacts/integrity/ is forbidden" ]]
}

@test "guard integrity: FAILS when event_payload.json is missing mandatory key (url)" {
  mkdir -p reports/integrity
  touch reports/integrity/summary.json
  echo '{"generated_at": "2024-01-01T00:00:00Z", "repo": "r", "status": "OK"}' > reports/integrity/event_payload.json

  run wgx guard
  assert_failure
  assert_output --partial "Event payload missing mandatory key: url"
}

@test "guard integrity: FAILS when event_payload.json is missing mandatory key (status)" {
  mkdir -p reports/integrity
  touch reports/integrity/summary.json
  echo '{"url": "https://example.com", "generated_at": "2024-01-01T00:00:00Z", "repo": "r"}' > reports/integrity/event_payload.json

  run wgx guard
  assert_failure
  assert_output --partial "Event payload missing mandatory key: status"
}

@test "guard integrity: FAILS when event_payload.json is not an object" {
  mkdir -p reports/integrity
  touch reports/integrity/summary.json
  echo '"not-an-object"' > reports/integrity/event_payload.json

  run wgx guard
  assert_failure
  assert_output --partial "Event payload must be an object."
}

@test "guard integrity: WARNS when event_payload.json exists but summary.json is missing" {
  mkdir -p reports/integrity
  echo '{"url": "https://example.com", "generated_at": "2024-01-01T00:00:00Z", "repo": "r", "status": "OK"}' > reports/integrity/event_payload.json

  run wgx guard
  assert_success
  assert_output --partial "WARN: Integrity task detected but no reports/integrity/summary.json produced."
  # Should still validate event_payload.json and pass
  assert_output --partial "Integrity checks passed."
}

@test "guard integrity: FAILS when jq is not available" {
  mkdir -p reports/integrity
  touch reports/integrity/summary.json
  echo '{"url": "https://example.com", "generated_at": "2024-01-01T00:00:00Z", "repo": "r", "status": "OK"}' > reports/integrity/event_payload.json

  # Create a wrapper script that simulates missing jq
  cat > /tmp/guard-wrapper.sh <<EOF
#!/bin/bash
cd "$WGX_TARGET_ROOT"
# Simulate jq not being available
function command() {
  if [[ "\$1" == "-v" && "\$2" == "jq" ]]; then
    return 1  # jq not found
  fi
  builtin command "\$@"
}
export -f command
source "$WGX_DIR/guards/integrity.guard.sh"
EOF
  chmod +x /tmp/guard-wrapper.sh
  
  run bash /tmp/guard-wrapper.sh
  assert_failure
  assert_output --partial "jq is required for event schema validation but was not found."
  
  rm -f /tmp/guard-wrapper.sh
}

@test "guard integrity: FAILS when status is not a valid enum value" {
  mkdir -p reports/integrity
  touch reports/integrity/summary.json
  echo '{"url": "https://example.com", "generated_at": "2024-01-01T00:00:00Z", "repo": "r", "status": "INVALID"}' > reports/integrity/event_payload.json

  run wgx guard
  assert_failure
  assert_output --partial "Event payload.status must be one of: OK, WARN, FAIL, MISSING, UNCLEAR"
}

@test "guard integrity: FAILS when URL is not a valid HTTP/HTTPS URL" {
  mkdir -p reports/integrity
  touch reports/integrity/summary.json
  echo '{"url": "ftp://example.com", "generated_at": "2024-01-01T00:00:00Z", "repo": "r", "status": "OK"}' > reports/integrity/event_payload.json

  run wgx guard
  assert_failure
  assert_output --partial "Event payload.url must be a valid HTTP/HTTPS URL"
}

@test "guard integrity: FAILS when generated_at is not in ISO-8601 format" {
  mkdir -p reports/integrity
  touch reports/integrity/summary.json
  echo '{"url": "https://example.com", "generated_at": "invalid-date", "repo": "r", "status": "OK"}' > reports/integrity/event_payload.json

  run wgx guard
  assert_failure
  assert_output --partial "Event payload.generated_at must be in ISO-8601 format"
}

@test "guard integrity: FAILS when repo is empty" {
  mkdir -p reports/integrity
  touch reports/integrity/summary.json
  echo '{"url": "https://example.com", "generated_at": "2024-01-01T00:00:00Z", "repo": "", "status": "OK"}' > reports/integrity/event_payload.json

  run wgx guard
  assert_failure
  assert_output --partial "Event payload.repo must be a non-empty string."
}

#!/usr/bin/env bats

load test_helper

setup() {
  export WGX_DIR="$BATS_TEST_DIRNAME/.."
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
    cp "$WGX_PROJECT_ROOT/templates/.wgx/profile.yml" "$target"
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
  # We overwrite because appending to yaml is tricky without structure awareness,
  # but here we can just write a valid minimal profile with integrity task.
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
  # Need to commit changes or stage them?
  # wgx guard usually checks working tree or profile.
  # Profile parser reads file from disk.

  run wgx guard
  assert_success
  assert_output --partial "Integrity task detected but no reports/integrity/summary.json produced."
}

@test "guard integrity: FAILS when reports/integrity/event.json has invalid schema (bad type)" {
  mkdir -p reports/integrity
  touch reports/integrity/summary.json
  echo '{"type": "wrong", "source": "s", "payload": {}}' > reports/integrity/event.json

  run wgx guard
  assert_failure
  assert_output --partial "Event type must be 'integrity.summary.published.v1'"
}

@test "guard integrity: FAILS when reports/integrity/event.json has extra keys" {
  mkdir -p reports/integrity
  touch reports/integrity/summary.json
  echo '{"type": "integrity.summary.published.v1", "source": "s", "payload": {"url": "u", "generated_at": "g", "repo": "r", "status": "s", "extra": "x"}}' > reports/integrity/event.json

  run wgx guard
  assert_failure
  assert_output --partial "Event payload contains forbidden keys: extra"
}

@test "guard integrity: PASSES when everything is correct" {
  mkdir -p reports/integrity
  touch reports/integrity/summary.json
  echo '{"type": "integrity.summary.published.v1", "source": "s", "payload": {"url": "u", "generated_at": "g", "repo": "r", "status": "s"}}' > reports/integrity/event.json

  run wgx guard
  assert_success
  assert_output --partial "Running integrity guard..."
  assert_output --partial "Integrity checks passed."
}

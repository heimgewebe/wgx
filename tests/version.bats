#!/usr/bin/env bats

load test_helper

setup() {
  export WGX_DIR="$BATS_TEST_TMPDIR/wgx"
  mkdir -p "$WGX_DIR/cmd" "$WGX_DIR/lib"
  cp "$BATS_TEST_DIRNAME/../cmd/version.bash" "$WGX_DIR/cmd/"
  cat <<'EOF' > "$WGX_DIR/lib/core.bash"
die() { echo "FATAL: $*" >&2; return 1; }
EOF
  source "$WGX_DIR/lib/core.bash"
  source "$WGX_DIR/cmd/version.bash"

  TEST_PROJECT_DIR="$BATS_TEST_TMPDIR/project"
  mkdir -p "$TEST_PROJECT_DIR"
  cd "$TEST_PROJECT_DIR"
}

@test "version: reads from VERSION file" {
  echo "1.2.3" > VERSION
  run cmd_version
  assert_success
  assert_output "1.2.3"
}

@test "version: reads from package.json" {
  echo '{"version": "2.3.4"}' > package.json
  run cmd_version
  assert_success
  assert_output "2.3.4"
}

@test "version: reads from Cargo.toml" {
  cat <<'EOF' > Cargo.toml
[package]
name = "test"
version = "4.5.6"
EOF
  run cmd_version
  assert_success
  assert_output "4.5.6"
}

@test "version: help documents read-only contract" {
  run cmd_version --help
  assert_success
  assert_output --partial "without modifying repository state"
}

@test "version: rejects mutation subcommands without changing VERSION" {
  echo "1.2.3" > VERSION
  run cmd_version set 2.0.0
  assert_failure
  assert_output --partial "read-only"
  run cat VERSION
  assert_output "1.2.3"

  run cmd_version bump patch
  assert_failure
  assert_output --partial "read-only"
  run cat VERSION
  assert_output "1.2.3"
}

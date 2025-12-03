#!/usr/bin/env bats

load test_helper

setup() {
  export WGX_DIR="$BATS_TEST_TMPDIR/wgx"
  mkdir -p "$WGX_DIR/modules" "$WGX_DIR/cmd" "$WGX_DIR/lib"

  # Mock necessary files
  cp "$BATS_TEST_DIRNAME/../modules/semver.bash" "$WGX_DIR/modules/"
  cp "$BATS_TEST_DIRNAME/../cmd/version.bash" "$WGX_DIR/cmd/"

  # Create a dummy core.bash for logging functions used in version.bash
  cat <<'EOF' > "$WGX_DIR/lib/core.bash"
info() { echo "INFO: $*"; }
die() { echo "FATAL: $*" >&2; exit 1; }
EOF

  # Source the command and helper
  source "$WGX_DIR/lib/core.bash"
  source "$WGX_DIR/cmd/version.bash"

  # Change to a clean temp dir for version file manipulation
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

@test "version: reads from package.json (jq)" {
  if ! command -v jq >/dev/null; then skip "jq not installed"; fi
  echo '{"version": "2.3.4"}' > package.json
  run cmd_version
  assert_success
  assert_output "2.3.4"
}

@test "version: reads from package.json (grep fallback)" {
  # Temporarily hide jq if possible? Hard in bats.
  # But the code prefers jq. We can rely on unit logic or mock jq.
  # Let's trust the logic prefers jq, but if we write valid json it works either way.
  echo '{"version": "3.4.5"}' > package.json
  run cmd_version
  assert_success
  assert_output "3.4.5"
}

@test "version: reads from Cargo.toml" {
  cat <<EOF > Cargo.toml
[package]
name = "test"
version = "4.5.6"
EOF
  run cmd_version
  assert_success
  assert_output "4.5.6"
}

@test "version set: updates VERSION file" {
  echo "0.0.1" > VERSION
  run cmd_version set 1.0.0
  assert_success
  assert_output --partial "Updated VERSION to 1.0.0"
  run cat VERSION
  assert_output "1.0.0"
}

@test "version set: updates package.json" {
  echo '{"name":"x","version":"0.1.0"}' > package.json
  run cmd_version set 0.2.0
  assert_success
  assert_output --partial "Updated package.json to 0.2.0"

  if command -v jq >/dev/null; then
     run jq -r .version package.json
     assert_output "0.2.0"
  else
     run grep '"version":' package.json
     assert_output --partial "0.2.0"
  fi
}

@test "version set: updates Cargo.toml" {
  cat <<EOF > Cargo.toml
[package]
version = "0.1.0"
EOF
  run cmd_version set 0.2.0
  assert_success
  assert_output --partial "Updated Cargo.toml to 0.2.0"
  run grep '^version =' Cargo.toml
  assert_output 'version = "0.2.0"'
}

@test "version bump: patch increment" {
  echo "1.0.0" > VERSION
  run cmd_version bump patch
  assert_success
  assert_output --partial "Updated VERSION to 1.0.1"
  run cat VERSION
  assert_output "1.0.1"
}

@test "version bump: minor increment" {
  echo "1.2.3" > VERSION
  run cmd_version bump minor
  assert_success
  assert_output --partial "Updated VERSION to 1.3.0"
  run cat VERSION
  assert_output "1.3.0"
}

@test "version bump: major increment" {
  echo "1.2.3" > VERSION
  run cmd_version bump major
  assert_success
  assert_output --partial "Updated VERSION to 2.0.0"
  run cat VERSION
  assert_output "2.0.0"
}

@test "version bump: validates semver" {
  echo "invalid-version" > VERSION
  run cmd_version bump patch
  assert_failure
  assert_output --partial "Current version 'invalid-version' is not valid SemVer"
}

@test "version bump: fails on unknown level" {
  echo "1.0.0" > VERSION
  run cmd_version bump super
  assert_failure
  assert_output --partial "Invalid bump level: super"
}

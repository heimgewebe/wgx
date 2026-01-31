#!/usr/bin/env bats

load test_helper

setup() {
  export WGX_DIR="$BATS_TEST_DIRNAME/.."
  PATH="$WGX_DIR:$PATH"
  rm -rf .wgx/out
}

teardown() {
  rm -rf .wgx/out
}

@test "audit git: creates unique artifacts per correlation_id" {
  run wgx audit git --correlation-id run-A
  assert_success
  assert_output --partial ".wgx/out/audit.git.v1.run-A.json"
  assert_exists ".wgx/out/audit.git.v1.run-A.json"

  run wgx audit git --correlation-id run-B
  assert_success
  assert_output --partial ".wgx/out/audit.git.v1.run-B.json"
  assert_exists ".wgx/out/audit.git.v1.run-B.json"

  # Verify both exist
  assert_exists ".wgx/out/audit.git.v1.run-A.json"
}

@test "audit git: stdout-json does not write file" {
  run wgx audit git --stdout-json
  assert_success
  assert_output --partial '"kind": "audit.git"'

  # Should not write the default file if stdout-json is used?
  # The implementation:
  # if [[ "$stdout_json" -eq 1 ]]; then echo "$out_json"; else echo "$out_json" > ...; fi
  # So it should NOT write to file.

  assert_not_exists ".wgx/out/audit.git.v1.json"
}

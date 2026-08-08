#!/usr/bin/env bats

load test_helper

setup() {
  WGX_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export WGX_DIR="$WGX_ROOT"
  export PATH="$WGX_ROOT/cli:$PATH"
  TEST_DIR="$(mktemp -d)"
  export WGX_INTEGRITY_ROOT="$TEST_DIR"
  unset GITHUB_REPOSITORY
}

teardown() {
  rm -rf "$TEST_DIR"
  unset WGX_INTEGRITY_ROOT GITHUB_REPOSITORY
}

run_generator() {
  run bash "$WGX_ROOT/scripts/generate-integrity-report.sh"
}

@test "integrity generator: reports MISSING with no proof artifacts" {
  mkdir -p "$TEST_DIR/reports/integrity"
  echo '{}' > "$TEST_DIR/reports/integrity/event_payload.json"
  export GITHUB_REPOSITORY="heimgewebe/wgx-test"

  run_generator
  assert_success
  [ -s "$TEST_DIR/reports/integrity/summary.json" ]

  run python3 -c "import json; p=json.load(open('$TEST_DIR/reports/integrity/summary.json')); assert p['repo']=='heimgewebe/wgx-test'; assert p['status']=='MISSING'; assert p['counts']['artifacts']==0"
  assert_success
}

@test "integrity generator: reports OK when contracts and artifacts exist" {
  mkdir -p "$TEST_DIR/contracts" "$TEST_DIR/reports/proofs"
  echo '{}' > "$TEST_DIR/contracts/example.schema.json"
  echo 'proof' > "$TEST_DIR/reports/proofs/result.txt"
  export GITHUB_REPOSITORY="heimgewebe/wgx-test"

  run_generator
  assert_success

  run python3 -c "import json; p=json.load(open('$TEST_DIR/reports/integrity/summary.json')); assert p['status']=='OK'; assert p['counts']['claims']==1; assert p['counts']['artifacts']==1"
  assert_success
}

@test "integrity generator: reports UNCLEAR for artifacts without contracts" {
  mkdir -p "$TEST_DIR/reports/proofs"
  echo 'proof' > "$TEST_DIR/reports/proofs/result.txt"

  run_generator
  assert_success

  run python3 -c "import json; p=json.load(open('$TEST_DIR/reports/integrity/summary.json')); assert p['status']=='UNCLEAR'; assert p['counts']['claims']==0; assert p['counts']['artifacts']==1"
  assert_success
}

@test "integrity generator: falls back to git origin identity" {
  cd "$TEST_DIR"
  git init >/dev/null 2>&1
  git remote add origin git@github.com:org/repo.git

  run_generator
  assert_success

  run python3 -c "import json; p=json.load(open('$TEST_DIR/reports/integrity/summary.json')); assert p['repo']=='org/repo'"
  assert_success
}

@test "integrity generator: leaves no temporary summary files" {
  export GITHUB_REPOSITORY="heimgewebe/wgx-test"
  run_generator
  assert_success

  run bash -c "find '$TEST_DIR/reports/integrity' -maxdepth 1 -name '.summary.json.*' -print -quit"
  assert_success
  assert_output ""
}

@test "integrity is not a public WGX CLI command" {
  run wgx integrity --update
  assert_failure
}

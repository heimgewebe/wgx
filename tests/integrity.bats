#!/usr/bin/env bats

load test_helper

setup() {
  export TEST_DIR
  TEST_DIR="$(mktemp -d)"
  export WGX_TARGET_ROOT="$TEST_DIR"

  # Hard isolation: no writes outside test dir
  export HOME="$TEST_DIR/home"
  mkdir -p "$HOME"
  export XDG_CONFIG_HOME="$TEST_DIR/xdg/config"
  export XDG_CACHE_HOME="$TEST_DIR/xdg/cache"
  export XDG_STATE_HOME="$TEST_DIR/xdg/state"
  mkdir -p "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_STATE_HOME"

  # Ensure clean environment for repo detection tests
  unset GITHUB_REPOSITORY
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "integrity: reports MISSING when file not found" {
  run wgx integrity
  assert_success
  # Note: info() output goes to stderr by default in lib/core.bash unless WGX_INFO_STDERR is changed or legacy logic applies.
  # However, run captures both stdout and stderr in $output.
  assert_output --partial "Kein Integritätsbericht gefunden"
  assert_output --partial "Status: MISSING"
}

@test "integrity: reports table when file found" {
  mkdir -p "$TEST_DIR/reports/integrity"
  cat <<JSON > "$TEST_DIR/reports/integrity/summary.json"
{
  "repo": "semantAH",
  "generated_at": "2023-10-27T10:00:00Z",
  "counts": {
    "claims": 12,
    "artifacts": 5,
    "loop_gaps": 3,
    "unclear": 2
  }
}
JSON

  run wgx integrity
  assert_success
  assert_output --partial "Integritäts-Diagnose (Beobachter-Modus)"
  assert_output --partial "Repo:       semantAH"
  assert_output --partial "Claims       | 12"
  assert_output --partial "Loop Gaps    | 3"
}

@test "integrity: --publish creates reports/integrity/event_payload.json" {
  mkdir -p "$TEST_DIR/reports/integrity"
  cat <<JSON > "$TEST_DIR/reports/integrity/summary.json"
{
  "repo": "heimgewebe/semantAH",
  "generated_at": "2023-10-27T10:00:00Z",
  "status": "OK"
}
JSON
  # Initialize git repo to satisfy remote url logic (best effort)
  cd "$TEST_DIR"
  git init >/dev/null 2>&1
  git remote add origin https://github.com/org/repo.git >/dev/null 2>&1

  run wgx integrity --publish

  # file check
  [ -f "$TEST_DIR/reports/integrity/event_payload.json" ]

  # content check
  run cat "$TEST_DIR/reports/integrity/event_payload.json"
  assert_output --partial '"status": "OK"'
  assert_output --partial '"repo": "heimgewebe/semantAH"'
}

@test "integrity: --publish generates canonical release asset URL" {
  mkdir -p "$TEST_DIR/reports/integrity"
  cat <<JSON > "$TEST_DIR/reports/integrity/summary.json"
{
  "repo": "heimgewebe/wgx-test",
  "generated_at": "2023-10-27T10:00:00Z",
  "status": "OK"
}
JSON

  # Ensure GITHUB_REPOSITORY is set
  export GITHUB_REPOSITORY="heimgewebe/wgx-test"

  run wgx integrity --publish
  assert_success

  # file check
  [ -f "$TEST_DIR/reports/integrity/event_payload.json" ]

  # content check
  run cat "$TEST_DIR/reports/integrity/event_payload.json"
  assert_output --partial '"url": "https://github.com/heimgewebe/wgx-test/releases/download/integrity/summary.json"'
  # Should also match the repo field in payload to match GITHUB_REPOSITORY
  assert_output --partial '"repo": "heimgewebe/wgx-test"'
}

@test "integrity: --publish uses corrected repo name in payload if summary is unknown" {
    mkdir -p "$TEST_DIR/reports/integrity"
    # Summary has "unknown" repo
    cat <<JSON > "$TEST_DIR/reports/integrity/summary.json"
{
  "repo": "unknown",
  "generated_at": "2023-10-27T10:00:00Z",
  "status": "MISSING"
}
JSON

    export GITHUB_REPOSITORY="heimgewebe/wgx-fallback"

    run wgx integrity --publish
    assert_success

    # Check that the payload now contains the detected repo name, not "unknown"
    run cat "$TEST_DIR/reports/integrity/event_payload.json"
    assert_output --partial '"repo": "heimgewebe/wgx-fallback"'
    assert_output --partial '"url": "https://github.com/heimgewebe/wgx-fallback/releases/download/integrity/summary.json"'
}

@test "integrity: --publish fails gracefully (no payload) if URL cannot be constructed" {
    mkdir -p "$TEST_DIR/reports/integrity"
    # Summary has "unknown" repo and no GITHUB_REPOSITORY or git remote
    cat <<JSON > "$TEST_DIR/reports/integrity/summary.json"
{
  "repo": "unknown",
  "generated_at": "2023-10-27T10:00:00Z",
  "status": "MISSING"
}
JSON
    unset GITHUB_REPOSITORY
    unset GIT_DIR GIT_WORK_TREE

    # Ensure strict isolation: no git repo at all
    cd "$TEST_DIR"
    rm -rf .git

    # The command should succeed (exit 0) but warn.
    # Redirect stderr to stdout to ensure we catch warnings regardless of BATS helper configuration.
    run bash -c "wgx integrity --publish 2>&1"
    assert_success

    # Check that warning was emitted
    assert_output --partial "Konnte keine gültige URL für das Integritäts-Event konstruieren"

    # Check that payload file was NOT created
    [ ! -f "$TEST_DIR/reports/integrity/event_payload.json" ]
}

@test "integrity: --publish skips payload creation if generated_at or status is missing" {
    mkdir -p "$TEST_DIR/reports/integrity"
    # Summary missing required fields (jq defaults to unknown/UNKNOWN)
    cat <<JSON > "$TEST_DIR/reports/integrity/summary.json"
{
  "repo": "heimgewebe/wgx-test"
}
JSON
    # The command should succeed (exit 0) but warn and skip.
    # Redirect stderr to stdout for robust assertion.
    run bash -c "wgx integrity --publish 2>&1"
    assert_success

    # Check warning
    assert_output --partial "Integritätsbericht unvollständig"

    # Check that payload file was NOT created
    [ ! -f "$TEST_DIR/reports/integrity/event_payload.json" ]
}

@test "integrity: --publish prioritizes summary.json repo over GITHUB_REPOSITORY" {
    mkdir -p "$TEST_DIR/reports/integrity"
    # Summary has explicit repo
    cat <<JSON > "$TEST_DIR/reports/integrity/summary.json"
{
  "repo": "heimgewebe/wgx-summary",
  "generated_at": "2023-10-27T10:00:00Z",
  "status": "OK"
}
JSON
    # GITHUB_REPOSITORY is different
    export GITHUB_REPOSITORY="heimgewebe/wgx-env"

    run wgx integrity --publish
    assert_success

    # Should use summary repo as primary truth for the payload, because the report
    # itself claims to belong to that repo.
    run cat "$TEST_DIR/reports/integrity/event_payload.json"
    assert_output --partial '"repo": "heimgewebe/wgx-summary"'
    assert_output --partial '"url": "https://github.com/heimgewebe/wgx-summary/releases/download/integrity/summary.json"'
}

@test "integrity: --publish fallback to GITHUB_REPOSITORY if summary repo invalid" {
    mkdir -p "$TEST_DIR/reports/integrity"
    # Summary repo is invalid (no slash)
    cat <<JSON > "$TEST_DIR/reports/integrity/summary.json"
{
  "repo": "invalidrepo",
  "generated_at": "2023-10-27T10:00:00Z",
  "status": "OK"
}
JSON
    export GITHUB_REPOSITORY="heimgewebe/wgx-env"

    run wgx integrity --publish
    assert_success

    # Should fallback to GITHUB_REPOSITORY
    run cat "$TEST_DIR/reports/integrity/event_payload.json"
    assert_output --partial '"repo": "heimgewebe/wgx-env"'
    assert_output --partial '"url": "https://github.com/heimgewebe/wgx-env/releases/download/integrity/summary.json"'
}

@test "integrity: --publish uses corrected repo name when remote has .git suffix" {
    mkdir -p "$TEST_DIR/reports/integrity"
    # Summary repo is unknown
    cat <<JSON > "$TEST_DIR/reports/integrity/summary.json"
{
  "repo": "unknown",
  "generated_at": "2023-10-27T10:00:00Z",
  "status": "OK"
}
JSON
    unset GITHUB_REPOSITORY
    # Setup git remote with .git suffix
    cd "$TEST_DIR"
    git init >/dev/null 2>&1
    git remote add origin https://github.com/org/repo.git >/dev/null 2>&1

    run wgx integrity --publish
    assert_success

    # Should strip .git suffix
    run cat "$TEST_DIR/reports/integrity/event_payload.json"
    assert_output --partial '"repo": "org/repo"'
    assert_output --partial '"url": "https://github.com/org/repo/releases/download/integrity/summary.json"'
}

@test "integrity: --publish handles SSH remote URLs" {
    mkdir -p "$TEST_DIR/reports/integrity"
    # Summary repo is unknown
    cat <<JSON > "$TEST_DIR/reports/integrity/summary.json"
{
  "repo": "unknown",
  "generated_at": "2023-10-27T10:00:00Z",
  "status": "OK"
}
JSON
    unset GITHUB_REPOSITORY
    # Setup SSH remote
    cd "$TEST_DIR"
    git init >/dev/null 2>&1
    git remote add origin git@github.com:ssh-org/ssh-repo.git >/dev/null 2>&1

    run wgx integrity --publish
    assert_success

    # Should correct repo name and URL
    run cat "$TEST_DIR/reports/integrity/event_payload.json"
    assert_output --partial '"repo": "ssh-org/ssh-repo"'
    assert_output --partial '"url": "https://github.com/ssh-org/ssh-repo/releases/download/integrity/summary.json"'
}

# Merged special characters test into the general robust repo handling tests
# to avoid redundancy. The SSH and priority tests already cover complex parsing.

@test "integrity: --update detects repo from GITHUB_REPOSITORY (priority)" {
  cd "$TEST_DIR"
  # Mock git remote (should be ignored when GITHUB_REPOSITORY is set)
  git init >/dev/null 2>&1
  git remote add origin https://github.com/should-be/ignored.git >/dev/null 2>&1

  # Set GITHUB_REPOSITORY to test priority
  export GITHUB_REPOSITORY="org/repo"

  run wgx integrity --update
  assert_success

  [ -f "reports/integrity/summary.json" ]
  run cat "reports/integrity/summary.json"
  assert_output --partial '"status":'
  assert_output --partial '"repo": "org/repo"'
}

@test "integrity: --update detects repo from git remote (fallback)" {
  cd "$TEST_DIR"
  git init >/dev/null 2>&1

  # Test that various remote URL formats are correctly parsed
  for remote in \
    "https://github.com/org/repo.git" \
    "git@github.com:org/repo.git" \
    "https://github.com/org/repo"
  do
    # Update remote for each format
    git remote remove origin >/dev/null 2>&1 || true
    git remote add origin "$remote" >/dev/null 2>&1

    run wgx integrity --update
    assert_success

    [ -f "reports/integrity/summary.json" ]
    run cat "reports/integrity/summary.json"
    assert_output --partial '"status":'
    assert_output --partial '"repo": "org/repo"'
  done
}

@test "integrity: --publish warns but succeeds when heimgeist::emit fails" {
  mkdir -p "$TEST_DIR/reports/integrity"
  cat <<JSON > "$TEST_DIR/reports/integrity/summary.json"
{
  "repo": "heimgewebe/wgx-fail",
  "generated_at": "2023-10-27T10:00:00Z",
  "status": "OK"
}
JSON

  # Save real root
  local real_root="$WGX_PROJECT_ROOT"

  # Copy lib and cmd to test dir so wgx can function when we override WGX_PROJECT_ROOT
  cp -r "$real_root/lib" "$TEST_DIR/"
  cp -r "$real_root/cmd" "$TEST_DIR/"

  # Mock heimgeist module
  mkdir -p "$TEST_DIR/modules"
  cat <<'BASH' > "$TEST_DIR/modules/heimgeist.bash"
heimgeist::emit() {
  echo "Mock heimgeist::emit failing..." >&2
  return 1
}
BASH

  # Force wgx to look in TEST_DIR for modules/lib/cmd
  # We override WGX_PROJECT_ROOT to force the CLI to load our mock module from TEST_DIR/modules.
  # This works because the CLI uses this variable to resolve library paths.
  export WGX_PROJECT_ROOT="$TEST_DIR"
  export GITHUB_REPOSITORY="heimgewebe/wgx-fail"

  # Run with absolute path to real wgx, capturing stderr
  run bash -c "$real_root/cli/wgx integrity --publish 2>&1"
  assert_success # Exit code 0 despite failure

  # Check warning
  assert_output --partial "Konnte Event 'integrity.summary.published.v1' nicht senden"

  # Check payload still exists (Release Asset logic)
  [ -f "$TEST_DIR/reports/integrity/event_payload.json" ]
}

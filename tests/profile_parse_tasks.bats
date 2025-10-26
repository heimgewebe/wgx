#!/usr/bin/env bats

load test_helper

setup() {
  REPO_ROOT="$(pwd)"
  export WGX_DIR="$REPO_ROOT"
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  # Stub python3 to force flat parser to be exercised when profile::load runs.
  cat >"$BATS_TEST_TMPDIR/bin/python3" <<'SH'
#!/usr/bin/env bash
exit 1
SH
  chmod +x "$BATS_TEST_TMPDIR/bin/python3"
  export PATH="$REPO_ROOT/cli:$BATS_TEST_TMPDIR/bin:/usr/bin:/bin"
  source "$REPO_ROOT/modules/profile.bash"
  WORKDIR="$BATS_TEST_TMPDIR/work"
  mkdir -p "$WORKDIR/.wgx"
  cd "$WORKDIR"
  profile::_reset
}

teardown() {
  profile::_reset
}

@test "flat parser loads inline and nested tasks without python" {
  cat >"$WORKDIR/.wgx/profile.yml" <<'YAML'
wgx:
  tasks:
    inline: echo inline
    nested:
      desc: Build project
      group: dev
      safe: true
      cmd: echo nested
    caution:
      cmd: echo caution
      safe: No
YAML

  profile::load "$WORKDIR/.wgx/profile.yml"
  assert_equal 0 "$?"

  assert_equal "inline nested caution" "${WGX_TASK_ORDER[*]}"

  assert_equal "STR:echo inline" "${WGX_TASK_CMDS[inline]}"
  assert_equal "" "${WGX_TASK_DESC[inline]}"
  assert_equal "" "${WGX_TASK_GROUP[inline]}"
  assert_equal "0" "${WGX_TASK_SAFE[inline]}"

  assert_equal "STR:echo nested" "${WGX_TASK_CMDS[nested]}"
  assert_equal "Build project" "${WGX_TASK_DESC[nested]}"
  assert_equal "dev" "${WGX_TASK_GROUP[nested]}"
  assert_equal "1" "${WGX_TASK_SAFE[nested]}"

  assert_equal "STR:echo caution" "${WGX_TASK_CMDS[caution]}"
  assert_equal "0" "${WGX_TASK_SAFE[caution]}"

  assert_equal "v1" "$PROFILE_VERSION"
}

@test "flat parser normalizes safe flag casing and defaults" {
  cat >"$WORKDIR/.wgx/profile.yml" <<'YAML'
wgx:
  tasks:
    safe_upper:
      safe: YES
      cmd: echo safe upper
    safe_mixed:
      safe: On
      cmd: echo safe mixed
    safe_false:
      safe: off
      cmd: echo unsafe
    metadata_only:
      desc: Example task
YAML

  profile::load "$WORKDIR/.wgx/profile.yml"
  assert_equal 0 "$?"

  assert_equal "1" "${WGX_TASK_SAFE[safe_upper]}"
  assert_equal "1" "${WGX_TASK_SAFE[safe_mixed]}"
  assert_equal "0" "${WGX_TASK_SAFE[safe_false]}"
  assert_equal "0" "${WGX_TASK_SAFE[metadata_only]}"

  assert_equal "STR:echo safe upper" "${WGX_TASK_CMDS[safe_upper]}"
  assert_equal "STR:echo safe mixed" "${WGX_TASK_CMDS[safe_mixed]}"
  assert_equal "STR:echo unsafe" "${WGX_TASK_CMDS[safe_false]}"
  assert_equal "STR:" "${WGX_TASK_CMDS[metadata_only]}"
  assert_equal "Example task" "${WGX_TASK_DESC[metadata_only]}"
}

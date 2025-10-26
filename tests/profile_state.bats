#!/usr/bin/env bats

load test_helper

setup() {
  REPO_ROOT="$(pwd)"
}

@test "profile::ensure_loaded clears cached data when manifest disappears" {
  WORKDIR="$BATS_TEST_TMPDIR/project"
  mkdir -p "$WORKDIR/.wgx"
  cat >"$WORKDIR/.wgx/profile.yml" <<'YAML'
wgx:
  apiVersion: v1
  repoKind: webapp
YAML

  helper_script="$BATS_TEST_TMPDIR/check_profile.sh"
  cat >"$helper_script" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$1"
WORKDIR="$2"
export WGX_DIR="$REPO_ROOT"
source "$REPO_ROOT/lib/core.bash"
source "$REPO_ROOT/modules/profile.bash"
cd "$WORKDIR"
profile::load ".wgx/profile.yml"
printf 'before=%s\n' "${WGX_REPO_KIND}"
rm -f .wgx/profile.yml
if profile::ensure_loaded; then
  printf 'ensure=ok\n'
else
  printf 'ensure=fail\n'
fi
printf 'after=%s\n' "${WGX_REPO_KIND}"
SH
  chmod +x "$helper_script"

  run "$helper_script" "$REPO_ROOT" "$WORKDIR"
  assert_success
  assert_line --index 0 -- "before=webapp"
  assert_line --index 1 -- "ensure=fail"
  assert_line --index 2 -- "after="
}

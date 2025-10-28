#!/usr/bin/env bats

load test_helper

setup() {
  REPO_ROOT="$(pwd)"
}

@test "tracked shell scripts declare a shebang" {
  local script="$BATS_TEST_TMPDIR/check-shebang.sh"
  cat <<'SCRIPT' >"$script"
#!/usr/bin/env bash
set -e
set -u
if ! set -o pipefail 2>/dev/null; then
  if [[ ${WGX_DEBUG:-0} != 0 ]]; then
    echo "shell-ci: 'pipefail' wird nicht unterstützt; fahre ohne fort." >&2
  fi
fi

mapfile -t files < <(git ls-files '*.sh' '*.bash' 'wgx' 'cli/wgx')
missing=()
for file in "${files[@]}"; do
  [[ -f "$file" ]] || continue
  first_line="$(head -n 1 "$file" 2>/dev/null || true)"
  if [[ ${first_line} != '#!'* ]]; then
    missing+=("$file")
  fi
done

if (( ${#missing[@]} > 0 )); then
  {
    echo "Missing shebang in shell scripts:"
    printf '  %s\n' "${missing[@]}"
  } >&2
  exit 1
fi
SCRIPT
  chmod +x "$script"

  run "$script"
  assert_success
  assert_output ""
}

@test "README shell CI commands stay aligned with GitHub Actions" {
  local -a readme_patterns=(
    "bash -n \$(git ls-files '*.sh' '*.bash')"
    "shfmt -d \$(git ls-files '*.sh' '*.bash')"
    "shellcheck -S style \$(git ls-files '*.sh' '*.bash')"
    "bats -r tests"
  )

  for pattern in "${readme_patterns[@]}"; do
    run grep -F "$pattern" "$REPO_ROOT/README.md"
    assert_success
  done

  local -a workflow_patterns=(
    "bash -n"
    "shfmt -d"
    "shellcheck -S style"
    "bats-core/bats-action"
  )

  for pattern in "${workflow_patterns[@]}"; do
    run grep -F "$pattern" "$REPO_ROOT/.github/workflows/ci.yml"
    assert_success
  done
}

@test "assertion helper self-tests pass" {
  if ! command -v bats >/dev/null 2>&1; then
    skip "bats executable not available"
  fi
  run bats -r tests/assertions.bats
  assert_success
}

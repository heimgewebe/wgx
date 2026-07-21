#!/usr/bin/env bats

load test_helper

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  TEST_TMPDIR="$(mktemp -d)"
  FAKE_BIN="$TEST_TMPDIR/bin"
  mkdir -p "$FAKE_BIN" "$TEST_TMPDIR/tmp"
  export REPO_ROOT TEST_TMPDIR FAKE_BIN
  export TMPDIR="$TEST_TMPDIR/tmp"
  export CURL_LOG="$TEST_TMPDIR/curl.args"
  export NPX_LOG="$TEST_TMPDIR/npx.args"
  export SCHEMA_PATH_LOG="$TEST_TMPDIR/schema.path"
  export PATH="$FAKE_BIN:$PATH"

  cat > "$FAKE_BIN/curl" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$@" > "$CURL_LOG"
if [[ "${FAKE_CURL_FAIL:-0}" == "1" ]]; then
  echo "curl: (22) requested URL returned error: 503" >&2
  exit 22
fi
output=""
while [[ $# -gt 0 ]]; do
  case "$1" in
  -o | --output)
    output=${2:-}
    shift 2
    ;;
  *)
    shift
    ;;
  esac
done
if [[ -z "$output" ]]; then
  echo "fake curl: output path fehlt" >&2
  exit 64
fi
printf '%s\n' '{"type":"object"}' > "$output"
SCRIPT
  chmod +x "$FAKE_BIN/curl"

  cat > "$FAKE_BIN/npx" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$@" > "$NPX_LOG"
schema=""
while [[ $# -gt 0 ]]; do
  case "$1" in
  -s)
    schema=${2:-}
    shift 2
    ;;
  *)
    shift
    ;;
  esac
done
printf '%s\n' "$schema" > "$SCHEMA_PATH_LOG"
if [[ "$schema" == "${METRICS_SCHEMA_URL:-}" && "$schema" == http*://* ]]; then
  echo "error: Cannot find schema '$schema'" >&2
  exit 2
fi
if [[ ! -f "$schema" ]]; then
  echo "error: downloaded schema file missing: $schema" >&2
  exit 3
fi
if [[ "${FAKE_NPX_SCHEMA_FAIL:-0}" == "1" ]]; then
  echo "error: schema is invalid" >&2
  exit 2
fi
SCRIPT
  chmod +x "$FAKE_BIN/npx"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

@test "contracts validate downloads remote schema instead of triggering Cannot find schema URL regression" {
  export METRICS_SCHEMA_URL="https://example.invalid/contracts/metrics.json"

  run "$REPO_ROOT/scripts/just-dispatch.sh" contracts validate

  assert_success
  run grep -Fx "$METRICS_SCHEMA_URL" "$CURL_LOG"
  assert_success
  schema_path="$(cat "$SCHEMA_PATH_LOG")"
  [[ "$schema_path" != "$METRICS_SCHEMA_URL" ]]
  [[ "$schema_path" == "$TMPDIR/"* ]]
  [[ ! -e "$schema_path" ]]
  run grep -Fx -- "--spec=draft2020" "$NPX_LOG"
  assert_success
  run grep -Fx -- "--strict=log" "$NPX_LOG"
  assert_success
}

@test "contracts validate reports remote schema download failures and does not invoke ajv" {
  export METRICS_SCHEMA_URL="https://example.invalid/contracts/metrics.json"
  export FAKE_CURL_FAIL=1

  run "$REPO_ROOT/scripts/just-dispatch.sh" contracts validate

  assert_failure
  assert_output --partial "curl: (22) requested URL returned error: 503"
  assert_output --partial "contracts validate: Schema konnte nicht geladen werden: $METRICS_SCHEMA_URL"
  [[ ! -e "$NPX_LOG" ]]
}

@test "contracts validate preserves ajv schema diagnostics" {
  export METRICS_SCHEMA_URL="https://example.invalid/contracts/metrics.json"
  export FAKE_NPX_SCHEMA_FAIL=1

  run "$REPO_ROOT/scripts/just-dispatch.sh" contracts validate

  [[ "$status" -eq 2 ]]
  assert_output --partial "error: schema is invalid"
}

@test "contracts validate keeps explicit local schema paths supported without curl" {
  local_schema="$TEST_TMPDIR/local.schema.json"
  printf '%s\n' '{"type":"object"}' > "$local_schema"
  export METRICS_SCHEMA_URL="$local_schema"

  run "$REPO_ROOT/scripts/just-dispatch.sh" contracts validate

  assert_success
  [[ ! -e "$CURL_LOG" ]]
  run grep -Fx "$local_schema" "$SCHEMA_PATH_LOG"
  assert_success
}

@test "contracts validate rejects unsupported URL schemes explicitly" {
  export METRICS_SCHEMA_URL="ftp://example.invalid/contracts/metrics.json"

  run "$REPO_ROOT/scripts/just-dispatch.sh" contracts validate

  [[ "$status" -eq 2 ]]
  assert_output --partial "contracts validate: Nicht unterstützte Schema-URL: $METRICS_SCHEMA_URL"
  [[ ! -e "$CURL_LOG" ]]
  [[ ! -e "$NPX_LOG" ]]
}


@test "canonical metrics schema pin stays aligned across Justfile workflow and README" {
  expected="https://raw.githubusercontent.com/heimgewebe/metarepo/b215b418a038ff535f07b7888fd6adeb3f4de51c/contracts/metrics.snapshot.schema.json"

  run grep -F "export METRICS_SCHEMA_URL := \"$expected\"" "$REPO_ROOT/Justfile"
  assert_success
  run grep -F "METRICS_SCHEMA_URL: $expected" "$REPO_ROOT/.github/workflows/metrics.yml"
  assert_success
  run grep -F "SCHEMA=\"$expected\"" "$REPO_ROOT/README.md"
  assert_success
  run grep -F 'validate --spec=draft2020 --strict=log -s .ci/metrics.schema.json -d metrics.json' "$REPO_ROOT/.github/workflows/metrics.yml"
  assert_success
}

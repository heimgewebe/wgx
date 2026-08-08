#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TARGET_ROOT="${WGX_INTEGRITY_ROOT:-$REPO_ROOT}"
REPORT_DIR="${TARGET_ROOT}/reports/integrity"
SUMMARY_FILE="${REPORT_DIR}/summary.json"

mkdir -p "$REPORT_DIR"

repo_name="unknown"
if [[ -n "${GITHUB_REPOSITORY:-}" ]]; then
  repo_name="$GITHUB_REPOSITORY"
elif git -C "$TARGET_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  remote_url="$(git -C "$TARGET_ROOT" remote get-url origin 2>/dev/null || true)"
  if [[ -n "$remote_url" ]]; then
    repo_name="$(printf '%s' "$remote_url" | sed -E 's/.*[:/]([^/]+\/[^/]+)(\.git)?$/\1/' | sed 's/\.git$//')"
  fi
fi

generated_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

count_claims=0
if [[ -d "${TARGET_ROOT}/contracts" ]]; then
  count_claims="$(find "${TARGET_ROOT}/contracts" -name '*.schema.json' -type f | wc -l | tr -d ' ')"
fi

count_artifacts=0
if [[ -d "${TARGET_ROOT}/reports" ]]; then
  count_artifacts="$({
    find "${TARGET_ROOT}/reports" -type f \
      ! -path "${SUMMARY_FILE}" \
      ! -path "${REPORT_DIR}/event_payload.json"
  } | wc -l | tr -d ' ')"
fi

count_gaps=0
count_unclear=0
status="OK"
if ((count_artifacts == 0)); then
  status="MISSING"
elif ((count_claims == 0)); then
  status="UNCLEAR"
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "error: python3 is required to generate the integrity report" >&2
  exit 1
fi

export INT_REPO="$repo_name"
export INT_GEN="$generated_at"
export INT_STATUS="$status"
export INT_C_CLAIMS="$count_claims"
export INT_C_ARTIFACTS="$count_artifacts"
export INT_C_GAPS="$count_gaps"
export INT_C_UNCLEAR="$count_unclear"

json_output="$(
  python3 - <<'PY'
import json
import os

print(json.dumps({
    "repo": os.environ["INT_REPO"],
    "generated_at": os.environ["INT_GEN"],
    "status": os.environ["INT_STATUS"],
    "counts": {
        "claims": int(os.environ["INT_C_CLAIMS"]),
        "artifacts": int(os.environ["INT_C_ARTIFACTS"]),
        "loop_gaps": int(os.environ["INT_C_GAPS"]),
        "unclear": int(os.environ["INT_C_UNCLEAR"]),
    },
}, indent=2))
PY
)"

if [[ -z "$json_output" ]]; then
  echo "error: generated integrity JSON is empty" >&2
  exit 1
fi

temp_file="$(mktemp "${REPORT_DIR}/.summary.json.XXXXXX")"
cleanup() {
  rm -f -- "$temp_file"
}
trap cleanup EXIT
printf '%s\n' "$json_output" >"$temp_file"
python3 -m json.tool "$temp_file" >/dev/null
mv -f -- "$temp_file" "$SUMMARY_FILE"
trap - EXIT

if [[ ! -s "$SUMMARY_FILE" ]]; then
  echo "error: integrity summary was not created" >&2
  exit 1
fi

printf '%s\n' "$SUMMARY_FILE"

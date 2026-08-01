#!/usr/bin/env bash
#
# Fleet proof for `wgx validate --profile` (OPERATOR-INTEGRATION-LOOP-V1-T002).
#
# Exercises the receipt contract against three representative core repositories.
# Each repository is materialised from `git archive HEAD` into a scratch tree, so
# the proof runs against the repository's real manifest and real native commands
# without mutating the source checkout. The declared validate profiles are added
# to the snapshot only; adopting them upstream stays a per-repository decision.
#
# Usage: scripts/validate_fleet_proof.sh [output-dir]

set -euo pipefail

WGX_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${1:-${WGX_ROOT}/docs/evidence/validate-fleet-proof}"
SCRATCH="$(mktemp -d "${TMPDIR:-/tmp}/wgx-fleet-proof.XXXXXX")"
trap 'rm -rf "$SCRATCH"' EXIT

# repository:quick checks:full checks
#
# semantAH is deliberately absent: its manifest declares a task named
# `semantah.index`, which the profile parser cannot turn into a shell variable
# name. That crash predates this change and blocks every wgx profile command in
# that repository; see docs/evidence/validate-fleet-proof/README.md.
FLEET=(
  "hausKI:lint:lint test"
  "chronik:guard:guard smoke"
  "weltgewebe:lint:lint test"
)

mkdir -p "$OUT_DIR"

run_wgx() {
  (cd "$1" && shift && WGX_DIR="$WGX_ROOT" PATH="$WGX_ROOT/cli:$PATH" wgx "$@")
}

snapshot() {
  local repo="$1" dest="$2"
  mkdir -p "$dest"
  git -C "/home/alex/repos/$repo" archive HEAD | tar -x -C "$dest"
  git -C "$dest" init -q -b main
  git -C "$dest" add -A
  git -C "$dest" -c user.email=fleet@proof.invalid -c user.name="Fleet Proof" commit -qm "snapshot"
}

# Append the declared validate profiles plus one always-failing and one
# always-slow probe, so green, red and timeout paths are all observable.
declare_profiles() {
  local dest="$1" quick="$2" full="$3"
  python3 - "$dest/.wgx/profile.yml" "$quick" "$full" <<'PY'
import sys

path, quick, full = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(path).read()
root_level = not text.lstrip().startswith('wgx:')
indent = '' if root_level else '  '

block = [
    f'{indent}validate:',
    f'{indent}  quick: [{", ".join(quick.split())}]',
    f'{indent}  full: [{", ".join(full.split())}, redprobe, slowprobe, ciprobe]',
    f'{indent}  ciOnly:',
    f'{indent}    ciprobe: "fleet proof: CI-only declaration"',
]
task_block = [
    f'{indent}  redprobe: "exit 7"',
    f'{indent}  slowprobe: "sleep 60"',
]

lines = text.splitlines()
# Insert the validate block before the tasks mapping and extend tasks with probes.
out, injected, in_tasks = [], False, False
for line in lines:
    stripped = line.strip()
    if not injected and stripped.startswith('tasks:'):
        out.extend(block)
        injected = True
        in_tasks = True
        out.append(line)
        out.extend(task_block)
        continue
    out.append(line)
if not injected:
    out.extend(block)
open(path, 'w').write('\n'.join(out) + '\n')
PY
}

summary="$OUT_DIR/summary.json"
printf '[\n' >"$summary"
sep=""

for entry in "${FLEET[@]}"; do
  IFS=':' read -r repo quick full <<<"$entry"
  dest="$SCRATCH/$repo"
  echo "== $repo"
  snapshot "$repo" "$dest"
  declare_profiles "$dest" "$quick" "$full"

  # 1. deterministic command discovery: identical order across repeated runs
  first="$(run_wgx "$dest" validate --profile full --dry-run || true)"
  second="$(run_wgx "$dest" validate --profile full --dry-run || true)"
  discovery="mismatch"
  [[ "$first" == "$second" ]] && discovery="deterministic"

  # 2. green path: the quick profile over the repository's own checks
  green_status=0
  run_wgx "$dest" validate --profile quick --timeout 300 --json \
    --output "$OUT_DIR/${repo}-quick.json" >/dev/null 2>&1 || green_status=$?

  # 3. red + timeout + redaction: the full profile with the probes
  red_status=0
  FLEET_PROOF_API_TOKEN="never-appears-in-a-receipt" \
    run_wgx "$dest" validate --profile full --timeout 3 --json \
    --output "$OUT_DIR/${repo}-full.json" >/dev/null 2>&1 || red_status=$?

  [[ -n $sep ]] && printf ',\n' >>"$summary"
  python3 - "$repo" "$discovery" "$green_status" "$red_status" \
    "$OUT_DIR/${repo}-quick.json" "$OUT_DIR/${repo}-full.json" "$first" >>"$summary" <<'PY'
import json, sys

repo, discovery, green_status, red_status, quick_path, full_path, plan = sys.argv[1:8]


def load(path):
    try:
        with open(path) as handle:
            return json.load(handle)
    except (OSError, ValueError):
        return None


quick, full = load(quick_path), load(full_path)
statuses = {item['name']: item['status'] for item in (full or {}).get('checks', [])}
skips = {item['name']: item['kind'] for item in (full or {}).get('skipped', [])}
blob = json.dumps(full or {})

json.dump({
    'repository': repo,
    'discovery': discovery,
    'discovery_plan': plan.splitlines(),
    'quick': {
        'exit_status': int(green_status),
        'result': (quick or {}).get('result'),
        'checks': {item['name']: item['status'] for item in (quick or {}).get('checks', [])},
        'receipt_sha256': (quick or {}).get('receipt_sha256'),
    },
    'full': {
        'exit_status': int(red_status),
        'result': (full or {}).get('result'),
        'checks': statuses,
        'skipped': skips,
        'receipt_sha256': (full or {}).get('receipt_sha256'),
    },
    'proves': {
        'deterministic_discovery': discovery == 'deterministic',
        'green_receipt': (quick or {}).get('result') == 'passed',
        'red_receipt': (full or {}).get('result') == 'failed',
        'failing_check_reported': statuses.get('redprobe') == 'failed',
        'timeout_reported': statuses.get('slowprobe') == 'timeout',
        'ci_only_skipped': skips.get('ciprobe') == 'ci-only',
        'secret_absent_from_receipt': 'never-appears-in-a-receipt' not in blob,
    },
}, sys.stdout, indent=2, sort_keys=True)
PY
  sep="set"
done

printf '\n]\n' >>"$summary"
echo "Fleet proof written to $OUT_DIR"

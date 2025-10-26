#!/usr/bin/env bash

_audit_default_dir() {
  local base="${WGX_DIR:-"$(pwd)"}"
  printf '%s/.wgx/audit' "$base"
}

audit::_ledger_path() {
  local target="${WGX_AUDIT_LOG:-}"
  if [[ -z "$target" ]]; then
    target="$(_audit_default_dir)/ledger.jsonl"
  fi
  printf '%s' "$target"
}

audit::log() {
  local event="${1:-}"
  local payload
  payload="$2"
  if [[ -z "$payload" ]]; then
    payload="{}"
  fi
  if [[ -z "$event" ]]; then
    printf 'audit::log: missing event name\n' >&2
    return 1
  fi
  if ! command -v python3 >/dev/null 2>&1; then
    printf 'audit::log: python3 not available – skipping log.\n' >&2
    return 0
  fi
  local ledger
  ledger="$(audit::_ledger_path)" || return 1
  local dir
  dir="$(dirname "$ledger")"
  mkdir -p "$dir"
  local timestamp
  timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  local git_sha
  git_sha="$(git rev-parse HEAD 2>/dev/null || printf '%040d' 0)"
  local prev_line=""
  if [[ -s "$ledger" ]]; then
    prev_line="$(tail -n 1 "$ledger" 2>/dev/null || printf '')"
  fi
  AUDIT_EVENT="$event" \
  AUDIT_PAYLOAD="$payload" \
  AUDIT_TIMESTAMP="$timestamp" \
  AUDIT_SHA="$git_sha" \
  AUDIT_PREV_LINE="$prev_line" \
  python3 - "$ledger" <<'PY'
import json
import os
import sys
import hashlib
from pathlib import Path

ledger_path = Path(sys.argv[1])
event = os.environ.get("AUDIT_EVENT", "")
payload_raw = os.environ.get("AUDIT_PAYLOAD", "{}")
timestamp = os.environ.get("AUDIT_TIMESTAMP") or ""
git_sha = os.environ.get("AUDIT_SHA") or ""
prev_line = os.environ.get("AUDIT_PREV_LINE", "").strip()
prev_hash = "0" * 64
if prev_line:
    try:
        prev_hash = json.loads(prev_line).get("hash", "0" * 64)
        if not isinstance(prev_hash, str) or len(prev_hash) != 64:
            raise ValueError
    except Exception:
        prev_hash = hashlib.sha256(prev_line.encode("utf-8")).hexdigest()
try:
    payload = json.loads(payload_raw)
except Exception:
    payload = {"raw": payload_raw}
entry = {
    "timestamp": timestamp,
    "event": event,
    "git_sha": git_sha,
    "payload": payload,
    "prev_hash": prev_hash,
}
body = json.dumps(entry, sort_keys=True, separators=(",", ":"))
entry["hash"] = hashlib.sha256(body.encode("utf-8")).hexdigest()
with ledger_path.open("a", encoding="utf-8") as fh:
    fh.write(json.dumps(entry, sort_keys=True, separators=(",", ":")))
    fh.write("\n")
PY
}

audit::verify() {
  local strict=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --strict)
        strict=1
        shift
        ;;
      --help|-h)
        cat <<'USAGE'
audit::verify [--strict]
  Prüft die Hash-Kette in .wgx/audit/ledger.jsonl.
  Rückgabewert 0 bei gültiger Kette.
  Mit --strict (oder AUDIT_VERIFY_STRICT=1) führt eine Verletzung zu exit != 0.
USAGE
        return 0
        ;;
      --*)
        printf 'audit::verify: unknown option %s\n' "$1" >&2
        return 1
        ;;
      *)
        break
        ;;
    esac
  done
  if ! command -v python3 >/dev/null 2>&1; then
    printf 'audit::verify: python3 not available.\n' >&2
    return 0
  fi
  local ledger
  ledger="$(audit::_ledger_path)" || return 1
  if [[ ! -s "$ledger" ]]; then
    printf 'audit::verify: ledger empty (%s).\n' "$ledger"
    return 0
  fi
  local output
  if output=$(AUDIT_STRICT_MODE="$strict" python3 - "$ledger" <<'PY'
import json
import os
import sys
import hashlib
from pathlib import Path

ledger_path = Path(sys.argv[1])
prev_hash = "0" * 64
line_no = 0
for raw in ledger_path.read_text(encoding="utf-8").splitlines():
    line = raw.strip()
    if not line:
        continue
    line_no += 1
    try:
        entry = json.loads(line)
    except Exception:
        print(f"invalid_json line={line_no}")
        sys.exit(1)
    if entry.get("prev_hash") != prev_hash:
        print(f"prev_hash_mismatch line={line_no}")
        sys.exit(1)
    data = dict(entry)
    digest = data.pop("hash", None)
    body = json.dumps(data, sort_keys=True, separators=(",", ":"))
    expected = hashlib.sha256(body.encode("utf-8")).hexdigest()
    if digest != expected:
        print(f"hash_mismatch line={line_no}")
        sys.exit(1)
    prev_hash = digest or "0" * 64
print("OK")
PY
); then
    printf '%s\n' "$output"
    return 0
  else
    local rc=$?
    if [[ -n "$output" ]]; then
      printf '%s\n' "$output" >&2
    fi
    if ((strict)) || [[ ${AUDIT_VERIFY_STRICT:-0} != 0 ]]; then
      return $rc
    fi
    printf 'audit::verify: non-strict mode, treating failure as warning.\n' >&2
    return 0
  fi
}

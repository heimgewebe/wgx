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

audit::verify() {
  local strict=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
    --strict)
      strict=1
      shift
      ;;
    --help | -h)
      cat <<'USAGE'
audit::verify [--strict]
  Verifies the hash chain in .wgx/audit/ledger.jsonl without modifying it.
  With --strict (or AUDIT_VERIFY_STRICT=1), verification/dependency failures
  return non-zero; non-strict mode reports damaged evidence as a warning.
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
    if ((strict)) || [[ ${AUDIT_VERIFY_STRICT:-0} != 0 ]]; then
      return 1
    fi
    return 0
  fi

  local ledger
  ledger="$(audit::_ledger_path)" || return 1
  if [[ ! -s "$ledger" ]]; then
    printf 'audit::verify: ledger empty (%s).\n' "$ledger"
    return 0
  fi

  local output
  if output=$(
    python3 - "$ledger" <<'PY'
import hashlib
import json
import sys
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
      return "$rc"
    fi
    printf 'audit::verify: non-strict mode, treating failure as warning.\n' >&2
    return 0
  fi
}

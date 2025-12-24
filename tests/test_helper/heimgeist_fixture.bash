#!/usr/bin/env bash

# Heimgeist Client Library
# Provides internal helpers to archive insights via Chronik.
#
# Environment Variables:
#   WGX_CHRONIK_MOCK_FILE  Path to a file to append events to (instead of real backend).
#   WGX_HEIMGEIST_STRICT   If "1", fails if backend is missing. Default: warn only.

# --- Preflight Check ---

heimgeist::preflight_check() {
  # Skip if already checked in this session
  if [[ "${_HEIMGEIST_PREFLIGHT_DONE:-}" == "1" ]]; then
    return 0
  fi

  # Check for python3 availability early with clear diagnostics
  if ! command -v python3 >/dev/null 2>&1; then
    echo "ERROR: python3 is required for JSON handling in heimgeist lib." >&2
    echo "Please ensure python3 is installed and available in PATH." >&2
    echo "" >&2
    echo "For GitHub Actions workflows, add these steps before running tests:" >&2
    echo "  - name: Install Python dependencies" >&2
    echo "    run: |" >&2
    echo "      sudo apt-get update -y" >&2
    echo "      sudo apt-get install -y python3 python3-venv" >&2
    echo "" >&2
    echo "  - name: Set up Python 3" >&2
    echo "    uses: actions/setup-python@v5" >&2
    echo "    with:" >&2
    echo "      python-version: '3.11'" >&2
    return 1
  fi
  
  # Verify python3 can actually run and import required standard library modules
  # Show diagnostics first to help with troubleshooting
  echo "Python diagnostics:" >&2
  echo "  Path: $(command -v python3)" >&2
  echo "  Version: $(python3 --version 2>&1)" >&2
  
  # Try the import and capture any error output
  local import_error
  if ! import_error=$(python3 -c "import json, sys, os" 2>&1); then
    echo "" >&2
    echo "ERROR: python3 found but unable to import required modules (json, sys, os)." >&2
    echo "This is unexpected as these are standard library modules." >&2
    echo "" >&2
    echo "Python error output:" >&2
    echo "$import_error" >&2
    echo "" >&2
    echo "This may indicate:" >&2
    echo "  - Corrupted or incomplete Python installation" >&2
    echo "  - Missing Python standard library packages" >&2
    echo "  - PYTHONPATH or environment variable issues" >&2
    echo "" >&2
    echo "To fix this in CI, ensure python3 is properly installed:" >&2
    echo "  sudo apt-get update -y" >&2
    echo "  sudo apt-get install -y python3 python3-venv" >&2
    return 1
  fi
  
  # Cache the result to avoid redundant checks
  _HEIMGEIST_PREFLIGHT_DONE=1
  
  return 0
}

# --- Chronik Logic ---

heimgeist::append_event() {
  local key="$1"
  local value="$2"

  if [[ -n "${WGX_CHRONIK_MOCK_FILE:-}" ]]; then
    # Mock-Modus: Anhängen an Datei
    local dir
    dir="$(dirname "$WGX_CHRONIK_MOCK_FILE")"
    if [[ ! -d "$dir" ]]; then
      mkdir -p "$dir"
    fi
    printf '%s=%s\n' "$key" "$value" >>"$WGX_CHRONIK_MOCK_FILE"
    return 0
  fi

  # Real-Modus (Platzhalter)
  # Hier würde der echte Versand an Chronik stehen (z.B. curl)

  if [[ "${WGX_HEIMGEIST_STRICT:-0}" == "1" ]]; then
      die "Chronik backend not configured and WGX_CHRONIK_MOCK_FILE not set (STRICT mode)."
      return 1
  fi

  warn "Chronik backend not configured and WGX_CHRONIK_MOCK_FILE not set (Warn-only)."
  return 0
}

# --- Archivist Logic ---

heimgeist::archive_insight() {
  local raw_id="$1"
  # Use provided role (default wgx.guard)
  local role="${2:-wgx.guard}"
  local data_json="$3"

  # Run preflight check before proceeding
  if ! heimgeist::preflight_check; then
    die "python3 required for JSON handling in heimgeist lib."
  fi

  # ID Consistency: Ensure ID is prefixed with evt-
  local event_id="evt-${raw_id}"

  # Zeitstempel generieren (ISO 8601)
  local timestamp
  if date --version >/dev/null 2>&1; then
    # GNU date
    timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  else
    # BSD date (macOS)
    timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  fi

  # JSON Wrapper bauen
  local payload
  # Use env vars for safe passing of values to avoid injection
  export HG_EVENT_ID="$event_id"
  export HG_TIMESTAMP="$timestamp"
  export HG_ROLE="$role"

  # Structure aligned with relaxed SSOT:
  # meta.role is present (string)
  # No meta.producer enforced if not in contract (or optional)

  payload=$(python3 -c "import json, sys, os; print(json.dumps({
    'kind': 'heimgeist.insight',
    'version': 1,
    'id': os.environ['HG_EVENT_ID'],
    'meta': {
      'occurred_at': os.environ['HG_TIMESTAMP'],
      'role': os.environ['HG_ROLE']
    },
    'data': json.loads(sys.stdin.read())
  }))" <<< "$data_json")

  # An Chronik senden
  heimgeist::append_event "$event_id" "$payload"
}

#!/usr/bin/env bash

# Rolle: Integritäts-Generator
# Erzeugt reports/integrity/summary.json basierend auf Checks.

integrity::generate() {
  local target_root="${WGX_TARGET_ROOT:-$(pwd)}"
  local report_dir="${target_root}/reports/integrity"
  local summary_file="${report_dir}/summary.json"

  mkdir -p "$report_dir"

  local repo_name="unknown"
  if git_has_remote; then
    repo_name="$(git remote get-url origin | sed -E 's/.*[:/]([^/]+\/[^/]+)(\.git)?$/\1/')"
  fi

  local generated_at
  generated_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  # --- Checks / Counts ---

  # 1. Claims (Contracts)
  local count_claims=0
  if [[ -d "${target_root}/contracts" ]]; then
    count_claims=$(find "${target_root}/contracts" -name "*.schema.json" | wc -l | tr -d ' ')
  fi

  # 2. Artifacts (Reports)
  local count_artifacts=0
  if [[ -d "${target_root}/reports" ]]; then
    count_artifacts=$(find "${target_root}/reports" -type f ! -name "summary.json" | wc -l | tr -d ' ')
  fi

  # 3. Gaps (Missing expected files based on profile - simplified)
  # "Missing ist ein valider Zustand" -> wir zählen nur offensichtliche Lücken
  local count_gaps=0
  # (Placeholder logic)

  # 4. Unclear (Files that are not tracked or unknown)
  local count_unclear=0
  # (Placeholder logic)

  # Status determination
  local status="OK"
  if ((count_artifacts == 0)); then
    status="MISSING" # No artifacts -> missing proof
  elif ((count_claims == 0)); then
    status="UNCLEAR" # No contracts -> unclear what integrity means
  fi

  # JSON Construction
  # Using python for safe JSON generation
  if ! command -v python3 >/dev/null 2>&1; then
    echo "Fehler: python3 wird benötigt, ist aber nicht installiert" >&2
    return 1
  fi

  export INT_REPO="$repo_name"
  export INT_GEN="$generated_at"
  export INT_STATUS="$status"
  export INT_C_CLAIMS="$count_claims"
  export INT_C_ARTIFACTS="$count_artifacts"
  export INT_C_GAPS="$count_gaps"
  export INT_C_UNCLEAR="$count_unclear"

  if ! python3 -c "import json, os; print(json.dumps({
    'repo': os.environ['INT_REPO'],
    'generated_at': os.environ['INT_GEN'],
    'status': os.environ['INT_STATUS'],
    'counts': {
      'claims': int(os.environ['INT_C_CLAIMS']),
      'artifacts': int(os.environ['INT_C_ARTIFACTS']),
      'loop_gaps': int(os.environ['INT_C_GAPS']),
      'unclear': int(os.environ['INT_C_UNCLEAR'])
    }
  }, indent=2))" > "$summary_file"; then
    echo "Fehler: Erzeugung der Zusammenfassungs-JSON fehlgeschlagen" >&2
    return 1
  fi

  # Verify the file was created and is not empty
  if [[ ! -s "$summary_file" ]]; then
    echo "Fehler: Zusammenfassungsdatei ist leer oder wurde nicht erstellt" >&2
    return 1
  fi

  # Return path to generated file
  echo "$summary_file"
}

#!/usr/bin/env bash

# Rolle: Integritäts-Observer
# Liest reports/integrity/summary.json und gibt sie tabellarisch aus.
# Keine Bewertung, kein Fail.

cmd_integrity() {
  local target_root="${WGX_TARGET_ROOT:-$(pwd)}"
  local summary_file="${target_root}/reports/integrity/summary.json"

  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    echo "Usage: wgx integrity"
    echo ""
    echo "Zeigt den aktuellen Integritätsstatus (Diagnose) an."
    echo "Liest aus reports/integrity/summary.json."
    return 0
  fi

  if [[ ! -f "$summary_file" ]]; then
    # Beobachter, nicht Richter: Wenn nichts da ist, ist das auch eine Beobachtung.
    info "Kein Integritätsbericht gefunden (${summary_file})."
    info "Status: MISSING"
    return 0
  fi

  if ! has jq; then
    warn "jq fehlt. Kann JSON nicht parsen."
    cat "$summary_file"
    return 0
  fi

  # JSON parsen und tabellarisch ausgeben
  local repo generated counts_claims counts_artifacts counts_gaps counts_unclear

  # Safe read with jq
  repo=$(jq -r '.repo // "unknown"' "$summary_file")
  generated=$(jq -r '.generated_at // "unknown"' "$summary_file")

  # Counts extraction
  counts_claims=$(jq -r '.counts.claims // 0' "$summary_file")
  counts_artifacts=$(jq -r '.counts.artifacts // 0' "$summary_file")
  counts_gaps=$(jq -r '.counts.loop_gaps // 0' "$summary_file")
  counts_unclear=$(jq -r '.counts.unclear // 0' "$summary_file")

  # Use -- to prevent printf from interpreting dashes as flags
  printf "\nIntegritäts-Diagnose (Beobachter-Modus)\n"
  printf -- "---------------------------------------\n"
  printf "Repo:       %s\n" "$repo"
  printf "Generated:  %s\n" "$generated"
  printf "\n"
  printf "%-12s | %s\n" "Metrik" "Anzahl"
  printf -- "-------------|-------\n"
  printf "%-12s | %s\n" "Claims" "$counts_claims"
  printf "%-12s | %s\n" "Artifacts" "$counts_artifacts"
  printf "%-12s | %s\n" "Loop Gaps" "$counts_gaps"
  printf "%-12s | %s\n" "Unclear" "$counts_unclear"
  printf "\n"

  return 0
}

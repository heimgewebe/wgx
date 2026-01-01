#!/usr/bin/env bash

# Rolle: Integritäts-Diagnose
# Verwaltet reports/integrity/summary.json (Lesen & Erzeugen).

cmd_integrity() {
  local DO_UPDATE=0
  local DO_PUBLISH=0
  local target_root="${WGX_TARGET_ROOT:-$(pwd)}"
  local summary_file="${target_root}/reports/integrity/summary.json"

  while [[ $# -gt 0 ]]; do
    case "$1" in
    --update | -u)
      DO_UPDATE=1
      ;;
    --publish | -p)
      DO_PUBLISH=1
      ;;
    -h | --help)
      echo "Usage: wgx integrity [options]"
      echo ""
      echo "Options:"
      echo "  --update, -u    Erzeugt/Aktualisiert den Integritätsbericht (und zeigt danach den Status an)."
      echo "  --publish, -p   Gibt ein Event-JSON (integrity.summary.published.v1) aus (und zeigt ebenfalls den Status an)."
      echo "  --help, -h      Zeigt diese Hilfe."
      echo ""
      echo "Ohne Optionen: Liest reports/integrity/summary.json und zeigt den Integritäts-Status an."
      echo "Optionen können kombiniert werden, z.B.: 'wgx integrity --update --publish' zum Erzeugen/Aktualisieren und anschließenden Veröffentlichen."
      return 0
      ;;
    *) ;;
    esac
    shift
  done

  # 1. Update (Generate) if requested
  if ((DO_UPDATE)); then
    # Ensure module is loaded
    local mod_integrity="${WGX_PROJECT_ROOT:-$WGX_DIR}/modules/integrity.bash"
    if [[ -r "$mod_integrity" ]]; then
      source "$mod_integrity"
    else
      die "Modul integrity.bash nicht gefunden."
    fi

    info "Erzeuge Integritätsbericht..."
    integrity::generate >/dev/null
    ok "Bericht aktualisiert: $summary_file"
  fi

  # 2. Check existence
  if [[ ! -f "$summary_file" ]]; then
    # Beobachter, nicht Richter: Wenn nichts da ist, ist das auch eine Beobachtung.
    info "Kein Integritätsbericht gefunden (${summary_file})."
    info "Nutze 'wgx integrity --update' um ihn zu erzeugen."
    info "Status: MISSING"
    return 0
  fi

  # 3. Publish Event (if requested)
  if ((DO_PUBLISH)); then
    local mod_heimgeist="${WGX_PROJECT_ROOT:-$WGX_DIR}/modules/heimgeist.bash"
    if [[ -r "$mod_heimgeist" ]]; then
      source "$mod_heimgeist"
    else
      die "Modul heimgeist.bash nicht gefunden."
    fi

    if ! has jq; then
      warn "jq fehlt. Kann Bericht für Event nicht lesen."
    else
      local data_json
      data_json="$(cat "$summary_file")"
      # Event senden (hier: auf stdout ausgeben). Fehler sind nicht fatal, werden aber geloggt.
      if ! heimgeist::emit "integrity.summary.published.v1" "$data_json" "wgx.integrity"; then
        warn "Konnte Event 'integrity.summary.published.v1' nicht senden (heimgeist::emit fehlgeschlagen)."
      fi
    fi
    # Continue to display report unless we want to exit?
    # Usually publish might be used in CI where we don't need the table output.
    # But let's show the table too for verification.
  fi

  if ! has jq; then
    warn "jq fehlt. Kann JSON nicht parsen."
    cat "$summary_file"
    return 0
  fi

  # JSON parsen und tabellarisch ausgeben
  local repo generated counts_claims counts_artifacts counts_gaps counts_unclear status

  # Safe read with jq
  repo=$(jq -r '.repo // "unknown"' "$summary_file")
  generated=$(jq -r '.generated_at // "unknown"' "$summary_file")
  status=$(jq -r '.status // "UNKNOWN"' "$summary_file")

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
  printf "Status:     %s\n" "$status"
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

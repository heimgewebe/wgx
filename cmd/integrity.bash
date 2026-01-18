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
      echo "  --update, -u    Erzeugt/Aktualisiert den Integritätsbericht."
      echo "  --publish, -p   Gibt ein Event-JSON (integrity.summary.published.v1) aus."
      echo "  --help, -h      Zeigt diese Hilfe."
      echo ""
      echo "Standard: Liest reports/integrity/summary.json und zeigt Status an."
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
      # shellcheck source=modules/integrity.bash
      source "$mod_integrity"
    else
      die "Modul integrity.bash nicht gefunden."
    fi

    info "Erzeuge Integritätsbericht..."
    if ! integrity::generate >/dev/null; then
      die "Fehler beim Erzeugen des Integritätsberichts."
    fi
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
      # shellcheck source=modules/heimgeist.bash
      source "$mod_heimgeist"
    else
      die "Modul heimgeist.bash nicht gefunden."
    fi

    if ! has jq; then
      warn "jq fehlt. Kann Bericht für Event nicht lesen."
    else
      local repo generated_at status
      repo=$(jq -r '.repo // "unknown"' "$summary_file")
      generated_at=$(jq -r '.generated_at // "unknown"' "$summary_file")
      status=$(jq -r '.status // "UNKNOWN"' "$summary_file")

      if [[ "$generated_at" == "unknown" || "$status" == "UNKNOWN" ]]; then
        warn "Integritätsbericht unvollständig (generated_at/status fehlt). Überspringe Event-Payload."
        return 0
      fi

      # Construct URL (Canonical Release Asset)
      local url=""
      local repo_name="$repo"

      # Fallback detection if repo from summary.json is not usable
      if [[ "$repo_name" == "unknown" || ! "$repo_name" =~ ^[^/]+/[^/]+$ ]]; then
        if [[ -n "${GITHUB_REPOSITORY:-}" ]]; then
          repo_name="$GITHUB_REPOSITORY"
        else
          local remote_url
          remote_url=$(git remote get-url origin 2>/dev/null || echo "")
          if [[ "$remote_url" =~ github\.com[:/]([^/]+)/([^/]+)(\.git)?$ ]]; then
            local org="${BASH_REMATCH[1]}"
            local rname="${BASH_REMATCH[2]}"
            rname="${rname%.git}"
            repo_name="${org}/${rname}"
          fi
        fi
      fi

      # Ensure repo_name is strictly owner/repo format, else unknown
      if [[ -z "$repo_name" || ! "$repo_name" =~ ^[^/]+/[^/]+$ ]]; then
        repo_name="unknown"
      fi

      if [[ "$repo_name" != "unknown" ]]; then
        url="https://github.com/${repo_name}/releases/download/integrity/summary.json"
      fi

      if [[ -z "$url" ]]; then
        warn "Konnte keine gültige URL für das Integritäts-Event konstruieren. (Repo: $repo_name)"
        return 0
      fi

      # Construct Payload JSON
      # The payload requires: url, generated_at, repo, status
      local payload_json
      export PL_URL="$url"
      export PL_GEN="$generated_at"
      export PL_REPO="$repo_name"
      export PL_STAT="$status"

      if ! command -v python3 >/dev/null 2>&1; then
        die "python3 fehlt. Kann Event-Payload nicht erzeugen."
      fi

      if ! payload_json=$(python3 -c "import json, os; print(json.dumps({
           'url': os.environ['PL_URL'],
           'generated_at': os.environ['PL_GEN'],
           'repo': os.environ['PL_REPO'],
           'status': os.environ['PL_STAT']
         }))"); then
        die "Fehler beim Erzeugen des Event-Payloads."
      fi

      if [[ -z "$payload_json" ]]; then
        die "Generierter Payload ist leer."
      fi

      # Write payload to file (Canonical)
      local payload_file="${target_root}/reports/integrity/event_payload.json"
      printf '%s' "$payload_json" > "$payload_file"

      # Emit Event - failure is acceptable but should be logged
      if ! heimgeist::emit "integrity.summary.published.v1" "$repo_name" "$payload_json"; then
        warn "Konnte Event 'integrity.summary.published.v1' nicht senden (heimgeist::emit fehlgeschlagen)."
      fi
      return 0
    fi
  fi

  if ! has jq; then
    warn "jq fehlt. Kann JSON nicht parsen."
    cat "$summary_file"
    return 0
  fi

  # JSON parsen und tabellarisch ausgeben
  local repo generated_at counts_claims counts_artifacts counts_gaps counts_unclear status

  # Safe read with jq
  repo=$(jq -r '.repo // "unknown"' "$summary_file")
  generated_at=$(jq -r '.generated_at // "unknown"' "$summary_file")
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
  printf "Generated:  %s\n" "$generated_at"
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

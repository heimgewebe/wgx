#!/usr/bin/env bash

# Status-Modul: Projektstatus anzeigen

status_cmd() {
  profile::ensure_loaded || true

  echo "▶ Repo-Root: $(git rev-parse --show-toplevel 2>/dev/null || echo 'N/A')"
  echo "▶ Branch: $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'N/A')"

  if [[ -n ${WGX_REPO_KIND:-} ]]; then
    echo "▶ Repo-Kind: ${WGX_REPO_KIND}"
  fi
  if [[ -n ${PROFILE_VERSION:-} ]]; then
    echo "▶ Manifest-Version: ${PROFILE_VERSION}"
  fi
  local required=""
  if [[ -n ${WGX_REQUIRED_RANGE:-} ]]; then
    required+="range=${WGX_REQUIRED_RANGE}"
  fi
  if [[ -n ${WGX_REQUIRED_MIN:-} ]]; then
    [[ -n $required ]] && required+=" "
    required+="min=${WGX_REQUIRED_MIN}"
  fi
  if [[ -n $required ]]; then
    echo "▶ requiredWgx: ${required}"
  fi

  # Ahead/Behind
  if git rev-parse --abbrev-ref HEAD >/dev/null 2>&1; then
    local ahead behind
    ahead=$(git rev-list --right-only --count '@{u}'...HEAD 2>/dev/null || echo 0)
    behind=$(git rev-list --left-only --count '@{u}'...HEAD 2>/dev/null || echo 0)
    echo "▶ Ahead: $ahead | Behind: $behind"
  fi

  # Erkannte Projektteile
  local info_present=0
  if [[ -n ${WGX_DIR_WEB:-}${WGX_DIR_API:-}${WGX_DIR_DATA:-} ]]; then
    info_present=1
    for entry in WEB:"${WGX_DIR_WEB}" API:"${WGX_DIR_API}" DATA:"${WGX_DIR_DATA}"; do
      local label="${entry%%:*}"
      local path="${entry#*:}"
      [[ -n $path ]] || continue
      if [[ -d $path ]]; then
        echo "▶ ${label}: ${path} (ok)"
      else
        echo "▶ ${label}: ${path} (missing)"
      fi
    done
  fi
  if [ "$info_present" != "1" ]; then
    local fallback_present=0
    if [[ -d web ]]; then
      echo "▶ Web-Verzeichnis: web"
      fallback_present=1
    fi
    if [[ -d api ]]; then
      echo "▶ API-Verzeichnis: api"
      fallback_present=1
    fi
    if [[ -d crates ]]; then
      echo "▶ crates vorhanden"
      fallback_present=1
    fi

    if [ "$fallback_present" = "1" ]; then

      info_present=1
    fi
  fi

  # OFFLINE?
  [[ -n "${OFFLINE:-}" ]] && echo "▶ OFFLINE=1 aktiv"
}

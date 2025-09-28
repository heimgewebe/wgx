#!/usr/bin/env bash
# Status-Modul: Projektstatus anzeigen

status_cmd() {
  echo "▶ Repo-Root: $(git rev-parse --show-toplevel 2>/dev/null || echo 'N/A')"
  echo "▶ Branch: $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'N/A')"

  if [[ -n ${WGX_REPO_KIND:-} ]]; then
    echo "▶ Repo-Kind: ${WGX_REPO_KIND}"
  fi
  if [[ -n ${WGX_PROFILE_API_VERSION:-} ]]; then
    echo "▶ Manifest-Version: ${WGX_PROFILE_API_VERSION}"
  fi
  if [[ -n ${WGX_REQUIRED:-} ]]; then
    echo "▶ requiredWgx: ${WGX_REQUIRED}"
  fi

  # Ahead/Behind
  if git rev-parse --abbrev-ref HEAD >/dev/null 2>&1; then
    local ahead behind
    ahead=$(git rev-list --right-only --count '@{u}'...HEAD 2>/dev/null || echo 0)
    behind=$(git rev-list --left-only --count '@{u}'...HEAD 2>/dev/null || echo 0)
    echo "▶ Ahead: $ahead | Behind: $behind"
  fi

  # Erkannte Projektteile
  if [[ -n ${WGX_DIR_WEB+x} ]]; then
    if [[ -n ${WGX_DIR_WEB} ]]; then
      echo "▶ Web-Verzeichnis: ${WGX_DIR_WEB}"
    else
      echo "▶ Web-Verzeichnis: (nicht vorhanden)"
    fi
  elif [[ -d web ]]; then
    echo "▶ Web-Teil vorhanden"
  fi

  if [[ -n ${WGX_DIR_API+x} ]]; then
    if [[ -n ${WGX_DIR_API} ]]; then
      echo "▶ API-Verzeichnis: ${WGX_DIR_API}"
    else
      echo "▶ API-Verzeichnis: (nicht vorhanden)"
    fi
  elif [[ -d api ]]; then
    echo "▶ API-Teil vorhanden"
  fi

  if [[ -n ${WGX_DIR_DATA+x} ]]; then
    if [[ -n ${WGX_DIR_DATA} ]]; then
      echo "▶ Data-Verzeichnis: ${WGX_DIR_DATA}"
    else
      echo "▶ Data-Verzeichnis: (nicht vorhanden)"
    fi
  elif [[ -d crates ]]; then
    echo "▶ Rust crates vorhanden"
  fi

  # OFFLINE?
  [[ -n "${OFFLINE:-}" ]] && echo "▶ OFFLINE=1 aktiv"
}

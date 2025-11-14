#!/usr/bin/env bash

set -e
set -u

if ! set -o pipefail 2>/dev/null; then
  if [[ ${WGX_DEBUG:-0} != 0 ]]; then
    echo "wgx-metrics-snapshot: 'pipefail' wird nicht unterstützt; fahre ohne fort." >&2
  fi
fi

print_json=0
output_path=${WGX_METRICS_OUTPUT:-metrics.json}

usage() {
  cat <<'EOF'
wgx-metrics-snapshot.sh [--json] [--output PATH]

Erzeugt eine metrics.json gemäß contracts-v1 (ts, host, updates, backup, drift).

  --json           JSON zusätzlich zur Datei auf STDOUT ausgeben
  --output PATH    Ziel-Datei (Standard: metrics.json oder WGX_METRICS_OUTPUT)
EOF
}

while ((${#})); do
  case "$1" in
  --json)
    print_json=1
    ;;
  --output)
    if (($# < 2)); then
      echo "--output erwartet einen Pfad" >&2
      usage >&2
      exit 1
    fi
    output_path=$2
    shift
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    echo "Unbekannte Option: $1" >&2
    usage >&2
    exit 1
    ;;
  esac
  shift
done

if [[ -z ${output_path} ]]; then
  echo "Der Ausgabe-Pfad darf nicht leer sein" >&2
  exit 1
fi

output_dir=$(dirname "$output_path")
if [[ ! -d $output_dir ]]; then
  if ! mkdir -p "$output_dir"; then
    echo "Konnte Ausgabe-Verzeichnis '$output_dir' nicht anlegen" >&2
    exit 1
  fi
fi

ts=$(date +%s)
host=$(hostname)

# Updates (Platzhalter – OS-spezifisch später ersetzen)
updates_os=${UPDATES_OS:-0}
updates_pkg=${UPDATES_PKG:-0}
updates_flatpak=${UPDATES_FLATPAK:-0}

# Backup-Status (Platzhalter)
if date -d "yesterday" +%F >/dev/null 2>&1; then
  # Backup-Status konsistent: age_days steuert last_ok
  age_days=${BACKUP_AGE_DAYS:-1}
  if date -d "today" +%F >/dev/null 2>&1; then
    # GNU date
    last_ok=$(date -d "${age_days} day ago" +%F)
  else
    # BSD/macOS date
    last_ok=$(date -v-"${age_days}"d +%F)
  fi
else
  last_ok=$(date -v-"${age_days}"d +%F) # BSD/macOS
fi
age_days=${BACKUP_AGE_DAYS:-1}

# Template-Drift (Platzhalter)
drift_templates=${DRIFT_TEMPLATES:-0}

json=$(jq -n \
  --arg host "$host" \
  --arg last_ok "$last_ok" \
  --argjson ts "$ts" \
  --argjson uos "$updates_os" \
  --argjson upkg "$updates_pkg" \
  --argjson ufp "$updates_flatpak" \
  --argjson age "$age_days" \
  --argjson drift "$drift_templates" \
  '{
    ts: $ts,
    host: $host,
    updates: { os: $uos, pkg: $upkg, flatpak: $ufp },
    backup: { last_ok: $last_ok, age_days: $age },
    drift: { templates: $drift }
  }')

printf '%s\n' "$json" >"$output_path"

if ((print_json != 0)); then
  printf '%s\n' "$json"
fi

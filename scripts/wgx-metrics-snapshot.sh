#!/usr/bin/env bash
set -euo pipefail

ts=$(date +%s)
host=$(hostname)

# Temperaturen (best effort; leeres Objekt, wenn sensors fehlt)
temps_json="{}"
if command -v sensors >/dev/null 2>&1; then
  mapfile -t lines < <(sensors 2>/dev/null | awk -F'[:+ ]+' '/°C/{print $1":"$3}')
  if [ ${#lines[@]} -gt 0 ]; then
    kv=""
    for l in "${lines[@]}"; do
      k=${l%%:*}
      v=${l##*:}
      v=${v%%.*}
      kv="${kv}${kv:+,}\"${k}\":${v}"
    done
    temps_json="{${kv}}"
  fi
fi

# Updates (Platzhalter – OS-spezifisch später ersetzen)
updates_os=${UPDATES_OS:-0}
updates_pkg=${UPDATES_PKG:-0}
updates_flatpak=${UPDATES_FLATPAK:-0}

# Backup-Status (Platzhalter)
if date -d "yesterday" +%F >/dev/null 2>&1; then
  last_ok=$(date -d "yesterday" +%F)
else
  last_ok=$(date -v-1d +%F) # BSD/macOS
fi
age_days=1

# Template-Drift (Platzhalter)
drift_templates=${DRIFT_TEMPLATES:-0}

jq -n \
  --arg host "$host" \
  --arg last_ok "$last_ok" \
  --argjson ts "$ts" \
  --argjson temps "$temps_json" \
  --argjson uos "$updates_os" \
  --argjson upkg "$updates_pkg" \
  --argjson ufp "$updates_flatpak" \
  --argjson age "$age_days" \
  --argjson drift "$drift_templates" \
  '{
  ts: $ts,
  host: $host,
  temps: $temps,
  updates: { os: $uos, pkg: $upkg, flatpak: $ufp },
  backup: { last_ok: $last_ok, age_days: $age },
  drift: { templates: $drift }
}'

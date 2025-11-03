#!/usr/bin/env bash
#
# wgx validate — prüft das .wgx/profile.* Manifest
#

validate_cmd() {
  local json=0 help=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --json) json=1 ;;
      -h | --help) help=1 ;;
      --)
        shift
        break
        ;;
      *) break ;;
    esac
    shift
  done

  if ((help)); then
    cat <<'USAGE'
Usage:
  wgx validate [--json]

Validiert das Manifest (.wgx/profile.*) im aktuellen Repository.
Exit-Status: 0 bei gültigem Manifest, sonst >0.

Optionen:
  --json   Kompakte maschinenlesbare Ausgabe:
           {"ok":bool,"errors":[...],"missingCapabilities":[...]}
USAGE
    return 0
  fi

  # Profil sicherstellen
  if ! profile::ensure_loaded; then
    if ((json)); then
      printf '{"ok":false,"errors":["no_manifest"],"missingCapabilities":[]}\n'
    else
      warn "Kein Profil gefunden (.wgx/profile.yml|.yaml|.json)."
    fi
    return 1
  fi

  # Manifest prüfen (nutzt vorhandene Profil-API)
  local -a _errors=() _missing=()
  profile::validate_manifest _errors _missing || true

  local ok=1
  if ((${#_errors[@]})); then ok=0; fi

  if ((json)); then
    # JSON-Ausgabe
    printf '{"ok":%s,"errors":[' "$([ $ok -eq 1 ] && echo true || echo false)"
    local i
    for i in "${!_errors[@]}"; do
      printf '%s"%s"' "$([ $i -gt 0 ] && echo ,)" "${_errors[$i]}"
    done
    printf '],"missingCapabilities":['
    for i in "${!_missing[@]}"; do
      printf '%s"%s"' "$([ $i -gt 0 ] && echo ,)" "${_missing[$i]}"
    done
    printf ']}\n'
  else
    # Menschlich lesbar
    if ((ok)); then
      ok "Manifest ist gültig."
    else
      warn "Manifest ist NICHT gültig."
      local e
      for e in "${_errors[@]}"; do
        printf '  - %s\n' "$e" >&2
      done
      if ((${#_missing[@]})); then
        printf 'Fehlende Capabilities:\n' >&2
        for e in "${_missing[@]}"; do
          printf '  - %s\n' "$e" >&2
        done
      fi
    fi
  fi
  return $((ok ? 0 : 1))
}

# Einheitlicher Einstiegspunkt – wie bei den anderen cmd/*-Skripten
wgx_command_main() {
  validate_cmd "$@"
}

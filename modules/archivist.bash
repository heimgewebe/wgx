#!/usr/bin/env bash

# Archivist-Modul: Bereitet Insights auf und sendet sie an Chronik.

# Importiere abhängige Module (angenommen, diese werden vom Aufrufer oder hier geladen)
# Wir verlassen uns darauf, dass `modules/chronik.bash` verfügbar ist.

archivist::archive_insight() {
  local id="$1"
  local role="$2"
  local data_json="$3"

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
  # Wir nutzen printf, um das JSON sicher zusammenzubauen.
  # Achtung: data_json wird hier direkt eingefügt, muss also valides JSON sein.
  local payload
  # Wir verwenden python3 für sicheres JSON-Composing, wenn möglich, um Escaping-Probleme zu vermeiden.
  if command -v python3 >/dev/null 2>&1; then
    payload=$(python3 -c "import json, sys; print(json.dumps({
      'kind': 'heimgeist.insight',
      'version': 1,
      'id': '$id',
      'meta': {
        'occurred_at': '$timestamp',
        'role': '$role'
      },
      'data': json.loads(sys.stdin.read())
    }))" <<< "$data_json")
  else
    # Fallback: Simple string manipulation (Riskant bei komplexem data_json, aber für einfache Zwecke ok)
    # Bevorzugt python3
    die "python3 required for JSON handling in archivist."
  fi

  # An Chronik senden
  local key="evt-${id}"
  chronik::append "$key" "$payload"
}

#!/usr/bin/env bash

# Chronik-Modul: Interaktion mit dem Chronik-Dienst (oder Mock)
# Konfigurierbare Umgebungsvariablen:
#   WGX_CHRONIK_MOCK_FILE  Pfad zu einer Datei, in die Events geschrieben werden (statt echtem Versand).

chronik::append() {
  local key="$1"
  local value="$2"

  if [[ -n "${WGX_CHRONIK_MOCK_FILE:-}" ]]; then
    # Mock-Modus: Anhängen an Datei
    # Wir stellen sicher, dass das Verzeichnis existiert
    local dir
    dir="$(dirname "$WGX_CHRONIK_MOCK_FILE")"
    if [[ ! -d "$dir" ]]; then
      mkdir -p "$dir"
    fi
    printf '%s=%s\n' "$key" "$value" >>"$WGX_CHRONIK_MOCK_FILE"
    return 0
  fi

  # Real-Modus (Platzhalter)
  # Hier würde der echte Versand an Chronik stehen (z.B. curl)
  # Aktuell noch nicht implementiert, daher Warnung und Return 0 (non-blocking)
  # oder Return 1, wenn wir Versand erzwingen wollen.
  # Laut Anforderung "Guard bricht bei fehlender Archivierung/IDs" müssen wir hier evtl. failen,
  # wenn kein Mock und kein Backend da ist?
  # Fürs Erste: Loggen und failen, wenn URL nicht gesetzt (wenn wir eine URL hätten).

  warn "Chronik backend not configured and WGX_CHRONIK_MOCK_FILE not set."
  return 1
}

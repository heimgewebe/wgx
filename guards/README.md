# WGX Guards

Dieses Verzeichnis enthält Guard-Skripte, die Fleet-Kohärenz erzwingen.

## contracts_meta_guard.py

Prüft `contracts/events/*.schema.json` und optional `*.meta.json`:

- keine `x-*` Keys in `.schema.json` (strict-validator kompatibel)
- `$ref: "./..."` muss auflösbar sein (Datei existiert im gleichen Ordner)
- Sidecar `*.meta.json` (falls vorhanden) ist valides JSON und enthält Governance-Struktur

Warum: Manche Strict-Validatoren brechen bei unbekannten Keywords; Governance-Meta wird daher ausgelagert.

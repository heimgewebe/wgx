# WGX Guards

Dieses Verzeichnis enthält Guard-Skripte, die Fleet-Kohärenz erzwingen.

## contracts_meta_guard.py

Prüft `contracts/events/*.schema.json` und optional `*.meta.json`:

- keine `x-*` Keys in `.schema.json` (strict-validator kompatibel)
- `$ref: "./..."` muss auflösbar sein (Datei existiert im gleichen Ordner)
- Sidecar `*.meta.json` (falls vorhanden) ist valides JSON und enthält Governance-Struktur

Warum: Manche Strict-Validatoren brechen bei unbekannten Keywords; Governance-Meta wird daher ausgelagert.

## data_flow_guard.py

Validiert Datenartefakte gegen JSON-Schemas basierend auf einer Flow-Definition.

- **Konfiguration:** `.wgx/flows.json` (Canonical) oder `contracts/flows.json` (Legacy).
- **Logik:**
  - Daten existieren + Schema fehlt = **FAIL** (Verhindert unvalidierten Datenfluss).
  - Daten existieren + Schema existiert = **VALIDATE** (Fail bei Schema-Verletzung).
  - Daten fehlen = **SKIP** (OK).

### Single Source of Truth (SSOT)

Die referenzierten Schemas **MÜSSEN** entweder:
1. Automatisch aus dem Metarepo gespiegelt werden (`contracts/...`).
2. Explizit als vendored Contracts abgelegt sein (`.wgx/contracts/...`).

**Wichtig:** Der Guard prüft strikt, ob Referenzen (`$ref`) aufgelöst werden können. Wenn die installierte `jsonschema`-Version keine Referenzauflösung unterstützt (fehlender `RefResolver` ohne `referencing`-Bibliothek), bricht der Guard mit einem Fehler ab. Dies verhindert Scheinsicherheit.

**Beispiel `.wgx/flows.json`:**

```json
{
  "flows": {
    "my_artifact": {
      "schema": ".wgx/contracts/my_artifact.schema.json",
      "data": ["artifacts/output.json"]
    }
  }
}
```

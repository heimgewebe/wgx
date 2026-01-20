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

**Optional:** Dieser Guard führt die Validierung nur durch, wenn die Python-Bibliothek `jsonschema` installiert ist.
Fehlt sie, überspringt der Guard die Prüfung (Skip/OK), um CI-Umgebungen nicht zu blockieren.

**Strict Mode (CI):** Wenn die Umgebungsvariable `WGX_STRICT=1` gesetzt ist, führt das Fehlen von `jsonschema` oder fehlende Referenzauflösungskapazitäten zu einem harten Fehler (Exit 1).

- **Konfiguration:** `.wgx/flows.json` (Canonical) oder `contracts/flows.json` (Legacy).
- **Logik:**
  - Daten existieren + Schema fehlt = **FAIL** (Verhindert unvalidierten Datenfluss).
  - Daten existieren + Schema existiert = **VALIDATE** (Fail bei Schema-Verletzung).
  - Daten fehlen = **SKIP** (OK).

### Single Source of Truth (SSOT)

Die referenzierten Schemas **MÜSSEN** entweder:

1. Automatisch aus dem Metarepo gespiegelt werden (`contracts/...`).
2. Explizit als vendored Contracts abgelegt sein (`.wgx/contracts/...`).

### Schema-Referenzen ($ref)

Der Guard prüft "smart", ob Referenzen aufgelöst werden können:

- Schemas *ohne* `$ref` werden immer validiert.
- Schemas *mit* `$ref` erfordern eine Umgebung, die Referenzen auflösen kann (via `RefResolver` oder
  `referencing`-Bibliothek).
- Ist keine Auflösung möglich, bricht der Guard mit einem Fehler ab, statt falsch-positiv zu validieren.

### Integration in CI

Um die strikte Validierung in CI sicherzustellen, muss `python3` und `jsonschema` in der Pipeline installiert sein.
Der Aufruf erfolgt über:

```bash
export WGX_STRICT=1
wgx guard --only data_flow
```

### Verpflichtende Repositories

Folgende Repositories müssen eine `.wgx/flows.json` definieren, um ihre Datenflüsse abzusichern:

- `aussensensor`
- `chronik`
- `heimlern`
- `leitstand`
- `plexer`
- `semantAH`

**Beispiel `.wgx/flows.json` (Array-Format):**

```json
[
  {
    "name": "my_canonical_artifact",
    "schema_path": ".wgx/contracts/my_artifact.v1.schema.json",
    "data_pattern": ["artifacts/output.json"]
  }
]
```

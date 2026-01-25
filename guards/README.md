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

**Abhängigkeiten:** Dieser Guard benötigt `python3` und `jsonschema`.

**Strict Mode (CI):**

- Wenn `WGX_STRICT=1` gesetzt ist, führt das Fehlen von `jsonschema` zu einem harten Fehler (Exit 1).
- Ohne `WGX_STRICT=1` wird bei fehlenden Abhängigkeiten die Prüfung übersprungen (SKIP/OK).

**Referenz-Validierung:**

- Wenn ein Schema `$ref` verwendet, **MUSS** eine Referenzauflösung möglich sein (via `RefResolver`).
  Andernfalls bricht der Guard mit einem Fehler ab (Exit 1), um Scheinsicherheit zu vermeiden –
  unabhängig vom Strict Mode.
- Schemas *ohne* `$ref` werden auch ohne Resolver validiert.

**Konfiguration:**

- **Datei:** `.wgx/flows.json` (Canonical) oder `contracts/flows.json` (Legacy).
- **Logik:**
  - Daten existieren + Schema fehlt = **FAIL** (Verhindert unvalidierten Datenfluss).
  - Daten existieren + Schema existiert = **VALIDATE** (Fail bei Schema-Verletzung).
  - Daten fehlen = **SKIP** (OK).
- **Hinweis:** Repos ohne .wgx/flows.json sind erlaubt, aber ungesichert.

### Log-Format

Der Guard verwendet ein stabiles, maschinenlesbares Log-Format:

- **Check:** `[wgx][guard][data_flow] CHECK flow=<name> files=<count> schema=<path>`
- **Fail:** `[wgx][guard][data_flow] FAIL flow=<name> data=<file> id=<id> error='<msg>'`
- **OK:** `[wgx][guard][data_flow] OK: ...`

### Single Source of Truth (SSOT)

Die referenzierten Schemas **MÜSSEN** entweder:

1. Automatisch aus dem Metarepo gespiegelt werden (`contracts/...`).
2. Explizit als vendored Contracts abgelegt sein (`.wgx/contracts/...`).

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

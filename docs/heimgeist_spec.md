# Heimgeist Contract Alignment for WGX

## Single Source of Truth

The canonical source of truth for Heimgeist Insight Events lives in the Metarepo:
`metarepo/contracts/heimgeist.insight.v1.schema.json`

## WGX Implementation Details

WGX adheres to the metarepo contract with the following specific values:

* **Role**: String (e.g., `wgx.guard`, `archivist`, `heimgeist`) in `meta.role`.
* **ID Format**: `evt-<uuid>`
* **Kind**: `heimgeist.insight`
* **Version**: `1` (number)

## Validation

Validation is performed via `scripts/validate_insight_schema.py`, which enforces
the contract rules strictly using the provided schema.

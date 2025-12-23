# Heimgeist Contract Alignment for WGX

## Single Source of Truth
The canonical source of truth for Heimgeist Insight Events lives in the Metarepo:
`metarepo/contracts/heimgeist.insight.v1.schema.json`

## WGX Implementation Details
WGX adheres to the metarepo contract with the following specific values:

*   **Producer**: `wgx.guard` (in `meta.producer`)
*   **Origin Role**: Mapped to `data.origin.role` (optional, for logical origin)
*   **ID Format**: `evt-<uuid>`
*   **Kind**: `heimgeist.insight`
*   **Version**: `1` (number)

## Validation
Validation is performed via `scripts/validate_insight_schema.py`, which enforces the contract rules strictly using the provided schema.

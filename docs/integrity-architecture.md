# Integrity Architecture

## Release Asset Is Truth

The Release Asset named `summary.json` attached to the `integrity` tag is the
**canonical published artifact**.

- **Repository-local source:** `reports/integrity/summary.json`
- **Generator:** `scripts/generate-integrity-report.sh`
- **Release asset:** `summary.json`
- **Fetch URL:** `https://github.com/<owner>/<repo>/releases/download/integrity/summary.json`

Integrity publication is WGX repository maintenance, not part of the public WGX
CLI. The scheduled/manual workflow generates the report, validates its invariant
fields, publishes the release asset and reads the release back to confirm that
the asset exists. There is no simulated event-publication step and consumers do
not need an event bus; they pull the canonical release asset.

## Status Semantics

The generator derives status from repository-local evidence:

- `MISSING`: no proof artifacts exist under `reports/` apart from the generated
  integrity files.
- `UNCLEAR`: artifacts exist but no `contracts/*.schema.json` claims are found.
- `OK`: both contract claims and artifacts exist.

The workflow accepts additional `WARN` and `FAIL` values for forward
compatibility, but the current generator emits the three values above.
`counts.loop_gaps` and `counts.unclear` remain reserved counters and currently do
not affect status.

## Data Flow Guard & SSOT

The Data Flow Guard separately enforces the binding between generated artifacts
and schemas. `.wgx/flows.json` maps data files to schemas; missing or unresolved
schema evidence fails closed. Integrity publication observes and distributes the
summary of repository evidence, while the Data Flow Guard owns schema/data
validation.

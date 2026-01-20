# Integrity Architecture

## Event is Hint, Release is Truth

The Release Asset named `summary.json` (attached to the `integrity` tag) is the **canonical source of truth**.

* **Repository Path:** `reports/integrity/summary.json` (Source)
* **Release Asset:** `summary.json` (Canonical Artifact)
* **Fetch URL:** `https://github.com/<owner>/<repo>/releases/download/integrity/summary.json`

Events (`integrity.summary.published.v1`) are **best-effort hints** to signal updates.
They may be lost or delayed.
Consumers MUST NOT rely on events for critical state but SHOULD pull the release asset upon receiving an event
(or on a schedule).

## Status Semantics (WGX)

This repository uses `reports/integrity/summary.json` as the source report that is published as
the `summary.json` release asset.

Important distinction:

* If the **release asset is missing**, consumers simply have **no data** for that repository yet.
* If the **release asset exists**, the consumer should display the **status value contained in `summary.json`**.

Current generator logic (see `modules/integrity.bash`):

* `MISSING`: no proof artifacts available yet (currently: no files under `reports/` except `summary.json`).
* `UNCLEAR`: no contract claims available yet (currently: no `contracts/*.schema.json` found), but artifacts exist.
* `OK`: both claims and artifacts exist.

Notes:

* The fields `counts.loop_gaps` and `counts.unclear` are placeholders at the moment and do not influence the status.
* The workflow allows additional status values (`WARN`, `FAIL`) for forward compatibility.

# Integrity Architecture

## Event is Hint, Release is Truth

The Release Asset named `summary.json` (attached to the `integrity` tag) is the **canonical source of truth**.

*   **Repository Path:** `reports/integrity/summary.json` (Source)
*   **Release Asset:** `summary.json` (Canonical Artifact)
*   **Fetch URL:** `https://github.com/<owner>/<repo>/releases/download/integrity/summary.json`

Events (`integrity.summary.published.v1`) are **best-effort hints** to signal updates.
They may be lost or delayed.
Consumers MUST NOT rely on events for critical state but SHOULD pull the release asset upon receiving an event
(or on a schedule).

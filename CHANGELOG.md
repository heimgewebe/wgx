# Changelog

## Unreleased

- **BREAKING**: Entfernt `log_info` (deprecated) aus `lib/core.bash`. Bitte `info` nutzen.
- **Fix**: `wgx send` bricht nun deterministisch ab, wenn Guards fehlschlagen (außer bei explizitem Override).
- **Test**: `guard insights` Tests mocken nun korrekt die Repository-Identität für `contracts_ownership`.
- **Change**: Upstream semantics clarified in `audit.git`: `configured` added; `exists_locally` denotes ref presence.

## 2.0.0 (YYYY-MM-DD)

- Initiale modulare Struktur; Shell & Docs CI; UV-Frozen-Sync in CI; guard-Checks; Runbook-Stub.

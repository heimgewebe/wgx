# WGX-Fähigkeiten und Systemgrenzen

Die fail-closed Inventur liegt in
[`operator-ecosystem-capabilities.v1.json`](operator-ecosystem-capabilities.v1.json).
Historische Consumerbelege bleiben getrennt in
`operator-ecosystem-source-evidence.v1.json`; sie sind kein Claim über den
aktuellen Fleet-Zustand.

## Aktive Rolle

WGX ist ein minimaler Repository-Verifikationsrunner mit der operativen ABI
`validate`, `tasks` und `task`. Der kanonische Verification-Vertrag und die
reusable Guard-/Smoke-/Quick-/Full-Policy liegen in Metarepo. WGX konsumiert
diese Policy für sein eigenes Repository über
`.github/workflows/repository-verification.yml`.

Ein Live-Scan der heimgewebe-Default-Branches am 8. August 2026 fand keinen
verbleibenden externen Caller der früheren WGX-reusable Guard-/Smoke-URLs. Die
beiden WGX-Shims wurden deshalb entfernt. Die historischen 2026-07-Belege
bleiben unverändert erhalten.

## Verbleibende Repository-Fähigkeiten

| Fähigkeit | Rolle |
| --- | --- |
| Metrics-Contract-Kompatibilität | WGX-interne Contract-Fixture, keine Fleet-Messung |
| Cross-Repository-Kompatibilitätsmatrix | WGX-eigener On-Demand-Kompatibilitätstest |
| `.wgx-tools`-Guard | repository-lokale Wartung |
| Integrity-Publikation | repository-lokaler Report/Release-Pfad |
| Versions-Release | repository-lokale Veröffentlichung |
| WGX-Profil-Starter | Übergangsmaterial ohne behauptete Consumer |

Diese Wartungsflächen sind keine zusätzlichen CLI-Commands und begründen keine
Fleet-, Task-, Host- oder Deploy-Autorität.

## Autoritätsgrenze

- Metarepo besitzt Fleet-Vertrag, Templates und reusable Verification-Policy.
- Ziel-Repository-CI und GitHub besitzen Check-/Merge-Schlussfolgerungen.
- Bureau besitzt Taskkoordination.
- Grabowski besitzt typisierte Git-/Worktree-/Prozess-/Deploy-Effekte.
- RepoGround liefert repository-übergreifenden Read-only-Kontext.

`wgx task` führt ausschließlich repository-deklarierte Befehle aus und sandboxed
deren Hosteffekte nicht. WGX selbst erzeugt dabei keine impliziten Audit-,
Event-, Git- oder Forge-Nebenwirkungen.

## Beweisführung

`scripts/validate_operator_capabilities.py` prüft unter anderem:

- exakte Capability-ID/Kategorie-/Surface-Bindungen;
- die Minimal-Command-Inventur;
- Authority-Owner und source-linked Grenzen;
- kryptografisch eingecheckte historische WGX-Source-Evidence;
- Push-/PR-Triggerabdeckung der aktiven Authority- und Validatorflächen.

Damit kann historische Nutzung erhalten bleiben, ohne alte Interfaces künstlich
am Leben zu halten.

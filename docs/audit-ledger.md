# Audit Ledger

WGX besitzt nur noch die **read-only Verifikation** einer bestehenden
JSONL-Audit-Kette. `wgx audit verify` prüft `prev_hash → hash` für jeden Eintrag
in `.wgx/audit/ledger.jsonl` und verändert dabei weder Ledger noch Git- oder
Remotezustand.

Standardmäßig wird eine beschädigte Kette als Warnung gemeldet. Mit
`AUDIT_VERIFY_STRICT=1` oder `wgx audit verify --strict` führt eine beschädigte
Kette zu einem Fehlerstatus. Ein fehlendes Python wird im Strict-Modus ebenfalls
fail-closed behandelt.

WGX erzeugt oder erweitert das Ledger nicht mehr selbst. Falls ein Repository
oder ein externer Operator ein solches Ledger bereitstellt, kann WGX es prüfen.
`docs/audit-ledger.sample.jsonl` bleibt als Formatbeispiel erhalten.

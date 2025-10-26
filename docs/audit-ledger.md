# Audit Ledger

`lib/audit.bash` stellt mit `audit::log` und `audit::verify` eine
JSONL-basierte Audit-Kette bereit. Jeder Eintrag enthält UTC-Zeitstempel,
Git-Commit, das Ereignis und optionales Payload-JSON; ein SHA256-Hash schützt
die Verkettung (`prev_hash` → `hash`). Der Befehl `wgx audit verify`
überprüft die Kette und gibt standardmäßig nur Warnungen aus. Mit
`AUDIT_VERIFY_STRICT=1` oder `wgx audit verify --strict` wird ein Fehlerstatus
ausgelöst, wenn die Hash-Kette unterbrochen ist.

Das produktive Ledger lebt unter `.wgx/audit/ledger.jsonl` und wird
automatisch erweitert. Da es sich bei jedem Lauf ändert, ist die Datei von
Git ausgeschlossen. Für Dokumentationszwecke gibt es stattdessen
`docs/audit-ledger.sample.jsonl`, das den Aufbau exemplarisch zeigt.

# WGX – Repository-Verifikationsadapter

Status: aktuelle Rollenbeschreibung für WGX v1.

WGX stellt eine gemeinsame CLI, Profilparser, statische Guard-Invarianten und
wiederverwendbare GitHub-Actions-Adapter bereit. Ein Ziel-Repository deklariert
seine eigenen Frontdoors in `.wgx/profile.yml`; WGX kann diese lokal oder in CI
aufrufen und strukturiert ausgeben.

## Zuständigkeit

WGX besitzt:

- das Profilformat und dessen Parserkompatibilität;
- querschnittliche, statische Repository-Checks;
- die wiederverwendbaren Guard-, Smoke- und Kompatibilitätsadapter;
- eine Metrics-Contract-Fixture für den gemeinsamen Metarepo-Vertrag.

WGX besitzt nicht:

- Task-Auswahl, Reihenfolge, Claims oder Abschlusswahrheit – das gehört Bureau;
- Grabowski-Autorität für Deployments, Services oder Prozesse;
- generische repository-übergreifende Host-Autorität;
- CI-Ergebnisse anderer Repositories – deren native CI und GitHub bleiben die
  Quelle;
- Fleet-Distribution – das gehört Metarepo.

WGX enthält ausdrücklich repository-bezogene Entwickler-Mutationen wie
`clean`, `reload`, `heal` und `send`. `wgx task` und `wgx run` führen einen vom
aktuellen Repository deklarierten Shell-Befehl aus; WGX begrenzt dessen
mögliche Host-Effekte nicht technisch. Diese Flächen sind weder Task-Queue noch
Deploy-Freigabe und übertragen WGX keine Bureau- oder Grabowski-Autorität.

## Beibehaltene gemeinsame Flächen

- `.github/workflows/wgx-guard.yml` routet zu repository-eigenen Guard- oder
  Smoke-Frontdoors.
- `.github/workflows/wgx-smoke.yml` verlangt eine deklarierte Smoke-Frontdoor.
- `modules/guard.bash` und `guards/` liefern statische Fleet-Invarianten.
- `.github/workflows/compat-on-demand.yml` prüft WGX gegen mehrere reale
  Ziel-Repositories.
- `scripts/wgx-metrics-snapshot.sh` erzeugt nur eine Contract-Fixture; die
  Ausgabe ist keine Live-Host- oder Deployment-Evidenz.

Die vollständige, maschinenvalidierte Consumer- und Ersatzinventur steht in
[`operator-ecosystem-capabilities.v1.json`](operator-ecosystem-capabilities.v1.json).

## Repository-native Frontdoors

WGX ersetzt keine fachliche CI. Ein Python-Repository kann beispielsweise
`uv run pytest`, ein Rust-Repository `cargo test` und ein Dokumentations-Repo
seinen eigenen Linter deklarieren. Der WGX-Adapter vereinheitlicht lediglich
den Aufruf und die Profilkompatibilität.

Metarepo besitzt die Fleet-Distribution. Die WGX-eigenen Starterprofile
bleiben jedoch erhalten, bis Metarepo einen nachweislich ausführbaren,
task-kompatiblen Ersatz samt CI-Abdeckung bietet. Der aktuell geprüfte
Metarepo-Profilkandidat enthält keine WGX-Tasks und ist deshalb kein Ersatz.

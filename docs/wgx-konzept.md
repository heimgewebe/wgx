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
- Deploy-, Service-, Prozess-, Git- oder generische Host-Mutation – das gehört
  Grabowski beziehungsweise einer explizit autorisierten Repository-Pipeline;
- CI-Ergebnisse anderer Repositories – deren native CI und GitHub bleiben die
  Quelle;
- Fleet-Templates oder deren Distribution – das gehört Metarepo.

`wgx task` und `wgx run` sind deshalb Repository-Adapter. Sie führen nur einen
vom aktuellen Repository deklarierten Befehl aus. Sie sind keine Task-Queue und
keine Deploy-Freigabe.

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

Fleet-Templates werden aus
[`heimgewebe/metarepo/templates`](https://github.com/heimgewebe/metarepo/tree/main/templates)
verteilt und dort validiert. WGX hält keine zweite Starterkopie.

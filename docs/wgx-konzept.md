# WGX – portabler Repository-Verifikationsrunner

Status: Boundary-v2-Rollenbeschreibung nach Metarepo-PR #687.

WGX ist nicht mehr Eigentümer des Fleet-Verifikationsvertrags. Der kanonische
Contract, die ausführbaren Starterprofile und die reusable CI-Policy liegen in
Metarepo, revisionsgebunden ab `31dbecc6c7b966faa73ad3dceb0ded7329187f36`. WGX bleibt während des Cutovers der
portable Kompatibilitätsrunner für bestehende `.wgx/profile.yml`-Consumer.

## WGX besitzt

- Parserkompatibilität für bestehende WGX-v1-Profile;
- Auflistung deklarierter Repository-Tasks;
- explizite Ausführung genau eines deklarierten Tasks;
- `quick`/`full`-Validierung mit deterministischen, redigierten JSON-Receipts;
- die alten `wgx-guard`/`wgx-smoke`-URLs ausschließlich als gepinnte
  Kompatibilitätsshims.

## Metarepo besitzt

- `repository-verification.v2.schema.json`;
- kanonische ausführbare Starterprofile;
- die gemeinsame Guard-/Smoke-/Quick-/Full-Policy;
- `reusable-repo-verify.yml` als wiederverwendbaren GitHub-Actions-Frontdoor.

Die WGX-Shims delegieren exakt an Metarepo `31dbecc6c7b966faa73ad3dceb0ded7329187f36`. Dadurch bleiben bestehende
Caller funktionsfähig, ohne zwei Policy-Eigentümer zu erzeugen.

## WGX besitzt ausdrücklich nicht

- Fleet- oder Contract-Wahrheit;
- Task-Auswahl, Reihenfolge, Claims oder Abschlusswahrheit – Bureau;
- Deployment-, Service-, Prozess-, Worktree- oder allgemeine Git-Autorität – Grabowski/GitHub;
- Event- oder Ledger-Wahrheit – Chronik/Plexer;
- Systemrollen und langfristige Beziehungen – Systemkatalog;
- repository-übergreifenden Codekontext – RepoGround.

## Übergangsflächen

Historische Entwicklerbefehle wie `clean`, `reload`, `heal`, `send`, `routine`,
`version`, `integrity` und `vibe` sind noch nicht automatisch Teil des
langfristigen Runner-Kerns. Sie bleiben nur so lange erhalten, wie Consumer oder
Migrationsbelege ihre Entfernung noch nicht erlauben. Reine Placeholder
`config`, `hooks`, `release`, `setup` und `start` wurden bereits entfernt.

`wgx task` erzeugt selbst keine Audit- oder HausKI-/Plexer-Nebenwirkungen mehr;
beobachtbare Effekte stammen ausschließlich aus dem vom Repository explizit
deklarierten Task.

## Nächster Schnitt

Nach revisionsgebundener Migration der direkten WGX-Caller kann der
Implementierungsname unabhängig vom Contract werden. Erst dann wird über die
Umbenennung von `wgx` zu einem beschreibenden Runnernamen wie `repoverify` und
über einen implementationunabhängigen Profilpfad entschieden.

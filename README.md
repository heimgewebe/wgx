# wgx – minimaler Repository-Verifikationsrunner

WGX ist ein kleiner Kompatibilitätsrunner für bestehende `.wgx/profile.yml`-Profile.
Die öffentliche CLI besteht absichtlich nur aus drei Frontdoors:

- `wgx validate` – Profil prüfen; `--profile quick|full` führt die im Profil deklarierten
  Validierungstasks mit Timeout- und Receipt-Vertrag aus.
- `wgx tasks` – deklarierte Tasks maschinenlesbar oder menschenlesbar auflisten.
- `wgx task <name>` – genau einen repository-deklarierten Task ausführen.

`wgx --help`, `wgx --list` und `wgx --version` sind Dispatcher-Metafunktionen und keine zusätzlichen operativen Commands.

## Schnellstart

```bash
mkdir -p "$HOME/.local/bin"
ln -sf "$PWD/cli/wgx" "$HOME/.local/bin/wgx"
export PATH="$HOME/.local/bin:$PATH"

wgx validate
wgx tasks
wgx task smoke
```

Ein Ziel-Repository versioniert sein eigenes `.wgx/profile.yml`. Beispiel:

```yaml
wgx:
  apiVersion: v1
  requiredWgx: "^2.0"
  validate:
    quick: [lint, smoke]
    full: [lint, test, smoke]
  tasks:
    lint: "ruff check ."
    test: "pytest -q"
    smoke: "python -m myapp --help"
```

Tasknamen wie `guard`, `lint`, `smoke` oder `test` gehören dem Ziel-Repository. Sie sind **keine WGX-Subcommands**.
WGX führt nur aus, was das Profil ausdrücklich deklariert.

## Systemgrenze

WGX besitzt:

- Parserkompatibilität für WGX-v1-Profile;
- Taskauflistung und explizite Taskausführung;
- `quick`/`full`-Validierung mit deterministischen, redigierten Receipts;
- die historischen `wgx-guard.yml`/`wgx-smoke.yml`-URLs als gepinnte Kompatibilitätsshims zu Metarepo.

WGX besitzt nicht:

- Fleet- oder Policy-Wahrheit – Metarepo;
- Taskkoordination – Bureau;
- Git-, Worktree-, Prozess- oder Deploy-Autorität – Grabowski/GitHub;
- repository-übergreifenden Codekontext – RepoGround.

Die öffentliche CLI erzeugt keine eigenen Git-, Forge-, Audit-, Cleanup- oder Repository-Wartungseffekte.
`wgx task` kann allerdings jeden Effekt haben, den das **Repository selbst** in seinem Task deklariert;
WGX sandboxed diesen Befehl nicht.

Details: [docs/wgx-konzept.md](docs/wgx-konzept.md).

## Repository-interne Wartung

WGX hat einige **eigene** CI-/Wartungspfade, die nicht Teil der öffentlichen Command-ABI sind:

- `.github/workflows/wgx-integrity.yml` + `scripts/generate-integrity-report.sh` erzeugen und veröffentlichen den WGX-Integritätsreport.
- `.github/workflows/metrics.yml` + `scripts/wgx-metrics-snapshot.sh` erzeugen eine lokale Metrics-Contract-Fixture.
- `.github/workflows/wgx-tools-guard.yml` prüft eingecheckte `.wgx-tools`-Module.
- Release- und Kompatibilitätsworkflows warten dieses Repository selbst.

Diese Pfade sind kein Beleg für zusätzliche WGX-Subcommands oder Fleet-Autorität.

## Entwicklung

Lokale Shell-/Test-Gates entsprechen den GitHub-Actions-Baselines:

```bash
bash -n $(git ls-files '*.sh' '*.bash')
shfmt -d $(git ls-files '*.sh' '*.bash')
shellcheck -x -S style $(git ls-files '*.sh' '*.bash')
bats -r tests
```

Python-Regressionstests:

```bash
python3 -m unittest discover -s tests -p 'test_*.py'
```

Metrics-Contract-Kompatibilität:

```bash
just wgx-metrics snapshot --json --output metrics.json
just contracts validate
```

## Dokumentation

- [Quickstart](docs/quickstart.md)
- [Runbook](docs/Runbook.md)
- [Profil-Spezifikation](docs/profile-v1-spec.md)
- [CLI-Referenz](docs/cli.md)
- [Operator-/Capability-Grenzen](docs/operator-ecosystem-capabilities.md)

Historische Konzept- und Evidence-Dateien dokumentieren frühere Zustände und sind keine aktuelle CLI-Spezifikation.

## Lizenz

MIT, siehe [LICENSE](LICENSE). Das Repository ist öffentlich sichtbar; der Projektfokus liegt auf der heimgewebe-Ökosphäre.

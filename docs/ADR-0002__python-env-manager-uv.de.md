# ADR-0002: Python-Umgebungen mit uv verwalten

## Status

Akzeptiert

## Kontext

- wgx bedient heterogene Zielumgebungen (Termux, Codespaces, klassische Linux-Hosts).
- Bisher wurden Python-Setups mit einer Kombination aus `pyenv`, `pip`, `pip-tools`, `venv` und `pipx` orchestriert.
- Die Vielzahl an Tools erzeugt lange Installationszeiten und erhöht den Pflegeaufwand (Updates, Caches, Pfade).
- Projekte benötigen reproduzierbare Python-Installationen inklusive Lockfiles für CI/CD.

## Entscheidung

Wir setzen [uv](https://docs.astral.sh/uv/) als standardmäßigen Python-Manager für wgx ein. uv liefert:

- Verwaltung passender Python-Versionen (on demand, ohne separates `pyenv`).
- Projektverwaltung inklusive `pyproject.toml`, Locking (`uv.lock`) und deterministischem `uv sync`.
- Tool-Installation via `uv tool install`, womit `pipx` entfällt.
- Sehr schnelle Installationszeiten dank nativer Builds und globalem Cache.

wgx bietet dafür Wrapper-Kommandos (`wgx py up`, `wgx py sync`, `wgx py run`, `wgx tool add`).
Repository-Profile können per `.wgx/profile.yml` alternative Manager deklarieren, fallen aber
standardmäßig auf uv zurück.

## Konsequenzen

- Reproduzierbare Umgebungen: `uv.lock` ist verpflichtender Bestandteil im Versionskontrollsystem.
- CI-Pipelines installieren uv einmalig und verwenden `uv sync --frozen` plus `uv run` für Testläufe.
- Entwickler:innen benötigen nur ein Binary; Startzeiten in Devcontainern/Termux sinken erheblich.
- Bestehende Workflows mit `requirements.txt` können schrittweise migriert werden (`uv pip sync`, `uv pip compile`).

## Risiken / Mitigations

- **Disziplin beim Lockfile**: Änderungen müssen via `wgx py sync` und committedem `uv.lock` erfolgen.
  wgx-Contracts prüfen dies.
- **Koexistenz mit Legacy-Tools**: uv überschreibt keine Fremdinstallationen ohne `--force`.
  Dokumentation weist auf uv als Owner hin.
- **Schulungsbedarf**: Kurzreferenzen in README/Runbook erläutern neue Kommandos und Migrationspfade.

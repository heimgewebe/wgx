# Beitrag zu wgx

**Rahmen:** wgx ist ein Bash-zentriertes Hilfstool für Linux/macOS, Termux, WSL und Codespaces.
Halte Änderungen klein, portabel und mit Tests abgesichert.

## Grundregeln

- **Sprache:** Dokumentation und Hilfetexte auf Deutsch verfassen; Commit-Nachrichten vorzugsweise auf Englisch für Tool-Kompatibilität.
- **Portabilität:** Termux/WSL/Codespaces nicht brechen. Keine GNU-only-Flags ohne Schutz.
- **Sicherheit:** Skripte aktivieren `set -e`/`set -u` und versuchen `pipefail`; wenn die Shell es nicht
  unterstützt, wird ohne weitergelaufen – aber niemals mit stillen Fehlern.
- **Quoting:** Die [Leitlinie: Shell-Quoting](docs/Leitlinie.Quoting.de.md) ist
  verbindlich, Ausnahmen müssen dokumentiert und begründet werden.
- **Hilfe:** Jeder Befehl muss `-h|--help` unterstützen.

## Entwicklungsumgebung

- Nutze den Dev-Container. Er enthält `shellcheck`, `shfmt`, `bats`.
- Lokale Entwicklung außerhalb des Containers: Werkzeuge manuell installieren.

## Lint & Tests

- Format-Check: `shfmt -d`.
- Lint: `shellcheck -f gcc`.
- Tests: Bats-Tests unter `tests/` ablegen und mit `bats -r tests` ausführen.
- Python-Tests: `python3 -m unittest discover -s tests` vom Root ausführen.
- Pytest: Einige Tests (z. B. `tests/test_insights_guard.py`) nutzen `pytest`.

## Commits & PRs

- Konventioneller Prefix: `feat|fix|docs|refactor|chore(wgx:subcmd): ...`
- PRs fokussiert halten; „Wie getestet“ angeben.

## Definition of Done

- CI grün (`bash_lint_test`).
- Für neue/geänderte Befehle: Hilfetext + Bats-Test vorhanden.

## Lokale Checks (Spiegel der CI)

```bash
bash -n $(git ls-files "*.sh" "*.bash")
shfmt -d $(git ls-files "*.sh" "*.bash")
shellcheck -S style $(git ls-files "*.sh" "*.bash")
bats -r tests
python3 -m unittest discover -s tests
markdownlint $(git ls-files "*.md" "*.mdx")
vale .
```

> Tipp: `pre-commit install` setzt das als Hook vor jeden Commit.

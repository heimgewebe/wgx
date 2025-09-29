# Beitrag zu wgx

**Rahmen:** wgx ist ein Bash-zentriertes Hilfstool für Linux/macOS, Termux, WSL und Codespaces.
Halte Änderungen klein, portabel und mit Tests abgesichert.

## Grundregeln

- **Sprache:** Dokumentation und Hilfetexte auf Deutsch verfassen; Commit-Nachrichten vorzugsweise auf Englisch für Tool-Kompatibilität.
- **Portabilität:** Termux/WSL/Codespaces nicht brechen. Keine GNU-only-Flags ohne Schutz.
- **Sicherheit:** In allen Skripten `set -euo pipefail`; keine stillen Fehler.
- **Hilfe:** Jeder Befehl muss `-h|--help` unterstützen.

## Entwicklungsumgebung

- Nutze den Dev-Container. Er enthält `shellcheck`, `shfmt`, `bats`.
- Lokale Entwicklung außerhalb des Containers: Werkzeuge manuell installieren.

## Lint & Tests

- Format-Check: `shfmt -d`.
- Lint: `shellcheck -f gcc`.
- Tests: Bats-Tests unter `tests/` ablegen und mit `bats -r tests` ausführen.

## Commits & PRs

- Konventioneller Prefix: `feat|fix|docs|refactor|chore(wgx:subcmd): ...`
- PRs fokussiert halten; „Wie getestet“ angeben.

## Definition of Done

- CI grün (`bash_lint_test`).
- Für neue/geänderte Befehle: Hilfetext + Bats-Test vorhanden.

# Contributing to wgx

**Scope:** wgx is a Bash-first helper toolkit targeting Linux/macOS, Termux, WSL and Codespaces.
Keep changes small, portable and covered by tests.

## Ground rules
- **Language:** English for code, docs and commit messages (helps tooling/Copilot).
- **Portability:** Do not break Termux/WSL/Codespaces. No GNU-only flags unless guarded.
- **Safety:** `set -euo pipefail` in all scripts; no silent failures.
- **Help:** Every command must support `-h|--help`.

## Dev setup
- Use the Dev Container. It ships `shellcheck`, `shfmt`, `bats`.
- Local dev outside container: install those tools manually.

## Lint & tests
- Format check: `shfmt -d`.
- Lint: `shellcheck -f gcc`.
- Tests: place Bats tests under `tests/` and run `bats -r tests`.

## Commits & PRs
- Conventional-ish prefix: `feat|fix|docs|refactor|chore(wgx:subcmd): ...`
- Keep PRs focused; include “How tested”.

## Definition of done
- CI green (bash_lint_test).
- For new/changed commands: help text + Bats test exist.

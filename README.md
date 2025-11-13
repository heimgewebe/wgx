# wgx – Heimgewebe Fleet-Orchestrator (Rust-Stub)

Dieses Repository enthält die Rust-Variante von **wgx**, dem Fleet-Orchestrator
für das Heimgewebe. Aktuell ist dies ein **minimaler Stub**, der vor allem
dafür sorgt, dass:

- `cargo install --git https://github.com/heimgewebe/wgx` erfolgreich ist und
- CI-Jobs, die `wgx` erwarten, ein lauffähiges Binary vorfinden.

## Status

- CLI-Stub mit:
  - `wgx` / `wgx noop` → macht nichts, Exit-Code 0
  - `wgx version` → zeigt Paketversion
- **Noch keine** Portierung der bestehenden Shell-/WGX-Logik (doctor, smoke, metrics …).

## Installation

```bash
cargo install --git https://github.com/heimgewebe/wgx
```

Danach steht `wgx` im `~/.cargo/bin` zur Verfügung.

> Hinweis: In CI-Workflows, die `wgx` nur ausführen, um Existenz/Version zu prüfen,
> ist dieser Stub ausreichend. Für reale Fleet-Orchestrierung müssen die
> bisherigen Funktionen schrittweise nach Rust portiert werden.

## Nächste Schritte (Roadmap)

1. Subcommands modellieren (`doctor`, `smoke`, `metrics`, `run`, …).
2. Bestehende Shell-Implementierungen schrittweise in Rust abbilden.
3. Release-Workflow ergänzen und Tags (`v0.1.0` etc.) für `cargo install --tag …` nutzen.

Lizenz: MIT (siehe `Cargo.toml`).

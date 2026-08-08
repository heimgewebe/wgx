# WGX Runbook (Kurzfassung)

## Runtime dependencies

WGX uses Bash as the CLI core and Python 3 with `pyyaml` to parse
`.wgx/profile.yml`. CI and the devcontainer install these dependencies.

On local machines you should ensure at least:

- Bash ≥ 4
- Git and common coreutils (`sed`, `awk`, `grep`, `find`, …)
- Python 3 with `pyyaml`

Examples:

- Debian/Ubuntu: `sudo apt install python3-yaml`
- macOS (Homebrew): `brew install python && pip3 install pyyaml`

## Erstlauf

1. `wgx doctor` prüft die lokale Umgebung.
2. `wgx validate` prüft den eingecheckten Repository-Vertrag.
3. `wgx tasks` zeigt die deklarierten Frontdoors.
4. `wgx task smoke` führt den repository-eigenen Smoke-Task aus.

WGX erstellt keine Profile, Branches, Commits oder Pull Requests mehr. Diese
Zuständigkeiten liegen beim Repository, bei Metarepo bzw. beim autorisierten
Operator.

## Python (uv)

- `wgx py up` / `wgx py sync --frozen` / `wgx py run <cmd>`

## Guard-Checks (Mindest-Standards)

- `uv.lock` committed
- CI mit shellcheck/shfmt/bats
- Markdownlint + Vale
- repository-eigenes `.wgx/profile.yml` oder `.wgx/profile.example.yml`
- Guard-Env: `WGX_GUARD_MAX_BYTES` (Bigfile-Schwelle), `WGX_GUARD_CHECKLIST_STRICT` (Warnmodus)

### Guard-Konfiguration

- `WGX_GUARD_MAX_BYTES` setzt die Bigfile-Schwelle in Bytes (Default: `1048576`).
- `WGX_GUARD_CHECKLIST_STRICT=0` wandelt Checklisten-Fehler in Warnungen um.

## Troubleshooting

- `wgx selftest` starten; Logs unter `~/.local/state/wgx/`.

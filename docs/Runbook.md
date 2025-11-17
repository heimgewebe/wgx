# WGX Runbook (Kurzfassung)

## Runtime dependencies

WGX v1 uses Bash as the CLI core, but deliberately relies on Python 3 with the `pyyaml` module to parse `.wgx/profile.yml`.
In CI and in the devcontainer these packages are installed automatically (for Debian/Ubuntu via the `python3-yaml` package).

On local machines you should ensure at least:

- Bash ≥ 4
- Git and common coreutils (`sed`, `awk`, `grep`, `find`, …)
- Python 3 with `pyyaml`

Examples:

- Debian/Ubuntu: `sudo apt install python3-yaml`
- macOS (Homebrew): `brew install python && pip3 install pyyaml`

## Erstlauf
1. `wgx doctor` ausführen → prüft Umgebung (bash, git, shellcheck, shfmt, bats).
2. `wgx init` → legt `~/.config/wgx/config` an (aus `etc/config.example`).
3. `wgx send "msg"` → Commit & Push Helper.

## Python (uv)
* `wgx py up` / `wgx py sync --frozen` / `wgx py run <cmd>`

## Guard-Checks (Mindest-Standards)
* `uv.lock` committed
* CI mit shellcheck/shfmt/bats
* Markdownlint + Vale
* templates/profile.template.yml vorhanden
* Guard-Env: `WGX_GUARD_MAX_BYTES` (Bigfile-Schwelle), `WGX_GUARD_CHECKLIST_STRICT` (Warnmodus)

### Guard-Konfiguration
* `WGX_GUARD_MAX_BYTES` setzt die Bigfile-Schwelle in Bytes (Default: `1048576`).
* `WGX_GUARD_CHECKLIST_STRICT=0` wandelt Checklisten-Fehler in Warnungen um.

## Troubleshooting
* `wgx selftest` starten; Logs unter `~/.local/state/wgx/`.

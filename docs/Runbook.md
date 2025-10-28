# WGX Runbook (Kurzfassung)

## Erstlauf
1. `wgx doctor` ausführen → prüft Umgebung (bash, git, shellcheck, shfmt, bats).
2. `wgx init` → legt `~/.config/wgx/config` an (aus `etc/config.example`).
3. `wgx sync` → holt Updates; `wgx send "msg"` → Commit & Push Helper.

## Python (uv)
* `wgx py up` / `wgx py sync --frozen` / `wgx py run <cmd>`

## Guard-Checks (Mindest-Standards)
* `uv.lock` committed
* CI mit shellcheck/shfmt/bats
* Markdownlint + Vale
* templates/profile.template.yml vorhanden
* Guard-Env: `WGX_GUARD_MAX_BYTES` (Bigfile-Schwelle), `WGX_GUARD_CHECKLIST_STRICT` (Warnmodus)

## Troubleshooting
* `wgx selftest` starten; Logs unter `~/.local/state/wgx/`.

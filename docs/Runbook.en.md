# Runbook: wgx CLI

> German version: [Runbook.de.md](Runbook.de.md)

## Quick Links
- Validate contract compatibility: `wgx validate`
- Run linting (also used by Git hooks): `wgx lint`
- Diagnose environment issues: `wgx doctor`

## Common Issues and Fixes

### `profile.yml` cannot be found
- Confirm that you are in the correct working directory (usually the project root).
- Use `wgx profile list` to ensure that the profile can be discovered.
- If multiple profiles exist, set `WGX_PROFILE_PATH` explicitly.

### `wgx` fails with Python errors
- Activate the Python environment (`.venv/bin/activate` or `pipx run`).
- Install missing dependencies with `pip install -r requirements.txt`.
- For global installations, confirm that the version matches the central contract.

### Git hooks block commits
- Run `wgx lint` manually to inspect the reported issues.
- If the hook is outdated, update the repository and run `wgx setup` again.

## Termux Tips
- Update the package repository first with `pkg update`.
- Install the essentials: `pkg install jq git python`.
- Add `pipx` for isolated CLI usage (`pip install pipx && pipx ensurepath`).
- Grant storage access to the project directory via `termux-setup-storage`.

## VS Code (Remote / Dev Containers) Tips
- Mark `profile.yml` as a workspace file so changes are synced.
- Add `wgx` tasks as VS Code tasks for one-click execution.
- Persist the `~/.wgx` configuration when using Dev Containers, for example:

```json
{
  "mounts": [
    "source=${localEnv:HOME}/.wgx,target=/home/vscode/.wgx,type=bind,consistency=cached"
  ]
}
```

# Runbook: wgx CLI (English Edition)

> Deutsche Version: [Runbook.de.md](Runbook.de.md)

## Quick Links

- Validate CLI contract compliance: `wgx validate`
- Run linting (also used by Git hooks): `wgx lint`
- Diagnose the local environment: `wgx doctor`

## Common issues and remedies

### `profile.yml` cannot be located

- Make sure you execute the command from the project root (or the directory that contains the profile).
- Use `wgx profile list` to verify that the profile is discoverable.
- When multiple profiles exist, set an explicit path via `WGX_PROFILE_PATH`.

### `wgx` aborts with Python related errors

- Execute `wgx py up` so that uv installs the Python version that is declared in the profile.
- Follow up with `wgx py sync` to install dependencies based on `uv.lock`.
- Repositories without a lockfile can migrate by running `uv pip sync requirements.txt` and establishing `wgx py sync` afterwards.
- Global or system wide installs should be checked for contract compatibility.

### `sudo apt-get update -y` fails with “unsigned/403 responses”

- This often happens in locked down networks or after adding external repositories. Confirm that the system clock is correct and whether a proxy/TLS interceptor is used (`echo $https_proxy`).
- Remove cached package lists before retrying:

  ```bash
  sudo rm -rf /var/lib/apt/lists/*
  sudo apt-get clean
  sudo apt-get update
  ```

- Ensure that any additional repository ships the proper signing key (prefer the keyring workflow over `apt-key`):

  ```bash
  # Example: adding the Docker repository on Ubuntu Jammy
  sudo install -d -m 0755 /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  echo "deb [signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu jammy stable" | sudo tee /etc/apt/sources.list.d/docker.list
  sudo apt-get update
  # Adjust the repository URL, distribution ("jammy") and components ("stable") to your target platform.
  ```

- If the problem persists, inspect `/var/log/apt/term.log`. HTTP 403 responses are often resolved by switching mirrors or by pruning stale entries in `/etc/apt/sources.list.d/`.

### Git hooks block commits

- Run `wgx lint` manually to see the failures.
- If a hook is outdated, update the repository and re-run `wgx setup`.

## Tips for Termux

- Update the Termux package registry (`pkg update`) before installing Python/Node.
- Install core dependencies: `pkg install jq git python`.
- Install `uv` as a single binary under `$HOME/.local/bin`:

  ```bash
  curl -LsSf https://astral.sh/uv/install.sh | sh
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.profile
  . ~/.profile
  ```

- Afterwards run `wgx py up` – uv manages Python versions and virtual environments without additional tools.
- Grant storage access to the project directory (`termux-setup-storage`).

## Migration guide: from `requirements.txt` to uv

1. Synchronise the existing dependencies:

   ```bash
   uv pip sync requirements.txt
   ```

2. Define project metadata in `pyproject.toml` if it does not exist yet.
3. Create a lockfile and add it to version control:

   ```bash
   uv lock
   git add uv.lock
   ```

4. Document `wgx py sync` for CI and local developers; in case of failures fall back to `uv sync --frozen`.
5. Optionally export compatibility artefacts (`uv pip compile --output-file requirements.txt`).

## CI with uv (quick reference)

- Install uv (e.g. `curl -LsSf https://astral.sh/uv/install.sh | sh`).
- Cache the global uv cache: `~/.cache/uv` with a key derived from the uv version (`uv --version | awk '{print $2}'`) plus `pyproject.toml` and `uv.lock`.
- Install dependencies strictly via `uv sync --frozen`.
- Execute tests with `uv run …` (e.g. `uv run pytest -q`).

## Tips for VS Code (Remote / Dev Containers)

- Mark `profile.yml` as a workspace file so that changes sync correctly.
- Expose `wgx` tasks as VS Code tasks to make the commands discoverable from the UI.
- Persist the `~/.wgx` configuration when using Dev Containers, e.g.:

```json
{
  "mounts": [
    "source=${localEnv:HOME}/.wgx,target=/home/vscode/.wgx,type=bind,consistency=cached"
  ]
}
```

- Use `.devcontainer/setup.sh ensure-uv` to guarantee that uv is available (including PATH adjustments) after the container starts.

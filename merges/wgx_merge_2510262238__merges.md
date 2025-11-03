### 📄 merges/wgx_merge_2510262237__.devcontainer.md

**Größe:** 7 KB | **md5:** `40e54660bb969e479ec3b76ef2a369ce`

```markdown
### 📄 .devcontainer/devcontainer.json

**Größe:** 952 B | **md5:** `62e6393a0cbb9c4aa49ae1e9bd82f1e7`

```json
{
  "name": "wgx-dev",
  "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
  "features": {
    "ghcr.io/devcontainers/features/git:1": {},
    "ghcr.io/devcontainers/features/github-cli:1": {},
    "ghcr.io/devcontainers/features/node:1": { "version": "20" }
  },
  "customizations": {
    "vscode": {
      "extensions": [
        "ms-azuretools.vscode-docker",
        "github.copilot",
        "eamodio.gitlens",
        "timonwong.shellcheck",
        "foxundermoon.shell-format",
        "jetmartin.bats",
        "streetsidesoftware.code-spell-checker"
      ],
      "settings": {
        "editor.formatOnSave": true,
        "[shellscript]": {
          "editor.defaultFormatter": "foxundermoon.shell-format"
        }
      }
    }
  },
  "remoteUser": "vscode",
  "postCreateCommand": "bash -lc '.devcontainer/setup.sh ensure-uv && export PATH=\"$HOME/.local/bin:$PATH\" && (just devcontainer-check || .devcontainer/setup.sh check)'"
}
```

### 📄 .devcontainer/setup.sh

**Größe:** 5 KB | **md5:** `e807bd07dfb7159aa3bd34f1b7b315b8`

```bash
#!/usr/bin/env bash

set -euo pipefail

readonly BASE_PACKAGES=(jq moreutils)
readonly OPTIONAL_PACKAGES=(shellcheck shfmt bats)

usage() {
  cat <<'USAGE'
Usage: setup.sh [command] [options]

Commands:
  check                 Report availability of base and optional development tools.
  install [targets...]  Install tool groups or individual packages. Defaults to "base".
  base|optional|all     Shortcut for "install" with the matching target(s).
  ensure-uv             Install uv (if missing) and ensure ~/.local/bin is on PATH.
  <package>             Shortcut for "install" with a specific package.

Targets:
  base       Install baseline development helpers (jq, moreutils).
  optional   Install optional tooling (shellcheck, shfmt, bats).
  all        Install both base and optional tool groups.
  <package>  Install a specific apt package from the base/optional lists.

Examples:
  setup.sh check
  setup.sh install                  # install baseline helpers
  setup.sh install optional         # install optional tooling
  setup.sh install all              # install everything
  setup.sh install shellcheck bats  # install a subset
  setup.sh ensure-uv                # install uv and export ~/.local/bin
USAGE
}

package_installed() {
  dpkg -s "$1" >/dev/null 2>&1
}

package_version() {
  dpkg-query --showformat='${Version}' --show "$1" 2>/dev/null || true
}

ensure_packages() {
  local -a missing_packages=()
  local pkg
  for pkg in "$@"; do
    if [[ -z "$pkg" ]]; then
      continue
    fi
    if ! package_installed "$pkg"; then
      missing_packages+=("$pkg")
    fi
  done

  if ((${#missing_packages[@]} == 0)); then
    echo "All requested packages are already installed."
    return 0
  fi

  echo "Installing packages: ${missing_packages[*]}"
  sudo apt-get update -y
  sudo apt-get install -y "${missing_packages[@]}"
}

print_group_header() {
  local label=$1
  printf '\n%s\n' "$label"
  printf '%*s\n' "${#label}" '' | tr ' ' '-'
}

print_tool_status() {
  local package=$1
  local binary=$2
  local description=$3
  local installed="✗"
  local version=""

  if package_installed "$package"; then
    installed="✓"
    version="$(package_version "$package")"
  fi

  if [[ -n "$version" ]]; then
    printf '  %s %-12s (%s) %s\n' "$installed" "$binary" "$package" "$version"
  else
    printf '  %s %-12s (%s)\n' "$installed" "$binary" "$package"
  fi

  if [[ $installed == "✗" ]]; then
    printf '      %s\n' "$description"
  fi
}

ensure_uv() {
  # shellcheck disable=SC2016
  local entry='export PATH="$HOME/.local/bin:$PATH"'
  local installer_url="https://astral.sh/uv/install.sh"

  if ! command -v uv >/dev/null 2>&1; then
    echo "Installing uv from ${installer_url}"
    curl -LsSf "$installer_url" | sh
  else
    echo "uv already present: $(uv --version)"
  fi

  local shell_rc
  for shell_rc in "$HOME/.bashrc" "$HOME/.profile"; do
    if [[ ! -e "$shell_rc" ]]; then
      touch "$shell_rc"
    fi
    if ! grep -qxF "$entry" "$shell_rc"; then
      echo "$entry" >>"$shell_rc"
    fi
  done

  export PATH="$HOME/.local/bin:$PATH"
}

collect_packages() {
  local -n _out=$1
  shift || true

  local target
  for target in "$@"; do
    case "$target" in
    '')
      continue
      ;;
    check)
      echo "Ignoring 'check' target during installation. Run './.devcontainer/setup.sh check' separately." >&2
      continue
      ;;
    base)
      _out+=("${BASE_PACKAGES[@]}")
      ;;
    optional)
      _out+=("${OPTIONAL_PACKAGES[@]}")
      ;;
    all)
      _out+=("${BASE_PACKAGES[@]}" "${OPTIONAL_PACKAGES[@]}")
      ;;
    jq | moreutils | shellcheck | shfmt | bats)
      _out+=("$target")
      ;;
    *)
      echo "Unknown install target: $target" >&2
      return 1
      ;;
    esac
  done
  return 0
}

run_check() {
  print_group_header "Baseline tools"
  print_tool_status jq jq "Install with './.devcontainer/setup.sh install base'"
  print_tool_status moreutils sponge "Install with './.devcontainer/setup.sh install base'"

  print_group_header "Optional tools"
  print_tool_status shellcheck shellcheck "Install with './.devcontainer/setup.sh install optional'"
  print_tool_status shfmt shfmt "Install with './.devcontainer/setup.sh install optional'"
  print_tool_status bats bats "Install with './.devcontainer/setup.sh install optional'"
}

run_install() {
  shift || true

  local default_to_base=0
  if (($# == 0)); then
    default_to_base=1
  fi

  local -a collected=()
  if ! collect_packages collected "$@"; then
    return 1
  fi

  local -a targets=()
  if ((${#collected[@]} > 0)); then
    targets=("${collected[@]}")
  fi
  if ((${#targets[@]} == 0)); then
    if ((default_to_base)); then
      targets=("${BASE_PACKAGES[@]}")
    else
      echo "No packages selected for installation." >&2
      return 0
    fi
  fi

  # Deduplicate while preserving order.
  local -a unique=()
  declare -A seen_map=()
  local pkg
  for pkg in "${targets[@]}"; do
    if [[ -z "$pkg" ]]; then
      continue
    fi
    if [[ -z "${seen_map[$pkg]:-}" ]]; then
      seen_map[$pkg]=1
      unique+=("$pkg")
    fi
  done

  ensure_packages "${unique[@]}"
}

main() {
  case "${1-}" in
  '')
    usage
    exit 1
    ;;
  check)
    run_check
    ;;
  install)
    run_install "$@"
    ;;
  base | optional | all | jq | moreutils | shellcheck | shfmt | bats)
    run_install install "$@"
    ;;
  ensure-uv)
    ensure_uv
    ;;
  -h | --help)
    usage
    ;;
  *)
    echo "Unknown command: $1" >&2
    usage >&2
    exit 1
    ;;
  esac
}

main "$@"
```
```

### 📄 merges/wgx_merge_2510262237__.github_actions_run-bats.md

**Größe:** 2 KB | **md5:** `a6c60ddf85a5f0e5ab326ca250fcfee4`

```markdown
### 📄 .github/actions/run-bats/action.yml

**Größe:** 2 KB | **md5:** `55afe6a2f8396d95c09373a01b2662c4`

```yaml
name: Run Bats test suite
description: Run the repository's Bats-based test suites
inputs:
  working-directory:
    description: Directory to run bats from
    required: false
    default: .
  bats-args:
    description: "Arguments to pass to the bats command (for example: \"-r tests\")"
    required: false
    default: -r tests
runs:
  using: composite
  steps:
    - name: Ensure bats is available
      shell: bash
      run: |
        set -euo pipefail
        if command -v bats >/dev/null 2>&1; then
          echo "Using existing bats: $(bats -v)"
          exit 0
        fi
        sudo apt-get update -y
        sudo apt-get install -y bats
    - name: Install bats helpers
      shell: bash
      working-directory: ${{ inputs.working-directory }}
      run: |
        set -euo pipefail
        mkdir -p test
        if [ ! -d test/bats-support ]; then
          git clone https://github.com/bats-core/bats-support.git test/bats-support
          (cd test/bats-support && git checkout v0.3.0)
        fi
        if [ ! -d test/bats-assert ]; then
          git clone https://github.com/bats-core/bats-assert.git test/bats-assert
          (cd test/bats-assert && git checkout v2.0.0)
        fi
    - name: Execute bats
      shell: bash
      working-directory: ${{ inputs.working-directory }}
      env:
        BATS_ARGS: ${{ inputs.bats-args }}
      run: |
        set -euo pipefail
        if [ -n "$BATS_ARGS" ]; then
          # Use eval and set -- to properly handle quoted arguments.
          eval "set -- $BATS_ARGS"
          _bats_args=("$@")
        else
          _bats_args=()
        fi
        bats "${_bats_args[@]}"
```
```

### 📄 merges/wgx_merge_2510262237__.github_actions_wgx-check.md

**Größe:** 2 KB | **md5:** `5f104f1673ef3454d5e929442c2e1653`

```markdown
### 📄 .github/actions/wgx-check/action.yml

**Größe:** 2 KB | **md5:** `fd11d88ee5e0aeff37cdd131df6e60ed`

```yaml
name: wgx-check
description: "Prüft ein Ziel-Repo gegen angegebene wgx-Version"
inputs:
  repo:
    description: "Repository, das getestet werden soll"
    required: true
  ref:
    description: "Ref im Ziel-Repo"
    required: false
    default: "main"
  wgx_ref:
    description: "Ref des wgx-Repos"
    required: false
    default: "main"
runs:
  using: "composite"
  steps:
    - name: Checkout target repo
      uses: actions/checkout@v4
      with:
        repository: ${{ inputs.repo }}
        ref: ${{ inputs.ref }}

    - name: Checkout wgx (self)
      uses: actions/checkout@v4
      with:
        path: wgx
        ref: ${{ inputs.wgx_ref }}

    - name: Install basics
      shell: bash
      run: |
        sudo apt-get update -y
        sudo apt-get install -y bash coreutils git curl jq
        sudo apt-get install -y build-essential pkg-config || true
        curl https://sh.rustup.rs -sSf | sh -s -- -y >/dev/null 2>&1 || true
        echo "$HOME/.cargo/bin" >> $GITHUB_PATH
        if command -v pnpm >/dev/null 2>&1; then
          echo "pnpm already available"
        else
          curl -fsSL https://get.pnpm.io/install.sh | sh -s -- --silent || true
          echo "$HOME/.local/share/pnpm" >> $GITHUB_PATH
        fi

    - name: Link wgx
      shell: bash
      run: |
        chmod +x wgx/wgx
        echo "${PWD}/wgx" >> $GITHUB_PATH

    - name: Sanity
      shell: bash
      run: |
        ./wgx/wgx version || true
        if ! ls .wgx/profile.* >/dev/null 2>&1; then
          echo "profile manifest fehlt"
          exit 1
        fi

    - name: Validate manifest
      shell: bash
      run: |
        wgx validate --json | jq -e '.ok==true'

    - name: Execute safe tasks
      shell: bash
      run: |
        set -euo pipefail
        tasks_json="$(wgx tasks --json --groups)"
        if echo "$tasks_json" | jq -e '.tasks[] | select(.name=="doctor" and .safe==true)' >/dev/null; then
          wgx task doctor || true
        fi
        if echo "$tasks_json" | jq -e '.tasks[] | select(.name=="test" and .safe==true)' >/dev/null; then
          wgx task test
        fi
```
```

### 📄 merges/wgx_merge_2510262237__.github_workflows.md

**Größe:** 36 KB | **md5:** `3d3adf240fea3a77db21f19c4f0580e4`

```markdown
### 📄 .github/workflows/ci.yml

**Größe:** 14 KB | **md5:** `4ef54d52ced4b0ae03e0147dd359be5b`

```yaml
name: CI (smart PR)

on:
  pull_request:
    branches: [ main ]
    types: [opened, synchronize, reopened, ready_for_review, labeled, unlabeled]
  merge_group: {}
  workflow_dispatch: {}

permissions:
  id-token: write
  pull-requests: write
  contents: read

concurrency:
  group: ${{ github.workflow }}-${{ github.event.pull_request.number || github.ref }}
  cancel-in-progress: true

jobs:
  changes:
    name: Detect changes
    runs-on: ubuntu-latest
    outputs:
      shell: ${{ steps.filter.outputs.shell }}
      tests: ${{ steps.filter.outputs.tests }}
      docs: ${{ steps.filter.outputs.docs }}
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: dorny/paths-filter@v3
        id: filter
        with:
          filters: |
            shell:
              - 'wgx'
              - '**/*.sh'
              - '**/*.bash'
            tests:
              - 'tests/**/*.bats'
              - 'tests/**/*.sh'
            docs:
              - '**/*.md'
              - 'docs/**'

  lint_shell:
    name: Shell lint (shfmt + shellcheck)
    needs: changes
    if: |
      github.event_name == 'merge_group' ||
      github.event_name == 'workflow_dispatch' ||
      (
        github.event_name == 'pull_request' &&
        github.event.pull_request.draft == false &&
        (
          needs.changes.outputs.shell == 'true' ||
          contains(github.event.pull_request.labels.*.name, 'full-ci') ||
          contains(github.event.pull_request.labels.*.name, 'lint')
        )
      )
    runs-on: ubuntu-latest
    timeout-minutes: 12
    steps:
      - uses: actions/checkout@v4
      - name: Find changed shell files
        id: shell_files
        env:
          FORCE_FULL: ${{ github.event_name != 'pull_request' || contains(github.event.pull_request.labels.*.name, 'full-ci') || contains(github.event.pull_request.labels.*.name, 'lint') }}
          PR_BASE_SHA: ${{ github.event.pull_request.base.sha || '' }}
        run: |
          set -euo pipefail
          base="$PR_BASE_SHA"
          head="${GITHUB_SHA}"
          declare -a candidates=()
          if [[ "$FORCE_FULL" == 'true' ]]; then
            mapfile -t candidates < <(git ls-files '*.sh' '*.bash' 'wgx' 2>/dev/null || true)
          elif [[ -n "$base" ]]; then
            if git fetch --no-tags --depth=50 origin "$base"; then
              mapfile -t candidates < <(git diff --name-only "$base" "$head" 2>/dev/null || true)
            else
              echo "git fetch failed; falling back to full shell file list" >&2
              mapfile -t candidates < <(git ls-files '*.sh' '*.bash' 'wgx' 2>/dev/null || true)
            fi
          else
            mapfile -t candidates < <(git ls-files '*.sh' '*.bash' 'wgx' 2>/dev/null || true)
          fi

          declare -a shell_files=()
          for file in "${candidates[@]}"; do
            [[ -z "$file" ]] && continue
            if [[ -f "$file" ]]; then
              case "$file" in
                *.sh|*.bash|wgx)
                  shell_files+=("$file")
                  ;;
              esac
            fi
          done

          {
            echo 'files<<EOF'
            printf '%s\n' "${shell_files[@]}"
            echo 'EOF'
          } >> "$GITHUB_OUTPUT"
      - name: Install shell tooling
        run: |
          sudo apt-get update -y
          sudo apt-get install -y --no-install-recommends shellcheck shfmt jq
      - name: bash -n (syntax check)
        run: |
          set -euo pipefail
          ./etc/ci/run-with-files.sh --per-file "No shell files to check." bash -n <<'EOF'
${{ steps.shell_files.outputs.files }}
EOF
      - name: shfmt (check)
        run: |
          set -euo pipefail
          ./etc/ci/run-with-files.sh "No shell files to format." shfmt -d <<'EOF'
${{ steps.shell_files.outputs.files }}
EOF
      - name: shellcheck
        run: |
          set -euo pipefail
          ./etc/ci/run-with-files.sh "No shell files to lint." shellcheck -S style <<'EOF'
${{ steps.shell_files.outputs.files }}
EOF

  bats_tests:
    name: Bats tests
    needs: changes
    if: |
      github.event_name == 'merge_group' ||
      github.event_name == 'workflow_dispatch' ||
      (
        github.event_name == 'pull_request' &&
        github.event.pull_request.draft == false &&
        (
          needs.changes.outputs.shell == 'true' ||
          needs.changes.outputs.tests == 'true' ||
          contains(github.event.pull_request.labels.*.name, 'full-ci') ||
          contains(github.event.pull_request.labels.*.name, 'tests') ||
          contains(github.event.pull_request.labels.*.name, 'bats')
        )
      )
    runs-on: ubuntu-latest
    timeout-minutes: 12
    steps:
      - uses: actions/checkout@v4
      - name: Run bats test suites
        # Pin to v1.8.0, the latest published release of bats-core/bats-action.
        uses: bats-core/bats-action@v1.8.0
        with:
          helpers: |
            bats-support
            bats-assert

  docs_lint:
    name: Docs lint (Markdown + Links)
    needs: changes
    if: |
      github.event_name == 'merge_group' ||
      github.event_name == 'workflow_dispatch' ||
      (
        github.event_name == 'pull_request' &&
        (
          needs.changes.outputs.docs == 'true' ||
          contains(github.event.pull_request.labels.*.name, 'full-ci')
        )
      )
    runs-on: ubuntu-latest
    timeout-minutes: 12
    steps:
      - uses: actions/checkout@v4
      - name: Find changed docs and script files
        id: changed_docs
        env:
          FORCE_FULL: ${{ github.event_name != 'pull_request' || contains(github.event.pull_request.labels.*.name, 'full-ci') }}
          PR_BASE_SHA: ${{ github.event.pull_request.base.sha || '' }}
        run: |
          set -euo pipefail
          base="$PR_BASE_SHA"
          head="${GITHUB_SHA}"
          declare -a candidates=()
          if [[ "$FORCE_FULL" == 'true' ]]; then
            mapfile -t candidates < <(git ls-files '*.md' '*.mdx' '*.sh' '*.bash' 2>/dev/null || true)
          elif [[ -n "$base" ]]; then
            if git fetch --no-tags --depth=50 origin "$base"; then
              mapfile -t candidates < <(git diff --name-only "$base" "$head" -- '*.md' '*.mdx' '*.sh' '*.bash' 2>/dev/null || true)
            else
              echo "git fetch failed; falling back to full docs file list" >&2
              mapfile -t candidates < <(git ls-files '*.md' '*.mdx' '*.sh' '*.bash' 2>/dev/null || true)
            fi
          else
            mapfile -t candidates < <(git ls-files '*.md' '*.mdx' '*.sh' '*.bash' 2>/dev/null || true)
          fi

          declare -a markdown_files=()
          declare -a vale_files=()
          for file in "${candidates[@]}"; do
            [[ -z "$file" ]] && continue
            if [[ -f "$file" ]]; then
              case "$file" in
                *.md|*.mdx)
                  markdown_files+=("$file")
                  vale_files+=("$file")
                  ;;
                *.sh|*.bash)
                  vale_files+=("$file")
                  ;;
              esac
            fi
          done

          {
            echo 'markdown_files<<EOF'
            printf '%s\n' "${markdown_files[@]}"
            echo 'EOF'
            echo 'vale_files<<EOF'
            printf '%s\n' "${vale_files[@]}"
            echo 'EOF'
          } >> "$GITHUB_OUTPUT"
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      - name: Install Vale
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          VALE_VERSION: latest
        run: |
          set -euo pipefail
          owner="errata-ai"
          repo="vale"
          version="${VALE_VERSION:-latest}"
          release_json=""

          # Use authenticated GitHub API requests to avoid low rate limits
          accept_header="Accept: application/vnd.github+json"
          api_ver_header="X-GitHub-Api-Version: 2022-11-28"

          curl_headers=(
            -H "$accept_header"
            -H "$api_ver_header"
          )

          if [[ -n "${GITHUB_TOKEN:-}" ]]; then
            curl_headers+=(
              -H "Authorization: Bearer ${GITHUB_TOKEN}"
            )
          fi

          if [[ -n "${version}" && "${version}" != "latest" ]]; then
            if ! release_json=$(curl --retry 5 --retry-all-errors -fsSL \
              "${curl_headers[@]}" \
              "https://api.github.com/repos/${owner}/${repo}/releases/tags/${version}"); then
              echo "Unable to fetch release metadata for ${version}; falling back to the latest release" >&2
              release_json=""
            fi
          fi

          if [[ -z "${release_json}" ]]; then
            release_json=$(curl --retry 5 --retry-all-errors -fsSL \
              "${curl_headers[@]}" \
              "https://api.github.com/repos/${owner}/${repo}/releases/latest")
            version=$(printf '%s' "${release_json}" | python3 - <<'PY'
import json, sys
data = json.load(sys.stdin)
tag = data.get('tag_name')
if not tag:
    raise SystemExit('Latest release tag_name not found')
print(tag)
PY
)
          fi

          if [[ -z "${release_json}" ]]; then
            echo "Failed to retrieve release metadata for Vale" >&2
            exit 1
          fi

          readarray -t asset_info < <(printf '%s' "${release_json}" | python3 - <<'PY'
import json, sys

data = json.load(sys.stdin)
preferred_suffixes = (
    'Linux_64-bit.tar.gz',
    'Linux_amd64.tar.gz',
)

for suffix in preferred_suffixes:
    for asset in data.get('assets', []):
        name = asset.get('name') or ''
        if name.endswith(suffix):
            print(name)
            print(asset.get('browser_download_url') or '')
            sys.exit(0)

raise SystemExit('No suitable Linux tarball found in release assets')
PY
)

          if [[ "${#asset_info[@]}" -lt 2 ]]; then
            echo "Failed to determine Vale asset download information" >&2
            exit 1
          fi

          asset_name="${asset_info[0]}"
          asset_url="${asset_info[1]}"

          checksums_url=$(printf '%s' "${release_json}" | python3 - <<'PY'
import json, sys

data = json.load(sys.stdin)
for asset in data.get('assets', []):
    name = asset.get('name') or ''
    if name.endswith('checksums.txt'):
        print(asset.get('browser_download_url') or '')
        sys.exit(0)

raise SystemExit('checksums.txt not found in release assets')
PY
)

          curl --retry 5 --retry-all-errors -fsSL "${asset_url}" -o vale.tar.gz
          curl --retry 5 --retry-all-errors -fsSL "${checksums_url}" -o checksums.txt

          EXPECTED_SHA256=$(awk -v file="${asset_name}" '$2 == file {print $1; exit}' checksums.txt)
          if [[ -z "${EXPECTED_SHA256:-}" ]]; then
            echo "Unable to determine expected checksum for ${asset_name}" >&2
            exit 1
          fi

          ACTUAL_SHA256=$(sha256sum vale.tar.gz | awk '{print $1}')
          if [[ "${EXPECTED_SHA256}" != "${ACTUAL_SHA256}" ]]; then
            echo "SHA256 checksum mismatch for vale.tar.gz" >&2
            echo "Expected: ${EXPECTED_SHA256}" >&2
            echo "Actual:   ${ACTUAL_SHA256}" >&2
            exit 1
          fi

          tar -xzf vale.tar.gz
          test -f vale && echo "vale binary extracted" || (echo "vale missing" && exit 1)
          sudo install -m 0755 vale /usr/local/bin/vale
          echo "Installed Vale ${version} (${asset_name})"
          vale --version
          rm -f vale vale.tar.gz checksums.txt
      - name: Markdownlint (changed only)
        run: |
          set -euo pipefail
          npm i -g markdownlint-cli2@0.12.1
          ./etc/ci/run-with-files.sh "No Markdown files to lint." markdownlint-cli2 <<'EOF'
${{ steps.changed_docs.outputs.markdown_files }}
EOF
      - name: Vale lint (changed only)
        run: |
          set -euo pipefail
          ./etc/ci/run-with-files.sh "No files for Vale." vale --minAlertLevel=warning <<'EOF'
${{ steps.changed_docs.outputs.vale_files }}
EOF
      - name: Link check (Lychee)
        if: steps.changed_docs.outputs.markdown_files != ''
        uses: lycheeverse/lychee-action@v2
        with:
          args: >-
            --no-progress
            --accept 200,206,429
            --max-concurrency 8
            --retry-wait-time 2
            --timeout 30
            --max-retries 2
            --exclude-path 'node_modules|.git'
            --exclude 'localhost|127\.0\.0\.1|badge\.fury\.io|shields\.io'
            ${{ steps.changed_docs.outputs.markdown_files }}
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

  profile_contracts:
    name: Profile contracts
    needs: changes
    if: |
      github.event_name == 'workflow_dispatch' ||
      github.event_name == 'merge_group' ||
      (
        github.event_name == 'pull_request' &&
        contains(github.event.pull_request.labels.*.name, 'full-ci')
      )
    runs-on: ubuntu-latest
    timeout-minutes: 10
    strategy:
      fail-fast: false
      matrix:
        repo:
          - https://github.com/heimgewebe/weltgewebe
          - https://github.com/heimgewebe/hausKI
          # ggf. weitere Repos ergänzen
    steps:
      - uses: actions/checkout@v4
      - name: Configure git safe.directory
        run: git config --global --add safe.directory "$GITHUB_WORKSPACE"
      - name: Validate ${{ matrix.repo }}
        env:
          GIT_ASKPASS: /bin/true
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          set -euo pipefail
          repo="${{ matrix.repo }}"
          name="${repo##*/}"
          target="$repo"
          if [[ "$repo" == https://github.com/* && -n "${GH_TOKEN:-}" ]]; then
            target="https://x-access-token:${GH_TOKEN}@github.com/${repo#https://github.com/}"
          fi
          ./wgx validate --json "$target" --out "validate_${name}.json"
      - name: Upload JSON results
        uses: actions/upload-artifact@v4
        with:
          name: profile-contracts-json
          path: validate_*.json
```

### 📄 .github/workflows/cli-docs-check.yml

**Größe:** 1 KB | **md5:** `1c037b9a35830445f9f6d9b80bdab75e`

```yaml
name: CLI Docs (consistency)

on:
  pull_request:
    branches: [ "**" ]
    paths:
      - "wgx"
      - "cmd/**"
      - "scripts/gen-cli-docs.sh"
      - "docs/cli.md"
  push:
    branches: [ "main" ]
    paths:
      - "wgx"
      - "cmd/**"
      - "scripts/gen-cli-docs.sh"
      - "docs/cli.md"

permissions:
  contents: read
  # keine artifacts, kein cache -> keine actions:write nötig

defaults:
  run:
    shell: bash

jobs:
  check:
    name: Regenerate & verify docs/cli.md
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          submodules: recursive
          fetch-depth: 0

      - name: Make generator executable (defensiv)
        run: |
          chmod +x scripts/gen-cli-docs.sh || true
          chmod +x wgx || true

      - name: Regenerate CLI docs
        run: |
          scripts/gen-cli-docs.sh

      - name: Verify no diff
        run: |
          set -euo pipefail
          if git diff --quiet -- docs/cli.md; then
            echo "✅ docs/cli.md ist aktuell."
          else
            echo "::error::CLI-Referenz ist nicht aktuell. Bitte lokal 'scripts/gen-cli-docs.sh' ausführen und Änderungen committen."
            echo ""
            echo "──── git diff docs/cli.md ────"
            git --no-pager diff -- docs/cli.md || true
            echo ""
            echo "Lokal fixen: ./scripts/gen-cli-docs.sh && git add docs/cli.md && git commit"
            exit 1
          fi
```

### 📄 .github/workflows/compat-on-demand.yml

**Größe:** 3 KB | **md5:** `40cd193211e4c2e8c9b4e1f00e85594b`

```yaml
name: Compat (on-demand matrix)

on:
  workflow_dispatch:
    inputs:
      targets_json:
        description: 'Matrix als JSON (repo/ref)'
        required: false
        default: |
          [
            {"repo":"heimgewebe/hausKI","ref":"main"},
            {"repo":"heimgewebe/weltgewebe","ref":"main"}
          ]
  pull_request:
    branches: [ main ]
    types: [labeled, unlabeled, synchronize, reopened, ready_for_review]
  merge_group: {}

permissions:
  id-token: write
  contents: read

concurrency:
  group: ${{ github.workflow }}-${{ github.event.pull_request.number || github.ref }}
  cancel-in-progress: true

jobs:
  gate:
    name: Decide when to run
    runs-on: ubuntu-latest
    outputs:
      run_compat: ${{ steps.decide.outputs.run_compat }}
      matrix: ${{ steps.matrix.outputs.matrix }}
    steps:
      - uses: actions/checkout@v4
      - uses: dorny/paths-filter@v3
        id: filter
        with:
          filters: |
            core:
              - 'wgx'
              - 'lib/**'
              - 'modules/**'
              - 'cmd/**'
              - '.github/actions/**'
      - id: decide
        shell: bash
        run: |
          labels="${{ github.event.pull_request.number && join(github.event.pull_request.labels.*.name, ' ') || '' }}"
          # Run if: merge_group OR manual dispatch OR label 'compat'/'full-ci' OR core changed
          if [[ "${{ github.event_name }}" == "merge_group" ]]; then echo "run_compat=true" >> $GITHUB_OUTPUT
          elif [[ "${{ github.event_name }}" == "workflow_dispatch" ]]; then echo "run_compat=true" >> $GITHUB_OUTPUT
          elif echo "$labels" | grep -qiE '(^| )(compat|full-ci)( |$)'; then echo "run_compat=true" >> $GITHUB_OUTPUT
          elif [[ "${{ steps.filter.outputs.core }}" == "true" ]]; then echo "run_compat=true" >> $GITHUB_OUTPUT
          else echo "run_compat=false" >> $GITHUB_OUTPUT; fi
      - id: matrix
        shell: bash
        run: |
          def='[{"repo":"heimgewebe/hausKI","ref":"main"},{"repo":"heimgewebe/weltgewebe","ref":"main"}]'
          inp=$(cat <<'JSON'
${{ github.event.inputs.targets_json }}
JSON
)
          # Fallback auf Default, wenn Input leer/ungültig
          if jq -e type >/dev/null 2>&1 <<<"$inp"; then echo "matrix=$inp" >> $GITHUB_OUTPUT
          else echo "matrix=$def" >> $GITHUB_OUTPUT; fi

  compat:
    name: Check ${{ matrix.target.repo }}@${{ matrix.target.ref }}
    needs: gate
    if: needs.gate.outputs.run_compat == 'true'
    runs-on: ubuntu-latest
    timeout-minutes: 45
    strategy:
      fail-fast: false
      matrix:
        target: ${{ fromJSON(needs.gate.outputs.matrix) }}
    steps:
      - uses: actions/checkout@v4
      - name: Run wgx-check
        uses: ./.github/actions/wgx-check
        with:
          repo: ${{ matrix.target.repo }}
          ref:  ${{ matrix.target.ref }}
```

### 📄 .github/workflows/contracts.yml

**Größe:** 214 B | **md5:** `af5c8714385a70cf9e572300c47c980b`

```yaml
name: contracts-validate
permissions:
  contents: read
  actions: read
  checks: write
on: [push, pull_request]
jobs:
  validate:
    uses: heimgewebe/metarepo/.github/workflows/contracts-validate.yml@contracts-v1
```

### 📄 .github/workflows/metrics.yml

**Größe:** 1 KB | **md5:** `78cc3152807fabe417ca9a2db0bcb236`

```yaml
name: "📊 Metrics Snapshot & Validation"
permissions:
  contents: read
  actions: write
  checks: write
on:
  workflow_dispatch:
  schedule:
    - cron: "0 * * * *"

env:
  METRICS_SCHEMA_URL: https://raw.githubusercontent.com/heimgewebe/metarepo/contracts-v1/contracts/wgx/metrics.json
  HAUSKI_POST_URL: ${{ secrets.HAUSKI_METRICS_URL }}

jobs:
  snapshot:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Ensure Node for ajv-cli
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          # Kein npm-Cache am Repo-Root, da es hier keine package-lock.json gibt.
          # Der Cache würde ohne Lockfile fehlschlagen. Daher bewusst deaktiviert.

      - name: Snapshot metrics
        run: scripts/wgx-metrics-snapshot.sh --json

      - name: Validate metrics contract
        run: npx --yes ajv-cli@5 validate -s "$METRICS_SCHEMA_URL" -d metrics.json

      - name: Optional POST to hausKI
        if: ${{ env.HAUSKI_POST_URL && env.HAUSKI_POST_URL != '' }}
        run: |
          curl --fail --silent --show-error \
            -H 'Content-Type: application/json' \
            --data @metrics.json \
            "$HAUSKI_POST_URL"
      - name: Upload metrics.json artifact
        uses: actions/upload-artifact@v4
        with:
          name: metrics-snapshot
          path: metrics.json
```

### 📄 .github/workflows/release.yml

**Größe:** 398 B | **md5:** `b0d8769d5d6ff723a14e449e6f7df991`

```yaml
name: release
permissions:
  contents: write
on:
  push:
    tags:
      - 'v*.*.*'

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Create GitHub Release
        uses: softprops/action-gh-release@v2
        with:
          generate_release_notes: true
```

### 📄 .github/workflows/security.yml

**Größe:** 2 KB | **md5:** `78af57d27d34d01bed588d85499b69f7`

```yaml
name: security
permissions:
  id-token: write
  contents: read

on:
  schedule:
    - cron: '0 5 * * *'
  push:
    branches:
      - main
  pull_request:
  workflow_dispatch:

jobs:
  audit:
    runs-on: ubuntu-latest
    timeout-minutes: 10
    concurrency:
      group: security-${{ github.ref }}
      cancel-in-progress: true
    steps:
      - uses: actions/checkout@v4

      - name: Locate Cargo manifest
        id: cargo-manifest
        run: |
          manifest=$(find . -name Cargo.toml -print -quit)
          if [[ -z "$manifest" ]]; then
            echo "found=false" >>"$GITHUB_OUTPUT"
            echo "No Cargo.toml found – skipping cargo audit run."
          else
            echo "found=true" >>"$GITHUB_OUTPUT"
            echo "manifest=$manifest" >>"$GITHUB_OUTPUT"
          fi
        shell: bash

      - name: Install Rust toolchain
        uses: dtolnay/rust-toolchain@stable

      # Caches beschleunigen cargo-audit merklich
      - name: Cache cargo registry + advisory DB
        if: steps.cargo-manifest.outputs.found == 'true'
        uses: actions/cache@v4
        with:
          path: |
            ~/.cargo/registry
            ~/.cargo/git
            ~/.cargo/advisory-db
          key: ${{ runner.os }}-cargo-${{ hashFiles('**/Cargo.lock') }}
          restore-keys: |
            ${{ runner.os }}-cargo-

      - name: Install cargo-audit
        if: steps.cargo-manifest.outputs.found == 'true'
        run: cargo install cargo-audit --locked

      - name: Audit dependencies
        if: steps.cargo-manifest.outputs.found == 'true'
        run: cargo audit --manifest-path "${{ steps.cargo-manifest.outputs.manifest }}"
        timeout-minutes: 5

      - name: Skip audit (no Cargo manifest found)
        if: steps.cargo-manifest.outputs.found != 'true'
        run: echo "No Cargo.toml detected in repository; cargo audit skipped."
      # Optional: falls du ein eigenes DB-Verzeichnis nutzt
      # - name: Audit with explicit DB path
      #   run: cargo audit -d ~/.cargo/advisory-db
```

### 📄 .github/workflows/shell-docs.yml

**Größe:** 3 KB | **md5:** `6bbd2b306723caa72177206a56b19045`

```yaml
name: shell-docs
permissions:
  contents: read
  actions: write
on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]
  workflow_dispatch:

permissions:
  contents: read
  actions: write

jobs:
  shell-and-docs:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Setup Node (cache npm)
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      - name: Install deps
        run: |
          export DEBIAN_FRONTEND=noninteractive
          sudo apt-get -yq update
          sudo apt-get -yq install shellcheck shfmt bats
          npm install -g markdownlint-cli@0.43.0
          tmpdir="$(mktemp -d)"
          curl -Ls https://github.com/errata-ai/vale/releases/download/v3.8.0/vale_3.8.0_Linux_64-bit.tar.gz \
            | tar xz -C "$tmpdir"
          sudo mv "$tmpdir/vale" /usr/local/bin/vale
          rm -rf "$tmpdir"
          vale --version
      - name: Lint shells
        run: |
          set -euo pipefail
          mapfile -t files < <(git ls-files '*.sh' '*.bash')
          if [[ ${#files[@]} -eq 0 ]]; then

<<TRUNCATED: max_file_lines=800>>
```

### 📄 merges/wgx_merge_2510262237__.local.md

**Größe:** 546 B | **md5:** `be7a91ad44c98926389d2b2ef2641ad6`

```markdown
### 📄 .local/README.md

**Größe:** 436 B | **md5:** `6025a32e11c2d16299dfd061d0a542a6`

```markdown
# `.local/`

This directory is reserved for machine-local caches and helper output that
should not be committed. Keeping a README in place documents the intent while
allowing the folder itself to stay ignored in Git.

Common examples include downloaded datasets, temporary CLI captures, or other
artifacts generated during runbook execution. Feel free to add additional notes
here if you introduce new tooling that relies on `.local/`.
```
```

### 📄 merges/wgx_merge_2510262237__.vale_styles_hauski_GermanComments.md

**Größe:** 356 B | **md5:** `f9577284b75f25899f4fdab20c91cf09`

```markdown
### 📄 .vale/styles/hauski/GermanComments/GermanComments.yml

**Größe:** 213 B | **md5:** `cafb4b9c480f4d8ebb615fded2b1187e`

```yaml
extends: existence
message: "Avoid colloquial expressions in comments."
level: warning
scope: sentence
tokens:
  - "halt"
  - "irgendwie"
  - "sozusagen"
  - "quasi"
  - "mal eben"
  - "eigentlich"
  - "kurz mal"
```
```

### 📄 merges/wgx_merge_2510262237__.vale_styles_hauski_GermanProse.md

**Größe:** 308 B | **md5:** `1ff1c62582c4f60873ced733b4d2a4fa`

```markdown
### 📄 .vale/styles/hauski/GermanProse/GermanProse.yml

**Größe:** 171 B | **md5:** `a9b4e843b53adf4ddf8a09e257c61212`

```yaml
extends: existence
message: "Avoid colloquial expressions in German prose."
level: warning
scope: paragraph
tokens:
  - "halt"
  - "irgendwie"
  - "sozusagen"
  - "quasi"
```
```

### 📄 merges/wgx_merge_2510262237__.vale_styles_wgxlint.md

**Größe:** 457 B | **md5:** `09966eb821f5d34ca479bf7f282412ca`

```markdown
### 📄 .vale/styles/wgxlint/GermanComments.yml

**Größe:** 328 B | **md5:** `97df599213cb74c7fe07fc0c4f31aa6d`

```yaml
# Flags German words in code comments only
extends: existence
message: "Avoid German words in comments; use English instead."
ignorecase: true
level: warning
scope: comments   # <- checks ONLY comments, not strings or code
tokens:
  - "\b(Das|Der|Die|und|nicht|aber|wenn|dann|weil|mit|ohne|für|gegen)\b"
  - "[äöüßÄÖÜ]"
```
```

### 📄 merges/wgx_merge_2510262237__.wgx.md

**Größe:** 1 KB | **md5:** `27adc59e84207d0b8d979ba55183f77f`

```markdown
### 📄 .wgx/.gitignore

**Größe:** 136 B | **md5:** `f316929c70572e5c99093e90ee0583f3`

```plaintext
# Ignoriere die echte, lokale Profil-Datei mit evtl. sensiblen Angaben
profile.yml

# Diese Datei selbst bitte versionieren
!.gitignore
```

### 📄 .wgx/profile.example.yml

**Größe:** 762 B | **md5:** `67e6b482b725a7aeac54576e3f1a14f8`

```yaml
# =======================================================================
#  .wgx/profile.example.yml  —  CI-Fallback & Strukturhinweis (ohne Secrets)
#  WARNUNG: Keine echten Zugangsdaten hier eintragen!
#  ➜ Lokale Nutzung: Kopiere diese Datei zu .wgx/profile.yml
#     und passe sie NUR lokal an (.wgx/profile.yml ist von Git ignoriert).
#  Diese Example-Datei MUSS versioniert bleiben, damit Guard/CI laufen.
# =======================================================================

wgx:
  apiVersion: v1.1
  requiredWgx: "^2.0.0"
  repoKind: generic

  tooling:
    python:
      manager: uv
      version: "3.12"
      lockfile: true
    shell:
      default: bash

  # Minimaler Task für Smoke-Checks in CI
  tasks:
    smoke: "echo wgx-profile-ok"
```
```

### 📄 merges/wgx_merge_2510262237__.wgx_audit.md

**Größe:** 113 B | **md5:** `e38d0dce7c4459fce4f61ffb3cb77f3c`

```markdown
### 📄 .wgx/audit/.gitkeep

**Größe:** 1 B | **md5:** `68b329da9893e34099c7d8ad5cb9c940`

```plaintext

```
```

### 📄 merges/wgx_merge_2510262237__archiv.md

**Größe:** 32 KB | **md5:** `5f484962e283a32a8380c4f1f2ed10e2`

```markdown
### 📄 archiv/wgx

**Größe:** 76 KB | **md5:** `1097bc36767964e98d5c39ddf0dbcfe2`

```plaintext
#!/usr/bin/env bash
# wgx – Weltgewebe CLI · Termux/WSL/macOS/Linux · origin-first
# Version: v2.0.0
# Lizenz: MIT (projektintern); Autorenteam: weltweberei.org
#
# RC-Codes:
#   0 = OK, 1 = WARN (fortsetzbar), 2 = BLOCKER (Abbruch)
#
# OFFLINE:  deaktiviert Netzwerkaktionen bestmöglich (fetch, npx pulls etc.)
# DRYRUN :  zeigt Kommandos an, führt sie aber nicht aus (wo sinnvoll)

# ─────────────────────────────────────────────────────────────────────────────
# SAFETY / SHELL MODE
# ─────────────────────────────────────────────────────────────────────────────
set -e
set -u
set -E
if ! set -o pipefail 2>/dev/null; then
  if [[ ${WGX_DEBUG:-0} != 0 ]]; then
    echo "archiv/wgx: 'pipefail' wird nicht unterstützt; fahre ohne fort." >&2
  fi
fi
IFS=$'\n\t'
umask 077
shopt -s extglob nullglob

# stabile Locale für Parser/Sort/Grep
export LC_ALL=C LANG=C

# optionaler Schreibschutz gegen versehentliches '>'
# (bewusst: wer überschreiben will, nutzt >|)
set -o noclobber

trap 'ec=$?; cmd=$BASH_COMMAND; line=${BASH_LINENO[0]}; fn=${FUNCNAME[1]:-MAIN}; \
      ((ec)) && printf "❌ wgx: Fehler in %s (Zeile %s): %s (exit=%s)\n" \
      "$fn" "$line" "$cmd" "$ec" >&2' ERR

WGX_VERSION="2.0.0"
RC_OK=0; RC_WARN=1; RC_BLOCK=2

# Früh-Exit für Versionsabfrage (auch ohne Git-Repo nutzbar)
if [[ "${1-}" == "--version" || "${1-}" == "-V" ]]; then
  printf "wgx v%s\n" "$WGX_VERSION"
  exit 0
fi

# ─────────────────────────────────────────────────────────────────────────────
# LOG / UI HELPERS
# ─────────────────────────────────────────────────────────────────────────────
_ok()   { printf "✅ %s\n" "$*"; }
_warn() { printf "⚠️  %s\n" "$*" >&2; }
_err()  { printf "❌ %s\n" "$*" >&2; }
info()  { printf "• %s\n"  "$*"; }
die()   { _err "$*"; exit 1; }
ok()    { _ok "$@"; }
warn()  { _warn "$@"; }
logv()  { ((VERBOSE)) && printf "… %s\n" "$*"; }
has()   { command -v "$1" >/dev/null 2>&1; }

trim()     { local s="$*"; s="${s#"${s%%[![:space:]]*}"}"; printf "%s" "${s%"${s##*[![:space:]]}"}"; }
to_lower() { tr '[:upper:]' '[:lower:]'; }

# Prompt liest vorzugsweise aus TTY (robust in Pipes/CI)
read_prompt() { # read_prompt var "Frage?" "default"
  local __v="$1"; shift
  local q="${1-}"; shift || true
  local d="${1-}"
  local ans
  if [[ -t 0 && -r /dev/tty ]]; then
    printf "%s " "$q"
    IFS= read -r ans < /dev/tty || ans="$d"
  else
    ans="$d"
  fi
  [[ -z "$ans" ]] && ans="$d"
  printf -v "$__v" "%s" "$ans"
}

# ─────────────────────────────────────────────────────────────────────────────
# GLOBAL DEFAULTS
# ─────────────────────────────────────────────────────────────────────────────
: "${ASSUME_YES:=0}"
: "${DRYRUN:=0}"
: "${TIMEOUT:=0}"      # 0 = kein Timeout
: "${NOTIMEOUT:=0}"    # 1 = Timeout unterdrücken
: "${VERBOSE:=0}"
: "${OFFLINE:=0}"

: "${WGX_BASE:=main}"
: "${WGX_SIGNING:=auto}"          # auto|ssh|gpg|off
: "${WGX_PREVIEW_DIFF_LINES:=120}"
: "${WGX_PR_LABELS:=}"
: "${WGX_CI_WORKFLOW:=CI}"
: "${WGX_AUTO_BRANCH:=0}"
: "${WGX_PM:=}"                   # pnpm|npm|yarn (leer = auto)

# ─────────────────────────────────────────────────────────────────────────────
# PLATFORM / ENV
# ─────────────────────────────────────────────────────────────────────────────
PLATFORM="linux"
case "$(uname -s 2>/dev/null || echo x)" in
  Darwin) PLATFORM="darwin" ;;
  *)      PLATFORM="linux"  ;;
esac
is_wsl() { uname -r 2>/dev/null | grep -qiE 'microsoft|wsl2?'; }
is_termux() {
  [[ "${PREFIX-}" == *"/com.termux/"* ]] && return 0
  command -v termux-setup-storage >/dev/null 2>&1 && return 0
  return 1
}
is_codespace() { [[ -n "${CODESPACE_NAME-}" ]]; }

# ─────────────────────────────────────────────────────────────────────────────
# REPO KONTEXT
# ─────────────────────────────────────────────────────────────────────────────
is_git_repo() { git rev-parse --is-inside-work-tree >/dev/null 2>&1; }
require_repo() {
  has git || die "git nicht installiert."
  is_git_repo || die "Nicht im Git-Repo (wgx benötigt ein Git-Repository)."
}

# Portables readlink -f
_root_resolve() {
  local here="$1"
  if command -v greadlink >/dev/null 2>&1; then greadlink -f "$here"
  elif command -v readlink >/dev/null 2>&1 && readlink -f / >/dev/null 2>&1; then readlink -f "$here"
  else
    local target="$here" link base
    while link="$(readlink "$target" 2>/dev/null)"; do
      case "$link" in
        /*) target="$link" ;;
        *)  base="$(cd "$(dirname "$target")" && pwd -P)"; target="$base/$link" ;;
      esac
    done
    printf "%s" "$target"
  fi
}

ROOT() {
  local here; here="$(_root_resolve "${BASH_SOURCE[0]}")"
  local fallback; fallback="$(cd "$(dirname "$here")/.." && pwd -P)"
  local r; r="$(git -C "${PWD}" rev-parse --show-toplevel 2>/dev/null || true)"
  [[ -n "$r" ]] && printf "%s" "$r" || printf "%s" "$fallback"
}

# Repo-Root heuristisch (wgx liegt i.d.R. als cli/wgx/wgx)
if r="$(git rev-parse --show-toplevel 2>/dev/null)"; then
  ROOT_DIR="$r"
else
  here="${BASH_SOURCE[0]}"
  base="$(cd "$(dirname "$here")" && pwd -P)"
  if [[ "$(basename "$base")" == "wgx" && "$(basename "$(dirname "$base")")" == "cli" ]]; then
    ROOT_DIR="$(cd "$base/../.." && pwd -P)"
  else
    ROOT_DIR="$(cd "$base/.." && pwd -P)"
  fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# CONFIG (.wgx.conf) EINLESEN – eval-frei & strikt
# ─────────────────────────────────────────────────────────────────────────────
# Erlaubte Schlüssel: nur A–Z, 0–9 und _
# Werte: CR abschneiden, keine Command-Substitution/Backticks/Nullbytes
if [[ -f "$ROOT_DIR/.wgx.conf" ]]; then
  while IFS='=' read -r k v; do
    k="$(trim "$k")"
    [[ -z "$k" || "$k" =~ ^# ]] && continue
    if [[ "$k" =~ ^[A-Z0-9_]+$ ]]; then
      v="${v%$'\r'}"
      [[ "$v" == *'$('* || "$v" == *'`'* || "$v" == *$'\0'* ]] && { warn ".wgx.conf: unsicherer Wert für $k ignoriert"; continue; }
      printf -v _sanitized "%s" "$v"
      declare -x "$k=$_sanitized"
    else
      warn ".wgx.conf: ungültiger Schlüssel '%s' ignoriert" "$k"
    fi
  done < "$ROOT_DIR/.wgx.conf"
fi

# ─────────────────────────────────────────────────────────────────────────────
# KLEINE PORTABILITÄTS-HELFER
# ─────────────────────────────────────────────────────────────────────────────
file_size_bytes() { # Linux/macOS/Busybox
  local f="$1" sz=0
  if   stat -c %s "$f" >/dev/null 2>&1; then sz=$(stat -c %s "$f")
  elif stat -f%z "$f" >/dev/null 2>&1;      then sz=$(stat -f%z "$f")
  else sz=$(wc -c < "$f" 2>/dev/null || echo 0); fi
  printf "%s" "$sz"
}

git_supports_magic() { git -C "$1" ls-files -z -- ':(exclude)node_modules/**' >/dev/null 2>&1; }

mktemp_portable() {
  local p="${1:-wgx}"
  if has mktemp; then
    mktemp -t "${p}.XXXXXX" 2>/dev/null || { local f="${TMPDIR:-/tmp}/${p}.$$.tmp"; : > "$f" && printf "%s" "$f"; }
  else
    local f="${TMPDIR:-/tmp}/${p}.$(date +%s).$$"
    : > "$f" || die "Konnte temporäre Datei nicht erstellen: $f"
    printf "%s" "$f"
  fi
}
now_ts() { date +"%Y-%m-%d %H:%M"; }

# Validierung & Flag-Ermittlung für Commit-Signing
maybe_sign_flag() {
  case "${WGX_SIGNING}" in
    off)  return 1 ;;
    ssh)  has git && git config --get gpg.format 2>/dev/null | grep -qi 'ssh' && echo "-S" || return 1 ;;
    gpg)  has gpg && echo "-S" || return 1 ;;
    auto) git config --get user.signingkey >/dev/null 2>&1 && echo "-S" || return 1 ;;
    *)    return 1 ;;
  esac
}

# Optionaler Timeout-Wrapper
with_timeout() {
  local t="${TIMEOUT:-0}"
  (( NOTIMEOUT )) && exec "$@"
  (( t>0 )) && command -v timeout >/dev/null 2>&1 && timeout "$t" "$@" || exec "$@"
}

# ─────────────────────────────────────────────────────────────────────────────
# GIT HELPERS
# ─────────────────────────────────────────────────────────────────────────────
git_branch() { git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "HEAD"; }
git_in_progress() {
  [[ -d .git/rebase-merge || -d .git/rebase-apply || -f .git/MERGE_HEAD ]]
}

# OFFLINE-freundlich, mit sichtbarer Warnung bei Fehler
_fetch_guard() {
  ((OFFLINE)) && { logv "offline: skip fetch"; return 0; }
  if ! git fetch -q origin 2>/dev/null; then
    warn "git fetch origin fehlgeschlagen (Netz/Origin?)."
    return 1
  fi
}

remote_host_path() {
  local u; u="$(git remote get-url origin 2>/dev/null || true)"
  [[ -z "$u" ]] && { echo ""; return; }
  case "$u" in
    http*://*/*)
      local rest="${u#*://}"
      local host="${rest%%/*}"
      local path="${rest#*/}"
      echo "$host $path"
      ;;
    ssh://git@*/*)
      local rest="${u#ssh://git@}"
      local host="${rest%%/*}"
      local path="${rest#*/}"
      echo "$host $path"
      ;;
    git@*:*/*)
      local host="${u#git@}"; host="${host%%:*}"
      local path="${u#*:}"
      echo "$host $path"
      ;;
    *) echo "";;
  esac
}
host_kind() { # erkannt: github, gitlab, codeberg, gitea (catch-all: gitea für fremde Hosts)
  local hp host; hp="$(remote_host_path || true)"; host="${hp%% *}"
  case "$host" in
    github.com) echo github ;;
    gitlab.com) echo gitlab ;;
    codeberg.org) echo codeberg ;;
    *)
      # Heuristik: beliebige eigene Gitea-Instanzen (host enthält gitea|forgejo?) → gitea
      if [[ "$host" == *gitea* || "$host" == *forgejo* ]]; then echo gitea; else echo unknown; fi
      ;;
  esac
}
compare_url() { # triple-dot base...branch (für github/gitlab/codeberg/gitea)
  local hp host path; hp="$(remote_host_path || true)"; [[ -z "$hp" ]] && { echo ""; return; }
  host="${hp%% *}"; path="${hp#* }"; path="${path%.git}"
  case "$(host_kind)" in
    github)   echo "https://$host/$path/compare/${WGX_BASE}...$(git_branch)";;
    gitlab)   echo "https://$host/$path/-/compare/${WGX_BASE}...$(git_branch)";;
    codeberg) echo "https://$host/$path/compare/${WGX_BASE}...$(git_branch)";;
    gitea)    echo "https://$host/$path/compare/${WGX_BASE}...$(git_branch)";;
    *)        echo "";;
  esac
}

git_ahead_behind() {
  local b="${1:-$(git_branch)}"
  ((OFFLINE)) || git fetch -q origin "$b" 2>/dev/null || true
  local ab; ab="$(git rev-list --left-right --count "origin/$b...$b" 2>/dev/null || echo "0 0")"
  local behind=0 ahead=0 IFS=' '
  read -r behind ahead <<<"$ab" || true
  printf "%s %s\n" "${behind:-0}" "${ahead:-0}"
}
ab_read() { local ref="$1" ab; ab="$(git_ahead_behind "$ref" 2>/dev/null || echo "0 0")"; set -- $ab; echo "${1:-0} ${2:-0}"; }

detect_web_dir() { for d in apps/web web; do [[ -d "$d" ]] && { echo "$d"; return; }; done; echo ""; }
detect_api_dir() { for d in apps/api api crates; do [[ -f "$d/Cargo.toml" ]] && { echo "$d"; return; }; done; echo ""; }

run_with_files_xargs0() {
  local title="$1"; shift
  if [[ -t 1 ]]; then info "$title"; fi
  if command -v xargs >/dev/null 2>&1; then
    xargs -0 "$@" || return $?
  else
    local buf=() f
    while IFS= read -r -d '' f; do buf+=("$f"); done
    [[ $# -gt 0 ]] && "$@" "${buf[@]}"
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# GLOBAL FLAG PARSER (bis SUB-Kommando)
# ─────────────────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes) ASSUME_YES=1 ;;
    --dry-run) DRYRUN=1 ;;
    --timeout) shift; [[ "${1-}" =~ ^[0-9]+$ ]] || die "--timeout braucht Zahl"; TIMEOUT="$1" ;;
    --no-timeout) NOTIMEOUT=1 ;;
    --verbose) VERBOSE=1 ;;
    --base) shift; WGX_BASE="${1-}" ;;
    --offline) OFFLINE=1 ;;
    --no-color) : ;; # wir nutzen Emojis → no-op
    send|sync|guard|heal|reload|clean|doctor|init|setup|lint|start|release|hooks|version|env|quick|config|test|selftest|help|-h|--help|status)
      break ;;
    *) warn "Unbekanntes globales Argument ignoriert: $1" ;;
  esac
  shift || true
done
SUB="${1-}"; shift || true

# ─────────────────────────────────────────────────────────────────────────────
# STATUS (kompakt)
# ─────────────────────────────────────────────────────────────────────────────
status_cmd() {
  if ! is_git_repo; then
    echo "=== wgx status ==="
    echo "root : $ROOT_DIR"
    echo "repo : (kein Git-Repo)"
    ok "Status OK"
    return $RC_OK
  fi
  local br web api behind=0 ahead=0
  br="$(git_branch)"; web="$(detect_web_dir || true)"; api="$(detect_api_dir || true)"
  local IFS=' '; read -r behind ahead < <(git_ahead_behind "$br") || true
  echo "=== wgx status ==="
  echo "root : $ROOT_DIR"
  echo "branch: $br (ahead:$ahead behind:$behind)  base:$WGX_BASE"
  echo "web  : ${web:-nicht gefunden}"
  echo "api  : ${api:-nicht gefunden}"
  (( OFFLINE )) && echo "mode : offline"
  ok "Status OK"
}

# ─────────────────────────────────────────────────────────────────────────────
# VALE / SPRACHE (optional)
# ─────────────────────────────────────────────────────────────────────────────
vale_maybe() {
  [[ -f ".vale.ini" ]] || return 0
  has vale || { warn "Vale nicht installiert – Sprach-Checks übersprungen."; return 0; }
  local staged=0; [[ "${1-}" == "--staged" ]] && staged=1
  if (( staged )); then
    if ! git diff --cached --name-only -z -- '*.md' 2>/dev/null | { IFS= read -r -d '' _; }; then
      return 0
    fi
    git diff --cached --name-only -z -- '*.md' 2>/dev/null \
      | run_with_files_xargs0 "Vale (staged)" vale
    return $?
  else
    if [[ -z "$(git ls-files -z -- '*.md' 2>/dev/null | head -c1)" ]]; then
      return 0
    fi
    git ls-files -z -- '*.md' 2>/dev/null \
      | run_with_files_xargs0 "Vale (alle .md)" vale
    return $?
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# PREFLIGHT / GUARD (inkl. Secrets, Conflicts, Big Files)
# ─────────────────────────────────────────────────────────────────────────────
changed_files_cached() { require_repo; git diff --cached --name-only -z | tr '\0' '\n' | sed '/^$/d'; }

# NUL-sicher inkl. Renames
changed_files_all() {
  require_repo
  local rec status path
  git status --porcelain -z \
  | while IFS= read -r -d '' rec; do
      status="${rec:0:2}"
      path="${rec:3}"
      if [[ "$status" =~ ^R ]]; then
        IFS= read -r -d '' path || true
      fi
      [[ -n "$path" ]] && printf '%s\n' "$path"
    done
}

auto_scope() {
  local files="$1" major="repo" m_web=0 m_api=0 m_docs=0 m_infra=0 m_devx=0 total=0
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    ((++total))
    case "$f" in
      apps/web/*) ((++m_web));;
      apps/api/*|crates/*) ((++m_api));;
      infra/*|deploy/*) ((++m_infra));;
      scripts/*|wgx|.wgx.conf) ((++m_devx));;
      docs/*|*.md|styles/*|.vale.ini) ((++m_docs));;
    esac
  done <<< "$files"
  (( total==0 )) && { echo "repo"; return; }
  local max=$m_docs; major="docs"
  (( m_web>max ))  && { max=$m_web;  major="web"; }
  (( m_api>max ))  && { max=$m_api;  major="api"; }
  (( m_infra>max ))&& { max=$m_infra; major="infra"; }
  (( m_devx>max )) && { max=$m_devx; major="devx"; }
  (( max * 100 >= 70 * total )) && echo "$major" || echo "meta"
}

# Basis-Branch verifizieren (nicht-blockierend, aber warnend)
validate_base_branch() {
  ((OFFLINE)) && return 0
  git rev-parse --verify "refs/remotes/origin/$WGX_BASE" >/dev/null 2>&1 || {
    warn "Basis-Branch origin/%s fehlt oder ist nicht erreichbar." "$WGX_BASE"
    return 1
  }
}

guard_run() {
  require_repo
  local FIX=0 LINT_OPT=0 TEST_OPT=0 DEEP_SCAN=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --fix) FIX=1;;
      --lint) LINT_OPT=1;;
      --test) TEST_OPT=1;;
      --deep-scan) DEEP_SCAN=1;;
      *) ;;
    esac
    shift || true
  done

  local rc=$RC_OK br; br="$(git_branch)"
  echo "=== Preflight (branch: $br, base: $WGX_BASE) ==="

  _fetch_guard || (( rc=rc<RC_WARN ? RC_WARN : rc ))
  validate_base_branch || (( rc=rc<RC_WARN ? RC_WARN : rc ))

  if git_in_progress; then
    echo "[BLOCKER] rebase/merge läuft → wgx heal --continue | --abort"
    rc=$RC_BLOCK
  fi
  [[ "$br" == "HEAD" ]] && { echo "[WARN] Detached HEAD – Branch anlegen."; (( rc==RC_OK )) && rc=$RC_WARN; }

  local behind=0 ahead=0 IFS=' '
  read -r behind ahead < <(git_ahead_behind "$br") || true
  if (( behind>0 )); then
    echo "[WARN] Branch $behind hinter origin/$br → rebase auf origin/$WGX_BASE"
    if (( FIX )); then
      git fetch -q origin "$WGX_BASE" 2>/dev/null || true
      git rebase "origin/$WGX_BASE" || rc=$RC_BLOCK
    fi
    (( rc==RC_OK )) && rc=$RC_WARN
  fi

  # Konfliktmarker in modifizierten Dateien
  local with_markers=""
  while IFS= read -r -d '' f; do
    [[ -z "$f" ]] && continue
    grep -Eq '<<<<<<<|=======|>>>>>>>' -- "$f" 2>/dev/null && with_markers+="$f"$'\n'
  done < <(git ls-files -m -z)
  if [[ -n "$with_markers" ]]; then
    echo "[BLOCKER] Konfliktmarker:"
    printf '%s' "$with_markers" | sed 's/^/  - /'
    rc=$RC_BLOCK
  fi

  # Secret-/Größen-Checks auf staged
  local staged; staged="$(changed_files_cached || true)"
  if [[ -n "$staged" ]]; then
    local secrets
    secrets="$(printf "%s\n" "$staged" | grep -Ei '\.env(\.|$)|(^|/)(id_rsa|id_ed25519)(\.|$)|\.pem$|\.p12$|\.keystore$' || true)"
    if [[ -n "$secrets" ]]; then
      echo "[BLOCKER] mögliche Secrets im Commit (Dateinamen-Match):"
      printf "%s\n" "$secrets" | sed 's/^/  - /'
      if (( FIX )); then
        while IFS= read -r s; do
          [[ -n "$s" ]] && git restore --staged -- "$s" 2>/dev/null || true
        done <<< "$secrets"
        echo "→ Secrets aus dem Index entfernt (Dateien bleiben lokal)."
      fi
      rc=$RC_BLOCK
    fi

    if (( DEEP_SCAN )); then
      local leaked
      leaked="$(git diff --cached -U0 \
        | grep -Ei 'BEGIN (RSA|EC|OPENSSH) PRIVATE KEY|AKIA[A-Z0-9]{16}|ghp_[A-Za-z0-9]{36}|glpat-[A-Za-z0-9_-]{20,}|AWS_ACCESS_KEY_ID|SECRET(_KEY)?|TOKEN|AUTHORIZATION:|PASSWORD' \
        || true)"
      if [[ -n "$leaked" ]]; then
        echo "[BLOCKER] möglicher Secret-Inhalt im Diff:"
        echo "$leaked" | sed 's/^/  > /'
        rc=$RC_BLOCK
      fi
    fi

    # Big Files > 10MB (portabel)
    local big=0; while IFS= read -r f; do
      [[ -f "$f" ]] || continue
      sz="$(file_size_bytes "$f")"
      if (( sz>10485760 )); then
        ((big++))
        printf '  - %s (%s B)\n' "$f" "$sz"
      fi
    done <<< "$staged"
    if (( big>0 )); then
      echo "[WARN] >10MB im Commit (siehe Liste oben)."
      (( rc==RC_OK )) && rc=$RC_WARN
    fi
  fi

  # Lockfile-Mix
  if git ls-files --error-unmatch pnpm-lock.yaml >/dev/null 2>&1 &&
     git ls-files --error-unmatch package-lock.json >/dev/null 2>&1; then
    echo "[WARN] pnpm-lock.yaml UND package-lock.json im Repo – Policy klären."
    (( rc==RC_OK )) && rc=$RC_WARN
  fi

  # Vale (nur Rückgabecode bewerten)
  if [[ -f ".vale.ini" ]]; then
    vale_maybe --staged || (( rc==RC_OK )) && rc=$RC_WARN
  fi

  case "$rc" in
    0) ok "Preflight sauber.";;
    1) warn "Preflight mit Warnungen.";;
    2) die "Preflight BLOCKER → bitte Hinweise beachten.";;
  esac
  printf "%s\n" "$rc"
}

# ─────────────────────────────────────────────────────────────────────────────
# SNAPSHOT (git stash)
# ─────────────────────────────────────────────────────────────────────────────
snapshot_make() {
  require_repo
  if [[ -z "$(git status --porcelain -z 2>/dev/null | head -c1)" ]]; then
    info "Kein Snapshot nötig (Arbeitsbaum sauber)."
    return 0
  fi
  local msg="snapshot@$(date +%s) $(git_branch)"
  git stash push -u -m "$msg" >/dev/null 2>&1 || true
  info "Snapshot erstellt (git stash list)."
}

# ─────────────────────────────────────────────────────────────────────────────
# LINT / TEST
# ─────────────────────────────────────────────────────────────────────────────
pm_detect() {
  local wd="$1"
  if [[ -n "${WGX_PM-}" ]]; then
    if has "$WGX_PM"; then echo "$WGX_PM"; return 0
    else warn "WGX_PM=$WGX_PM nicht gefunden, Auto-Detect aktiv."; fi
  fi
  if   [[ -f "$wd/pnpm-lock.yaml" ]] && has pnpm; then echo "pnpm"
  elif [[ -f "$wd/package-lock.json" ]] && has npm;  then echo "npm"
  elif [[ -f "$wd/yarn.lock"      ]] && has yarn; then echo "yarn"
  elif [[ -f "$wd/package.json"   ]]; then
    has pnpm && echo "pnpm" || has npm && echo "npm" || has yarn && echo "yarn" || echo ""
  else
    echo ""
  fi
}

run_soft() {
  local title="$1"; shift || true
  local rc=0
  if (( DRYRUN )); then
    if [[ $# -gt 0 ]]; then
      printf "DRY: %s → %q" "$title" "$1"; shift || true
      while [[ $# -gt 0 ]]; do printf " %q" "$1"; shift || true; done
      echo
    else
      printf "DRY: %s (kein Befehl übergeben)\n" "$title"
    fi
    return 0
  fi
  info "$title"
  if "$@"; then ok "$title ✓"; rc=0; else warn "$title ✗"; rc=1; fi
  printf "%s\n" "$rc"; return 0
}

lint_cmd() {
  require_repo
  local rc_total=$RC_OK

  # Vale
  vale_maybe || rc_total=$RC_WARN

  # Markdownlint (wenn vorhanden)
  if has markdownlint; then
    if [[ -n "$(git ls-files -z -- '*.md' 2>/dev/null | head -c1)" ]]; then
      git ls-files -z -- '*.md' 2>/dev/null \
        | run_with_files_xargs0 "markdownlint" markdownlint || rc_total=$RC_WARN
    fi
  fi

  # Web (Prettier/ESLint)
  local wd; wd="$(detect_web_dir || true)"
  if [[ -n "$wd" ]]; then
    local pm; pm="$(pm_detect "$wd")"
    local prettier_cmd="" eslint_cmd=""
    case "$pm" in
      pnpm) prettier_cmd="pnpm -s exec prettier"; eslint_cmd="pnpm -s exec eslint" ;;
      yarn) prettier_cmd="yarn -s prettier";     eslint_cmd="yarn -s eslint" ;;
      npm|"") prettier_cmd="npx --yes prettier"; eslint_cmd="npx --yes eslint" ;;
    esac

    if (( OFFLINE )); then
      [[ "$pm" == "npm" || "$pm" == "" ]] && warn "Offline: npx evtl. nicht verfügbar → Prettier/ESLint ggf. übersprungen."
    fi

    local has_gnu_find=0
    if find --version >/dev/null 2>&1; then
      find --version 2>/dev/null | grep -q GNU && has_gnu_find=1
    fi

    # Prettier Check (große Dateimengen effizient, node_modules/dist/build ausgeschlossen)
    if (( ! OFFLINE )); then
      if git_supports_magic "$wd" && (( has_gnu_find )); then
        git -C "$wd" ls-files -z \
          -- ':(exclude)node_modules/**' ':(exclude)dist/**' ':(exclude)build/**' \
             '*.js' '*.ts' '*.tsx' '*.jsx' '*.json' '*.css' '*.scss' '*.md' '*.svelte' 2>/dev/null \
        | run_with_files_xargs0 "Prettier Check" \
            sh -c 'cd "$1"; shift; '"$prettier_cmd"' -c -- "$@"' _ "$wd" \
        || run_with_files_xargs0 "Prettier Check (fallback npx)" \
            sh -c 'cd "$1"; shift; npx --yes prettier -c -- "$@"' _ "$wd" \
        || rc_total=$RC_WARN
      else
        find "$wd" \( -path "$wd/node_modules" -o -path "$wd/dist" -o -path "$wd/build" \) -prune -o \
             -type f \( -name '*.js' -o -name '*.ts' -o -name '*.tsx' -o -name '*.jsx' -o -name '*.json' -o -name '*.css' -o -name '*.scss' -o -name '*.md' -o -name '*.svelte' \) -print0 \
        | while IFS= read -r -d '' f; do rel="${f#$wd/}"; printf '%s\0' "$rel"; done \
        | run_with_files_xargs0 "Prettier Check" \
            sh -c 'cd "$1"; shift; '"$prettier_cmd"' -c -- "$@"' _ "$wd" \
        || { 
             if (( ! OFFLINE )); then
               run_with_files_xargs0 "Prettier Check (fallback npx)" \
                 sh -c 'cd "$1"; shift; npx --yes prettier -c -- "$@"' _ "$wd"
             fi
           } \
        || rc_total=$RC_WARN
      fi
    fi

    # ESLint (nur wenn Konfig vorhanden)
    local has_eslint_cfg=0
    [[ -f "$wd/.eslintrc" || -f "$wd/.eslintrc.js" || -f "$wd/.eslintrc.cjs" || -f "$wd/.eslintrc.json" \
       || -f "$wd/eslint.config.js" || -f "$wd/eslint.config.mjs" || -f "$wd/eslint.config.cjs" ]] && has_eslint_cfg=1
    if (( has_eslint_cfg )); then
      run_soft "ESLint" bash -c "cd '$wd' && $eslint_cmd -v >/dev/null 2>&1 && $eslint_cmd . --ext .js,.cjs,.mjs,.ts,.tsx,.svelte" \
      || { if (( OFFLINE )); then warn "ESLint übersprungen (offline)"; false; \
           else run_soft "ESLint (fallback npx)" \
                  bash -c "cd '$wd' && npx --yes eslint . --ext .js,.cjs,.mjs,.ts,.tsx,.svelte"; fi; } \
      || rc_total=$RC_WARN
    fi
  fi

  # Rust (fmt + clippy, falls vorhanden)
  local ad; ad="$(detect_api_dir || true)"
  if [[ -n "$ad" && -f "$ad/Cargo.toml" ]] && has cargo; then
    run_soft "cargo fmt --check" bash -lc "cd '$ad' && cargo fmt --all -- --check" || rc_total=$RC_WARN
    if rustup component list 2>/dev/null | grep -q 'clippy.*(installed)'; then
      run_soft "cargo clippy (Hinweise)" bash -lc "cd '$ad' && cargo clippy --all-targets --all-features -q" || rc_total=$RC_WARN
    else
      warn "clippy nicht installiert – übersprungen."
    fi
  fi

  # Shell / Dockerfiles / Workflows
  if has shellcheck; then
    if [[ -n "$(git ls-files -z -- '*.sh' 2>/dev/null | head -c1)" || -f "./wgx" || -d "./scripts" ]]; then
      { git ls-files -z -- '*.sh' 2>/dev/null; git ls-files -z -- 'wgx' 'scripts/*' 2>/dev/null; } \
        | run_with_files_xargs0 "shellcheck" shellcheck || rc_total=$RC_WARN
    fi
  fi
  if has hadolint; then
    if [[ -n "$(git ls-files -z -- '*Dockerfile*' 2>/dev/null | head -c1)" ]]; then
      git ls-files -z -- '*Dockerfile*' 2>/dev/null \
        | run_with_files_xargs0 "hadolint" hadolint || rc_total=$RC_WARN
    fi
  fi
  if has actionlint && [[ -d ".github/workflows" ]]; then run_soft "actionlint" actionlint || rc_total=$RC_WARN; fi

  (( rc_total==RC_OK )) && ok "Lint OK" || warn "Lint mit Hinweisen (rc=$rc_total)."
  printf "%s\n" "$rc_total"; return 0
}

pm_test() {
  local wd="$1"; local pm; pm="$(pm_detect "$wd")"
  case "$pm" in
    pnpm) (cd "$wd" && pnpm -s test -s) ;;
    npm)  (cd "$wd" && npm test -s) ;;
    yarn) (cd "$wd" && yarn -s test) ;;
    *)    return 0 ;;
  esac
}

test_cmd() {
  require_repo
  local rc_web=0 rc_api=0 wd ad pid_web= pid_api=
  trap '[[ -n "${pid_web-}" ]] && kill "$pid_web" 2>/dev/null || true; [[ -n "${pid_api-}" ]] && kill "$pid_api" 2>/dev/null || true' INT
  wd="$(detect_web_dir || true)"; ad="$(detect_api_dir || true)"
  if [[ -n "$wd" && -f "$wd/package.json" ]]; then
    info "Web-Tests…"; ( pm_test "$wd" ) & pid_web=$!
  fi
  if [[ -n "$ad" && -f "$ad/Cargo.toml" ]] && has cargo; then
    info "Rust-Tests…"; ( cd "$ad" && cargo test --all --quiet ) & pid_api=$!
  fi
  if [[ -n "${pid_web-}" ]]; then wait "$pid_web" || rc_web=1; fi
  if [[ -n "${pid_api-}" ]]; then wait "$pid_api" || rc_api=1; fi
  (( rc_web==0 && rc_api==0 )) && ok "Tests OK" || {
    [[ $rc_web -ne 0 ]] && warn "Web-Tests fehlgeschlagen."
    [[ $rc_api -ne 0 ]] && warn "Rust-Tests fehlgeschlagen."
    return 1
  }
}
# ─────────────────────────────────────────────────────────────────────────────
# Block 2 – Sicherheitsshims & Defaults (nur wirksam, wenn upstream fehlt)
# ─────────────────────────────────────────────────────────────────────────────
: "${WGX_BASE:=main}"
: "${WGX_PREVIEW_DIFF_LINES:=120}"
: "${WGX_CI_WORKFLOW:=CI}"
: "${OFFLINE:=0}"
: "${ASSUME_YES:=0}"
: "${DRYRUN:=0}"

# Mini-Logger & Guards
if ! type -t has >/dev/null 2>&1; then
  has() {
    command -v "$1" >/dev/null 2>&1
  }
fi
if ! type -t info >/dev/null 2>&1; then
  info() {
    printf '• %s\n' "$*"
  }
fi
if ! type -t ok >/dev/null 2>&1; then
  ok() {
    printf '✅ %s\n' "$*"
  }
fi
if ! type -t warn >/dev/null 2>&1; then
  warn() {
    printf '⚠️  %s\n' "$*" >&2
  }
fi
if ! type -t die >/dev/null 2>&1; then
  die() {
    printf '❌ %s\n' "$*" >&2
    exit 1
  }
fi

# Utils
if ! type -t trim >/dev/null 2>&1; then
  trim() {
    local s="$*"
    s="${s#"${s%%[![:space:]]*}"}"
    printf "%s" "${s%"${s##*[![:space:]]}"}"
  }
fi
if ! type -t to_lower >/dev/null 2>&1; then
  to_lower() {
    printf '%s' "$*" | tr '[:upper:]' '[:lower:]'
  }
fi

# Git-Hilfen
if ! type -t git_branch >/dev/null 2>&1; then
  git_branch() {
    git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "HEAD"
  }
fi
if ! type -t git_ahead_behind >/dev/null 2>&1; then
  git_ahead_behind() {
    local b="${1:-$(git_branch)}"
    git rev-list --left-right --count "origin/$b...$b" 2>/dev/null | awk '{print ($1?$1:0), ($2?$2:0)}'
  }
fi
if ! type -t compare_url >/dev/null 2>&1; then
  compare_url() {
    echo ""

<<TRUNCATED: max_file_lines=800>>
```

### 📄 merges/wgx_merge_2510262237__cli.md

**Größe:** 2 KB | **md5:** `c8927b6d7a287009cea651d04b4ee141`

```markdown
### 📄 cli/wgx

**Größe:** 2 KB | **md5:** `c58cf13e6ee8801638b8b39bbbfa98e8`

```plaintext
#!/usr/bin/env bash
set -e
set -u
if ! set -o pipefail 2>/dev/null; then
  if [[ ${WGX_DEBUG:-0} != 0 ]]; then
    echo "WGX: 'pipefail' wird von dieser Shell nicht unterstützt; fahre ohne fort." >&2
  fi
fi

# WGX_DIR auf Root des Repos setzen – robust MIT Symlink-Auflösung
# Warum? Wenn cli/wgx als Symlink in ~/.local/bin/wgx landet, zeigt
# ${BASH_SOURCE[0]} zunächst auf den Symlink-Pfad. Wir folgen allen
# Symlinks und landen zuverlässig im echten Verzeichnis der Datei.
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
  # Verzeichnis des gerade betrachteten Pfades (kann selbst ein Symlink sein)
  DIR="$(cd -P "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd)"
  # Aufgelöstes Ziel des Symlinks holen
  TARGET="$(readlink "$SOURCE")"
  # Wenn Ziel ein relativer Pfad ist, relativ zu DIR auflösen
  [[ "$TARGET" != /* ]] && TARGET="$DIR/$TARGET"
  SOURCE="$TARGET"
done
# Jetzt ist SOURCE eine echte Datei; ihr Verzeichnis ist das cli/-Verzeichnis.
DIR="$(cd -P "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd)"
# WGX_DIR zeigt auf Repo-Root (eine Ebene über cli/)
WGX_DIR="$(cd -P "$DIR/.." >/dev/null 2>&1 && pwd)"
export WGX_DIR

# Version anzeigen, bevor weitere Komponenten geladen werden
__WGX_VERSION__="2.0.3"
export WGX_VERSION="$__WGX_VERSION__"
case "${1:-}" in
--version | -V)
  echo "wgx ${__WGX_VERSION__}"
  exit 0
  ;;
esac

# libs laden (alphabetisch hält Ordnung)
if [ -d "$WGX_DIR/lib" ]; then
  for f in "$WGX_DIR/lib/"*.bash; do
    if [ -r "$f" ]; then
      if [[ ${WGX_DEBUG:-0} != 0 ]]; then
        echo "Loading library: $f" >&2
      fi
      if ! source "$f"; then
        echo "Error: Failed to source library file: $f" >&2
        exit 1
      fi
    fi
  done
fi

# Default-Branch / Basis für Reload
: "${WGX_BASE:=main}"

# Haupteinstieg
wgx_main "$@"
```
```

### 📄 merges/wgx_merge_2510262237__cmd.md

**Größe:** 47 KB | **md5:** `01d8052dad9c42b9a17686f3a5fd663c`

```markdown
### 📄 cmd/audit.bash

**Größe:** 1 KB | **md5:** `400422108b43d01ccd39522a4c2a438e`

```bash
#!/usr/bin/env bash

if [ -z "${WGX_DIR:-}" ]; then
  WGX_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

if ! declare -F audit::verify >/dev/null 2>&1; then
  # shellcheck disable=SC1090
  source "$WGX_DIR/lib/audit.bash"
fi

cmd_audit() {
  local sub="${1:-}"; shift || true
  case "$sub" in
    verify)
      local strict=0
      while [[ $# -gt 0 ]]; do
        case "$1" in
          --strict)
            strict=1
            ;;
          -h|--help)
            cat <<'USAGE'
Usage:
  wgx audit verify [--strict]

Prüft die Audit-Log-Kette (.wgx/audit/ledger.jsonl). Standardmäßig wird
nur eine Warnung ausgegeben, wenn die Kette beschädigt ist. Mit --strict
(oder AUDIT_VERIFY_STRICT=1) führt eine Verletzung zu einem Fehlercode.
USAGE
            return 0
            ;;
          --)
            shift
            break
            ;;
          --*)
            printf 'wgx audit verify: unknown option %s\n' "$1" >&2
            return 1
            ;;
          *)
            break
            ;;
        esac
        shift || true
      done
      if ((strict)); then
        audit::verify --strict "$@"
      else
        audit::verify "$@"
      fi
      ;;
    -h|--help|help|'')
      cat <<'USAGE'
Usage:
  wgx audit verify [--strict]

Verwaltet das Audit-Ledger von wgx.
USAGE
      ;;
    *)
      printf 'wgx audit: unknown subcommand %s\n' "$sub" >&2
      return 1
      ;;
  esac
}

wgx_command_main() {
  cmd_audit "$@"
}
```

### 📄 cmd/clean.bash

**Größe:** 8 KB | **md5:** `f3867f37418f1ad9446987d5e9dc78ee`

```bash
#!/usr/bin/env bash

cmd_clean() {
  local base_dir="${WGX_DIR:-"$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"}"
  local oldpwd="$PWD"
  if ! cd "$base_dir" >/dev/null 2>&1; then
    die "Clean: Basisverzeichnis '$base_dir' nicht erreichbar."
  fi

  local __cmd_clean_restore_errexit=0
  case $- in
  *e*)
    __cmd_clean_restore_errexit=1
    set +e
    ;;
  esac

  local dry_run=0 safe=0 build=0 git_cleanup=0 deep=0 force=0
  while [ $# -gt 0 ]; do
    case "$1" in
    --safe) safe=1 ;;
    --build) build=1 ;;
    --git) git_cleanup=1 ;;
    --deep) deep=1 ;;
    --dry-run | -n) dry_run=1 ;;
    --force | -f) force=1 ;;
    --help | -h)
      cat <<'USAGE'
Usage:
  wgx clean [--safe] [--build] [--git] [--deep] [--dry-run] [--force]

Options:
  --safe       Entfernt temporäre Cache-Verzeichnisse (Standard).
  --build      Löscht Build-Artefakte (dist, build, target, ...).
  --git        Räumt gemergte Branches und Remote-Referenzen auf (nur sauberer Git-Tree).
  --deep       Führt ein destruktives `git clean -xfd` aus (erfordert --force, nur sauberer Git-Tree).
  --dry-run    Zeigt nur an, was passieren würde.
  --force      Bestätigt destruktive Operationen (für --deep).
USAGE
      cd "$oldpwd" >/dev/null 2>&1 || true
      if [ "$__cmd_clean_restore_errexit" -eq 1 ]; then
        set -e
      fi
      return 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      warn "Unbekannte Option: $1"
      cd "$oldpwd" >/dev/null 2>&1 || true
      if [ "$__cmd_clean_restore_errexit" -eq 1 ]; then
        set -e
      fi
      return 2
      ;;
    *)
      warn "Ignoriere unerwartetes Argument: $1"
      ;;
    esac
    shift || true
  done

  # Standard: ungefährliche Caches
  if [ $safe -eq 0 ] && [ $build -eq 0 ] && [ $git_cleanup -eq 0 ] && [ $deep -eq 0 ]; then
    safe=1
  fi

  local rc=0
  local performed=0
  local skip_cleanup=0

  # Fehler protokollieren (vor erster Nutzung definiert)
  _record_error() {
    local status=${1:-1}
    if [ "$status" -eq 0 ]; then status=1; fi
    if [ $dry_run -eq 1 ]; then
      # Im Dry-Run wird nur der finale RC-Wert beeinflusst,
      # aber kein harter Fehler ausgelöst.
      :
    else
      if [ "$rc" -eq 0 ]; then rc=$status; fi
    fi
  }

  # Für reale Läufe ggf. sauberen Git-Tree verlangen
  local require_clean_tree=0 allow_untracked_dirty=0
  if [ $dry_run -eq 0 ]; then
    [ $git_cleanup -eq 1 ] && require_clean_tree=1
    [ $deep -eq 1 ] && allow_untracked_dirty=1
  fi

  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    local worktree_dirty=0
    if [ $require_clean_tree -eq 1 ]; then
      if git_workdir_dirty; then worktree_dirty=1; fi
    elif [ $allow_untracked_dirty -eq 1 ]; then
      # Nur getrackte Änderungen verhindern Deep-Clean
      if git status --porcelain=v1 --untracked-files=no 2>/dev/null | grep -q .; then
        worktree_dirty=1
      fi
    fi

    if [ $worktree_dirty -eq 1 ]; then
      warn "Git-Arbeitsverzeichnis ist nicht sauber. Bitte committe oder stash deine Änderungen und versuche es erneut."
      local status_output
      status_output="$(git status --short 2>/dev/null || true)"
      if [ -n "$status_output" ]; then
        while IFS= read -r line; do
          [ -n "$line" ] || continue
          printf '    %s\n' "$line" >&2
        done <<<"$status_output"
      fi
      skip_cleanup=1
      [ $dry_run -eq 0 ] && _record_error 1
    fi
  fi

  # --- Helpers ---------------------------------------------------------------

  _remove_path() {
    local target="$1"
    [ -e "$target" ] || return 1
    performed=1
    if [ $dry_run -eq 1 ]; then
      printf 'DRY: rm -rf -- %q\n' "$target"
      return 0
    fi
    rm -rf -- "$target"
  }

  _remove_paths() {
    local desc="$1"
    shift
    local removed_any=0 local_rc=0 status=0 path
    for path in "$@"; do
      if _remove_path "$path"; then
        removed_any=1
      else
        status=$?
        if [ $status -ne 1 ] && [ $local_rc -eq 0 ]; then
          local_rc=$status
          _record_error "$status"
        fi
      fi
    done
    [ $removed_any -eq 1 ] && info "$desc entfernt."
    return "$local_rc"
  }

  # --- Hauptlogik ------------------------------------------------------------

  if [ $skip_cleanup -eq 1 ]; then
    [ $dry_run -eq 1 ] && info "Dry-Run: Bereinigung aufgrund verschmutztem Git-Arbeitsverzeichnis übersprungen."
  else
    # --safe: ungefährliche Caches
    if [ $safe -eq 1 ]; then
      if _remove_paths "Temporäre Caches" \
        .pytest_cache .ruff_cache .mypy_cache .coverage coverage \
        .hypothesis .cache; then :; else
        local status=$?
        if [ $status -ne 0 ]; then
          [ $rc -eq 0 ] && rc=$status
          _record_error "$status"
        fi
      fi

      # alte wgx-Logs im TMP
      if [ $dry_run -eq 1 ]; then
        printf 'DRY: find "%s" -maxdepth 1 -type f -name %q -mtime +1 -delete\n' "${TMPDIR:-/tmp}" 'wgx-*.log'
      else
        find "${TMPDIR:-/tmp}" -maxdepth 1 -type f -name 'wgx-*.log' -mtime +1 -exec rm -f -- {} + 2>/dev/null || true
      fi
    fi

    # --git: gemergte Branches + prune origin
    if [ $git_cleanup -eq 1 ]; then
      if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        local git_performed=0
        local current_branch
        current_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"
        local branch
        while IFS= read -r branch; do
          [ -n "$branch" ] || continue
          case "$branch" in "$current_branch" | main | master | dev) continue ;; esac
          git_performed=1
          if [ $dry_run -eq 1 ]; then
            printf 'DRY: git branch -d -- %q\n' "$branch"
          else
            git branch -d "$branch" >/dev/null 2>&1 || true
          fi
        done < <(git for-each-ref --format='%(refname:short)' --merged 2>/dev/null)

        if git remote | grep -qx 'origin'; then
          git_performed=1
          if [ $dry_run -eq 1 ]; then
            echo 'DRY: git remote prune origin'
          else
            git remote prune origin >/dev/null 2>&1 || true
          fi
        fi

        [ $git_performed -eq 1 ] && performed=1
      else
        if [ $dry_run -eq 1 ]; then
          info "--git übersprungen (kein Git-Repository, Dry-Run)."
        else
          warn "--git verlangt ein Git-Repository."
          _record_error 1
        fi
      fi
    fi

    # --build: Build-/Tool-Artefakte
    if [ $build -eq 1 ]; then
      if _remove_paths "Build-Artefakte" \
        build dist target .tox .nox .venv .uv .pdm-build node_modules/.cache; then :; else
        local status=$?
        if [ $status -ne 0 ]; then
          [ $rc -eq 0 ] && rc=$status
          _record_error "$status"
        fi
      fi

      if [ $dry_run -eq 1 ]; then
        printf 'DRY: find . -maxdepth 1 -type d -name %q -exec rm -rf -- {} +\n' '*.egg-info'
      else
        find . -maxdepth 1 -type d -name '*.egg-info' -exec rm -rf -- {} + 2>/dev/null || true
      fi
    fi

    # --deep: destruktiver Git-Clean
    if [ $deep -eq 1 ]; then
      if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        if [ $dry_run -eq 1 ]; then
          git clean -nfxd || true # Simulation, Dry-Run bleibt grün
        else
          if [ $force -eq 0 ]; then
            warn "--deep ist destruktiv und benötigt --force."
            _record_error 1
          else
            if ! git clean -xfd; then
              local clean_status=$?
              rc=$clean_status
              _record_error "$clean_status"
            fi
          fi
        fi
        performed=1
      else
        if [ $dry_run -eq 1 ]; then
          info "--deep übersprungen (kein Git-Repository, Dry-Run)."
        else
          warn "--deep verlangt ein Git-Repository."
          _record_error 1
        fi
      fi
    fi
  fi

  cd "$oldpwd" >/dev/null 2>&1 || true

  if [ $dry_run -eq 1 ]; then
    # Dry-Run: nie als Fehler enden (Tests erwarten Exit 0)
    info "Clean (Dry-Run) abgeschlossen."
    if [ "$__cmd_clean_restore_errexit" -eq 1 ]; then
      set -e
    fi
    return 0
  fi

  if [ "$rc" -eq 0 ]; then
    if [ $performed -eq 0 ]; then
      info "Nichts zu tun."
    else
      ok "Clean abgeschlossen."
    fi
  fi
  if [ "$__cmd_clean_restore_errexit" -eq 1 ]; then
    set -e
  fi
  return "$rc"
}

clean_cmd() {
  cmd_clean "$@"
}

wgx_command_main() {
  cmd_clean "$@"
}
```

### 📄 cmd/config.bash

**Größe:** 668 B | **md5:** `2f58055472bf7ea39fd2f370965f8c3f`

```bash
#!/usr/bin/env bash

cmd_config() {
  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    cat <<'USAGE'
Usage:
  wgx config [show]
  wgx config set <KEY>=<VALUE>

Description:
  Zeigt die aktuelle Konfiguration an oder setzt einen Wert in der
  '.wgx.conf'-Datei.
  Die Implementierung dieses Befehls ist noch in Arbeit.

Options:
  -h, --help    Diese Hilfe anzeigen.
USAGE
    return 0
  fi

  echo "FEHLER: Der 'config'-Befehl ist noch nicht vollständig implementiert." >&2
  echo "Eine Beschreibung der geplanten Funktionalität finden Sie in 'docs/Command-Reference.de.md'." >&2
  return 1
  # config_cmd "$@"
}

wgx_command_main() {
  cmd_config "$@"
}
```

### 📄 cmd/doctor.bash

**Größe:** 56 B | **md5:** `3ae517fcd9e460cfd239d3dff625a848`

```bash
#!/usr/bin/env bash

cmd_doctor() {
  doctor_cmd "$@"
}
```

### 📄 cmd/env.bash

**Größe:** 89 B | **md5:** `ea8e70510668067898a7db90188a693f`

```bash
#!/usr/bin/env bash

cmd_env() {
  env_cmd "$@"
}

wgx_command_main() {
  cmd_env "$@"
}
```

### 📄 cmd/guard.bash

**Größe:** 1 KB | **md5:** `41e09572c0137fdc30de9e93309d8cf2`

```bash
#!/usr/bin/env bash

if [ -z "${WGX_DIR:-}" ]; then
  WGX_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

if ! declare -F audit::log >/dev/null 2>&1; then
  # shellcheck disable=SC1090
  source "$WGX_DIR/lib/audit.bash"
fi

if ! declare -F hauski::emit >/dev/null 2>&1; then
  # shellcheck disable=SC1090
  source "$WGX_DIR/lib/hauski.bash"
fi

cmd_guard() {
  local -a args=("$@")
  local payload_start payload_finish
  if command -v python3 >/dev/null 2>&1; then
    payload_start=$(python3 - "${args[@]}" <<'PY'
import json
import sys
print(json.dumps({"args": list(sys.argv[1:]), "phase": "start"}))
PY
)
  else
    payload_start="{\"phase\":\"start\"}"
  fi
  audit::log "guard_start" "$payload_start" || true
  hauski::emit "guard.start" "$payload_start" || true

  guard_run "${args[@]}"
  local rc=$?

  if command -v python3 >/dev/null 2>&1; then
    payload_finish=$(python3 - "$rc" <<'PY'
import json
import sys
print(json.dumps({"status": "ok" if int(sys.argv[1]) == 0 else "error", "exit_code": int(sys.argv[1])}))
PY
)
  else
    local status_word
    if ((rc == 0)); then
      status_word="ok"
    else
      status_word="error"
    fi
    printf -v payload_finish '{"status":"%s","exit_code":%d}' "$status_word" "$rc"
  fi
  audit::log "guard_finish" "$payload_finish" || true
  hauski::emit "guard.finish" "$payload_finish" || true
  return $rc
}
```

### 📄 cmd/heal.bash

**Größe:** 747 B | **md5:** `c47850477e5a749feb2c04f401c921df`

```bash
#!/usr/bin/env bash

cmd_heal() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    cat <<'USAGE'
Usage:
  wgx heal [ours|theirs|ff-only|--continue|--abort]

Description:
  Hilft bei der Lösung von Merge- oder Rebase-Konflikten.
  Die vollständige Implementierung dieses Befehls ist noch in Arbeit.
  Für eine detaillierte Beschreibung der geplanten Funktionalität,
  siehe 'docs/Command-Reference.de.md'.

Options:
  -h, --help    Diese Hilfe anzeigen.
USAGE
    return 0
  fi

  echo "FEHLER: Der 'heal'-Befehl ist noch nicht vollständig implementiert." >&2
  echo "Eine Beschreibung der geplanten Funktionalität finden Sie in 'docs/Command-Reference.de.md'." >&2
  return 1
  # heal_cmd "$@"
}

wgx_command_main() {
  cmd_heal "$@"
}
```

### 📄 cmd/hooks.bash

**Größe:** 702 B | **md5:** `889171f2e0b585db2e14f60f5487666b`

```bash
#!/usr/bin/env bash

cmd_hooks() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    cat <<'USAGE'
Usage:
  wgx hooks [install]

Description:
  Verwaltet die Git-Hooks für das Repository.
  Die vollständige Implementierung dieses Befehls ist noch in Arbeit.
  Aktuell ist nur die 'install'-Aktion geplant.
  Für Details, siehe 'docs/Command-Reference.de.md'.

Options:
  -h, --help    Diese Hilfe anzeigen.
USAGE
    return 0
  fi

  echo "FEHLER: Der 'hooks'-Befehl ist noch nicht vollständig implementiert." >&2
  echo "Eine Beschreibung der geplanten Funktionalität finden Sie in 'docs/Command-Reference.de.md'." >&2
  return 1
  # hooks_cmd "$@"
}

wgx_command_main() {
  cmd_hooks "$@"
}
```

### 📄 cmd/init.bash

**Größe:** 1 KB | **md5:** `f0320e38342437cafd894ee4ce569c14`

```bash
#!/usr/bin/env bash

cmd_init() {
  local wizard=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --wizard)
        wizard=1
        ;;
      -h|--help)
        cat <<'USAGE'
Usage:
  wgx init [--wizard]

Description:
  Initialisiert die 'wgx'-Konfiguration im Repository. Mit `--wizard` wird
  ein interaktiver Assistent gestartet, der `.wgx/profile.yml` erstellt.

Options:
  --wizard      Interaktiven Profil-Wizard starten.
  -h, --help    Diese Hilfe anzeigen.
USAGE
        return 0
        ;;
      --)
        shift
        break
        ;;
      --*)
        printf 'Unknown option: %s\n' "$1" >&2
        return 1
        ;;
      *)
        break
        ;;
    esac
    shift || true
  done

  if ((wizard)); then
    "$WGX_DIR/cmd/init/wizard.sh"
    return $?
  fi

  echo "FEHLER: Der 'init'-Befehl ist noch nicht vollständig implementiert." >&2
  echo "Eine Beschreibung der geplanten Funktionalität finden Sie in 'docs/Command-Reference.de.md'." >&2
  return 1
}

wgx_command_main() {
  cmd_init "$@"
}
```

### 📄 cmd/lint.bash

**Größe:** 2 KB | **md5:** `33cd0ac81eee3c58bcd0991d37ef6f4b`

```bash
#!/usr/bin/env bash

cmd_lint() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    cat <<'USAGE'
Usage:
  wgx lint

Description:
  Führt Linting-Prüfungen für verschiedene Dateitypen im Repository aus.
  Dies umfasst Shell-Skripte (Syntax-Prüfung mit bash -n, Formatierung mit shfmt,
  statische Analyse mit shellcheck) und potenziell weitere linter.

Options:
  -h, --help    Diese Hilfe anzeigen.
USAGE
    return 0
  fi

  local base_dir="${WGX_DIR:-"$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"}"
  local oldpwd="$PWD"
  if ! cd "$base_dir" >/dev/null 2>&1; then
    die "Lint: Basisverzeichnis '$base_dir' nicht erreichbar."
  fi

  local -a shell_files=()

  if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    while IFS= read -r -d '' file; do
      shell_files+=("$file")
    done < <(git ls-files -z -- '*.sh' '*.bash' 'wgx' 'cli/wgx')
  else
    while IFS= read -r -d '' file; do
      case "$file" in
      ./*) shell_files+=("${file#./}") ;;
      *) shell_files+=("$file") ;;
      esac
    done < <(find . -type f \( -name '*.sh' -o -name '*.bash' -o -name 'wgx' -o -path './cli/wgx' \) -print0)
  fi

  if [ ${#shell_files[@]} -eq 0 ]; then
    warn "No shell scripts found to lint."
    if ! cd "$oldpwd" >/dev/null 2>&1; then
      warn "Failed to return to original directory '$oldpwd'."
    fi
    return 0
  fi

  local rc=0

  if command -v bash >/dev/null 2>&1; then
    if [ ${#shell_files[@]} -ne 0 ]; then
      if ! bash -n "${shell_files[@]}"; then
        rc=1
      fi
    fi
  else
    warn "bash not found, skipping syntax check."
  fi

  if command -v shfmt >/dev/null 2>&1; then
    if ! shfmt -d "${shell_files[@]}"; then
      rc=1
    fi
  else
    warn "shfmt not found, skipping formatting check."
  fi

  if command -v shellcheck >/dev/null 2>&1; then
    local -a shellcheck_args=(--severity=style --shell=bash --external-sources --format=gcc)
    if ! shellcheck "${shellcheck_args[@]}" "${shell_files[@]}"; then
      rc=1
    fi
  else
    warn "shellcheck not found, skipping lint step."
  fi

  cd "$oldpwd" >/dev/null 2>&1 || true
  return $rc
}

lint_cmd() {
  cmd_lint "$@"
}

wgx_command_main() {
  cmd_lint "$@"
}
```

### 📄 cmd/quick.bash

**Größe:** 2 KB | **md5:** `5e024ac522df873835c5ad326a9d2198`

```bash
#!/usr/bin/env bash

_quick_usage() {
  cat <<'USAGE'
Usage: wgx quick [-i|--interactive] [--help]

Run repository guards (lint + tests) and open the PR/MR helper.

Options:
  -i, --interactive  Open the PR body in $EDITOR before sending
  -h, --help         Show this help message
USAGE
}

_quick_require_repo() {
  if ! command -v git >/dev/null 2>&1; then
    die "quick: git is not installed."
  fi
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    die "quick: not inside a git repository."
  fi
}

_quick_guard_available() {
  declare -F guard_run >/dev/null 2>&1
}

_quick_send_available() {
  declare -F send_cmd >/dev/null 2>&1
}

cmd_quick() {
  local interactive=0

  while (($#)); do
    case "$1" in
    -i | --interactive)
      interactive=1
      ;;
    -h | --help)
      _quick_usage
      return 0
      ;;
    --)
      shift || true
      break
      ;;
    *)
      die "Usage: wgx quick [-i|--interactive]"
      ;;
    esac
    shift || true
  done

  _quick_require_repo

  local guard_status=0
  if _quick_guard_available; then
    guard_run --lint --test || guard_status=$?
  else
    warn "guard command not available; skipping lint/test checks."
  fi

  if ((guard_status > 1)); then
    return $guard_status
  fi


<<TRUNCATED: max_file_lines=800>>
```

### 📄 merges/wgx_merge_2510262237__cmd_init.md

**Größe:** 3 KB | **md5:** `75cbfe47113ef2ebe50f8eae7f12560c`

```markdown
### 📄 cmd/init/wizard.sh

**Größe:** 3 KB | **md5:** `0f55058762da4367631b7a10e30679a7`

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
WGX_BIN="${WGX_DIR:-$REPO_DIR}/wgx"
PROFILE_DIR="$REPO_DIR/.wgx"
PROFILE_PATH="$PROFILE_DIR/profile.yml"

mkdir -p "$PROFILE_DIR"

if [[ -f "$PROFILE_PATH" ]]; then
  read -rp "Es existiert bereits ein .wgx/profile.yml. Überschreiben? [y/N] " answer
  case "${answer:-}" in
    y|Y|yes|YES) ;;
    *) echo "Abgebrochen."; exit 0 ;;
  esac
fi

read -rp "Repository-Typ [generic]: " repo_kind
repo_kind=${repo_kind:-generic}
read -rp "Bevorzugter Env-Manager (z. B. uv/pip/npm) [system]: " env_prefer
env_prefer=${env_prefer:-system}

declare -a selected_tasks=()
declare -A task_cmd=()
declare -A task_args=()
declare -A task_safe=()

declare -a default_tasks=(test lint build)
for task in "${default_tasks[@]}"; do
  read -rp "Befehl für Task '${task}' (leer zum Überspringen): " cmd
  if [[ -z "$cmd" ]]; then
    continue
  fi
  read -rp "Argumente für '${task}' (Leerzeichen getrennt, leer für keine): " arg_line
  read -rp "Als 'safe' markieren? [Y/n]: " safe_answer
  case "${safe_answer:-}" in
    n|N|no|NO) safe=false ;;
    *) safe=true ;;
  esac
  selected_tasks+=("$task")
  task_cmd["$task"]="$cmd"
  task_args["$task"]="$arg_line"
  task_safe["$task"]="$safe"
done

if ((${#selected_tasks[@]} == 0)); then
  echo "Keine Tasks ausgewählt – breche ab." >&2
  exit 1
fi

yaml_escape() {
  local input="$1"
  local dq='"'
  input=${input//\\/\\\\}
  input=${input//${dq}/\"}
  printf '%s' "$input"
}

format_args() {
  local line="$1"
  if [[ -z "$line" ]]; then
    printf '[]'
    return
  fi
  local -a items
  read -r -a items <<<"$line"
  printf '['
  local first=1
  local item
  for item in "${items[@]}"; do
    if ((first)); then
      first=0
    else
      printf ', '
    fi
    printf '"%s"' "$(yaml_escape "$item")"
  done
  printf ']'
}

tmp_file="$(mktemp)"
trap 'rm -f "$tmp_file"' EXIT

{
  printf 'wgx:\n'
  printf '  apiVersion: v1.1\n'
  printf '  repoKind: "%s"\n' "$(yaml_escape "$repo_kind")"
  printf '  envDefaults:\n'
  printf '    WGX_ENV_PREFER: "%s"\n' "$(yaml_escape "$env_prefer")"
  printf '  tasks:\n'
  for task in "${selected_tasks[@]}"; do
    printf '    %s:\n' "$task"
    printf '      desc: "%s"\n' "$(yaml_escape "Wizard task: $task")"
    printf '      safe: %s\n' "${task_safe[$task]}"
    printf '      cmd: "%s"\n' "$(yaml_escape "${task_cmd[$task]}")"
    printf '      args: %s\n' "$(format_args "${task_args[$task]}")"
  done
} >"$tmp_file"

mv "$tmp_file" "$PROFILE_PATH"
trap - EXIT

if "$WGX_BIN" validate >/dev/null 2>&1; then
  echo "Profil erfolgreich erstellt: $PROFILE_PATH"
else
  echo "wgx validate meldete Fehler:" >&2
  "$WGX_BIN" validate || true
  echo "Diff (neu erzeugte Datei):" >&2
  diff -u /dev/null "$PROFILE_PATH" || true
  exit 1
fi
```
```

### 📄 merges/wgx_merge_2510262237__docs.md

**Größe:** 72 KB | **md5:** `47ab62277da060537db818c117ce4223`

```markdown
### 📄 docs/.gitkeep

**Größe:** 0 B | **md5:** `d41d8cd98f00b204e9800998ecf8427e`

```plaintext

```

### 📄 docs/ADR-0001__central-cli-contract.de.md

**Größe:** 2 KB | **md5:** `d314d8eb7ce8f693bc874ea680b879a8`

```markdown
# ADR-0001: Zentrales CLI-Contract

> Englische Version: [ADR-0001__central-cli-contract.en.md](ADR-0001__central-cli-contract.en.md)

## Status

Akzeptiert

## Kontext

Die wgx-Toolchain unterstützt mehrere Projekte und Arbeitsplätze. Bisher existierten unterschiedliche Varianten des
CLI-Vertrags (Command Line Interface Contract) in einzelnen Repositories, was zu inkonsistentem Verhalten und
wiederholtem Abstimmungsaufwand führte. Neue Funktionen mussten mehrfach dokumentiert und abgestimmt werden, und
automatisierte Tests konnten nicht zuverlässig wiederverwendet werden. Darüber hinaus nutzen Mitarbeiter verschiedene
Entwicklungsumgebungen (Termux, VS Code Remote, klassische Linux-Setups), wodurch Abweichungen in der CLI-Konfiguration
schnell zu Fehlern führen.

## Entscheidung

Wir etablieren einen zentral gepflegten CLI-Contract innerhalb von wgx. Der Contract wird in `docs` versioniert,
beschreibt erwartete Befehle, Konfigurationsdateien (z. B. `profile.yml`) und deren Schnittstellen, und dient als
Referenz für alle abhängigen Projekte. Änderungen am Contract erfolgen über Pull Requests inklusive ADR-Aktualisierung,
wodurch Transparenz und Nachvollziehbarkeit gewährleistet werden.

## Konsequenzen

- Einheitliches Verhalten: Alle Projekte orientieren sich am selben Contract und können kompatible Tooling-Skripte
  bereitstellen.
- Geringerer Abstimmungsaufwand: Dokumentation, Tests und Runbooks müssen nur einmal gepflegt werden.
- Schnellere Onboarding-Prozesse: Neue Teammitglieder erhalten eine zentrale Referenz.
- Höhere Wartbarkeit: Inkompatible Änderungen werden frühzeitig erkannt, weil sie über den zentralen Contract
  abgestimmt werden müssen.

## Offene Fragen

- Wie werden ältere Projekte migriert, die noch eigene CLI-Definitionen haben?
- Welche automatisierten Validierungen sollen beim Ändern des Contracts verpflichtend sein?
```

### 📄 docs/ADR-0002__python-env-manager-uv.de.md

**Größe:** 2 KB | **md5:** `4d448ba977e204c71386ce61d1c75a38`

```markdown
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

wgx bietet dafür Wrapper-Kommandos (`wgx py up`, `wgx py sync`, `wgx py run`, `wgx tool add`). Repository-Profile können per `.wgx/profile.yml` alternative Manager deklarieren, fallen aber standardmäßig auf uv zurück.

## Konsequenzen

- Reproduzierbare Umgebungen: `uv.lock` ist verpflichtender Bestandteil im Versionskontrollsystem.
- CI-Pipelines installieren uv einmalig und verwenden `uv sync --frozen` plus `uv run` für Testläufe.
- Entwickler:innen benötigen nur ein Binary; Startzeiten in Devcontainern/Termux sinken erheblich.
- Bestehende Workflows mit `requirements.txt` können schrittweise migriert werden (`uv pip sync`, `uv pip compile`).

## Risiken / Mitigations

- **Disziplin beim Lockfile**: Änderungen müssen via `wgx py sync` und committedem `uv.lock` erfolgen. wgx-Contracts prüfen dies.
- **Koexistenz mit Legacy-Tools**: uv überschreibt keine Fremdinstallationen ohne `--force`. Dokumentation weist auf uv als Owner hin.
- **Schulungsbedarf**: Kurzreferenzen in README/Runbook erläutern neue Kommandos und Migrationspfade.
```

### 📄 docs/Command-Reference.de.md

**Größe:** 9 KB | **md5:** `f1ccd704b80a4760f333868f4c61b604`

```markdown
# Befehlsreferenz für `wgx`

Diese Übersicht fasst die wichtigsten Subcommands zusammen, inklusive Zweck und zentraler Optionen. Die Beschreibungen basieren auf dem aktuellen Stand der Skripte unter `cmd/` sowie den portierten Funktionen aus `archiv/wgx`.

> ⚠️ **Umbau-Hinweis:** Einige Kommandos – insbesondere `wgx quick`, `wgx hooks` sowie der `wgx version`/`wgx release`-Pfad – befinden sich in aktiver Überarbeitung. Sie sind funktional, können aber kurzfristig Breaking Changes oder erweiterte Optionen erhalten. Kennzeichnungen erfolgen in den jeweiligen Abschnitten.

## Schnellüberblick

| Kommando | Kurzbeschreibung |
| --- | --- |
| `wgx status` | Zeigt Branch, Ahead/Behind sowie erkannte Projektpfade an. |
| `wgx sync` | Staged/committet Änderungen, führt Rebase & Push aus. |
| `wgx send` | Erstellt PR/MR nach Guard-Checks und Sync. |
| `wgx guard` | Führt Sicherheitsprüfungen (Secrets, Lint, Tests) aus. |
| `wgx heal` | Räumt Rebase-/Merge-Konflikte auf oder holt Updates nach. |
| `wgx clean` | Bereinigt Workspace, Build-Artefakte und ggf. Git-Branches. |
| `wgx doctor` | Diagnostik (Status, Tools, optional Clean/Heal-Abkürzungen). |
| `wgx lint` / `wgx test` | Lint- bzw. Test-Läufe für alle erkannten Teilprojekte. |
| `wgx start` | Legt Feature-Branches nach Naming-Guard an. |
| `wgx release` / `wgx version` | Versionierung und Release-Automation *(Umbau, Funktionsumfang variiert)*. |
| `wgx env doctor` | Plattformabhängiger Umgebungscheck (Termux-Fokus). |
| `wgx quick` | Pipeline aus Guard → Sync → PR/MR inklusive CI-Trigger *(Preview)*. |
| `wgx task(s)` | Liest Tasks aus `.wgx/profile.yml` und führt sie aus. |
| `wgx config` | Zeigt bzw. setzt Werte in `.wgx.conf`. |
| `wgx selftest` | Verifiziert Basisfunktionalität des CLI. |

## Detailbeschreibungen

### `wgx status`
- **Zweck:** Kompakter Snapshot von Branch, Ahead/Behind zum Basis-Branch, erkannte Web/API-Verzeichnisse und globale Flags.
- **Besonderheiten:** Funktioniert auch außerhalb von Git-Repositories und markiert Offline-Modus.

### `wgx sync`
- **Zweck:** Bündelt Commit, optionales Signieren, Rebase auf `origin/$WGX_BASE` und Push.
- **Wichtige Optionen:**
  - `--staged-only` lässt unstaged Dateien unangetastet.
  - `--wip` kennzeichnet Commits mit einem WIP-Präfix.
  - `--amend` hängt an den letzten Commit an.
  - `--scope <name>` setzt den Prefix im Commit-Subject; Standard ist Auto-Erkennung.
  - `--sign` erzwingt signierte Commits.
- **Hinweise:** Offline-Modus überspringt Remote-Operationen und verweist auf `wgx heal`.

### `wgx send`
- **Zweck:** Erstellt Pull/Merge Requests inklusive Body-Rendering und Reviewer-/Label-Logik.
- **Wichtige Optionen:**
  - `--draft` oder automatische Draft-Umschaltung bei Guard-Warnungen.
  - `--scope`, `--title`, `--why`, `--tests`, `--notes` für den PR-Body.
  - `--reviewers auto|foo,bar`, `--label`, `--issue`/`--issues` für Metadaten.
  - `--ci` triggert optionale Workflows (`$WGX_CI_WORKFLOW`).
  - `--open` öffnet den PR/MR im Browser.
  - `--auto-branch` legt bei Bedarf einen Arbeits-Branch auf Basis von `wgx start` an.
- **Besonderheiten:** Erzwingt vorher `wgx guard` und `wgx sync`; unterstützt GitHub (`gh`) und GitLab (`glab`).

### `wgx guard`
- **Zweck:** Sicherheitsnetz vor PRs: sucht nach Secrets, Konfliktmarkern, übergroßen Dateien und prüft Pflichtartefakte.
- **Wichtige Optionen:**
  - `--lint` bzw. `--test` lassen sich einzeln aktivieren; Standard ist beides.
- **Besonderheiten:** Ruft `wgx lint`/`wgx test` nur auf, wenn die Kommandos verfügbar sind.

### `wgx heal`
- **Zweck:** Konfliktlösung oder Rebase-/Merge-Helfer nach fehlgeschlagenem Sync.
- **Wichtige Modi:**
  - Standard/Rebase (ohne Argument) zieht `origin/$WGX_BASE` neu.
  - `ours`, `theirs`, `ff-only` bieten alternative Merge-Strategien.
  - `--continue`/`--abort` steuern laufende Rebase-/Merge-Sessions.
  - `--stash` erstellt vorab ein Snapshot/Stash.

### `wgx reload`
- **Zweck:** Startet eine neue Login-Shell im aktuellen oder im Repo-Root-Kontext.
- **Wichtige Optionen:**
  - `here` (Standard) ersetzt die aktuelle Shell.
  - `root` wechselt ins Repo-Root und startet dort.
  - `new` öffnet eine neue Shell (optional `--tmux`).

### `wgx clean`
- **Zweck:** Entfernt Build- und Cache-Artefakte sowie (optional) gemergte Branches.
- **Wichtige Optionen:**
  - `--safe` (Default) löscht ungefährliche Caches.
  - `--build` räumt Build-Verzeichnisse.
  - `--git` löscht gemergte Branches und pruned Remotes.
  - `--deep` kombiniert `git clean -xfd` (mit Rückfrage, Snapshot-Empfehlung).

### `wgx doctor`
- **Zweck:** Diagnostik-Panel mit Branch-/Tool-Informationen.
- **Unterbefehle:**
  - `clean` zeigt `wgx clean` im Dry-Run und fragt nach Bestätigung.
  - `heal` führt direkt `wgx heal rebase` aus.
- **Ausgabe:** listet u. a. Vale/GitHub/GitLab/Node/Cargo-Versionen, erkennt Offline-Modus.

### `wgx init`
- **Zweck:** Legt `.wgx.conf` sowie PR-Template unter `.wgx/` an, falls fehlend.
- **Besonderheiten:** Verwendet aktuelle Defaults aus den Umgebungseinstellungen.

### `wgx setup`
- **Zweck:** Hilft bei der Erstinstallation – insbesondere unter Termux.
- **Verhalten:** Installiert/prüft Kernpakete (git, gh, glab, jq, vale …) und weist auf fehlende Tools hin; außerhalb Termux dient der Befehl als Checkliste.

### `wgx lint`
- **Zweck:** Aggregiertes Linting für Markdown, Vale, Frontend (Prettier/ESLint), Rust, Shell, Dockerfiles und GitHub Actions.
- **Besonderheiten:** Erkennt Paketmanager automatisch, versucht Offline-Fallbacks, kennzeichnet fehlende Tools als Warnungen.

### `wgx test`
- **Zweck:** Führt parallele Web-Tests (npm/pnpm/yarn) und Rust-Tests (`cargo test`) aus, sofern Verzeichnisse erkannt werden.
- **Hinweis:** Aggregiert Exit-Codes und meldet getrennt Web-/Rust-Fehler.

### `wgx start`
- **Zweck:** Erstellt neue Feature-Branches nach validiertem Slug, optional mit Issue-Präfix.
- **Besonderheiten:** Normalisiert Sonderzeichen, schützt gegen Base-Branch-Missbrauch und fetches vorher den Basisbranch (sofern nicht offline).

### `wgx release`
> **Status:** Funktionsumfang wird aktuell neu strukturiert (Release-Workflows sind im Aufbau).
- **Zweck:** Erstellt SemVer-Tags und (optional) Releases auf GitHub/GitLab.
- **Wichtige Optionen:**
  - `--version vX.Y.Z` oder `--auto-version patch|minor|major` (SemVer-Bump).
  - `--push`, `--sign-tag`, `--latest`, `--allow-prerelease` für erweiterten Release-Flow.
  - `--notes <file>` oder automatische Release Notes aus dem Git-Log.

### `wgx version`
> **Status:** Versionierungspipeline im Umbau, CLI-Optionen können sich kurzfristig ändern.
- **Zweck:** Synchronisiert Projektversionen in `package.json` und `Cargo.toml`.
- **Unterbefehle:**
  - `bump patch|minor|major [--commit]`
  - `set vX.Y.Z [--commit]`
- **Besonderheiten:** Nutzt `jq` bzw. `cargo set-version` wenn verfügbar, fallback auf sed/awk.

### `wgx hooks`
> **Status:** Erweiterte Subcommands sind geplant; derzeit nur Installation verfügbar.
- **Zweck:** Installiert lokale Git-Hooks via `cli/wgx/install.sh`.
- **Unterbefehl:** `install` (weitere Subcommands sind aktuell nicht implementiert).

### `wgx env doctor`
- **Zweck:** Prüft Umgebungen, insbesondere Termux, auf notwendige Pakete.
- **Optionen:**
  - `--fix` schlägt Termux-spezifische Remediations (Storage, Paketinstallation, `core.filemode`) vor.
- **Generic Mode:** Auf Desktop-Systemen erfolgt eine reine Statusausgabe ohne Fixes.

### `wgx quick`
> **Status:** Preview-Flow, Änderungen an Flags und Ablauffolge möglich.
- **Zweck:** End-to-End-Automation für „Guard → Sync → PR/MR → CI“.
- **Optionen:**
  - `-i`/`--interactive` öffnet den PR-Body im Editor.
- **Besonderheit:** Wandelt Warnungen automatisch in Draft-PRs um.

### `wgx task`
- **Zweck:** Führt einen Task aus `.wgx/profile.yml` aus.
- **Benutzung:** `wgx task <name> [--] [args…]`; benötigt ein geladenes Profil.
- **Manifest:** `tasks.<name>.cmd` kann als Shell-String oder als Array angegeben werden. String-Varianten
  werden unverändert übergeben; optionale `args`-Einträge werden separat gequotet angehängt.
  Array-Kommandos bleiben Listen und werden inklusive `args` als JSON-Payload ausgegeben.

### `wgx tasks`
- **Zweck:** Listet Tasks aus dem Profil.
- **Optionen:**
  - `--json` liefert maschinenlesbare Ausgabe.
  - `--safe` filtert auf Tasks mit `safe: true`.
  - `--groups` gruppiert nach `group`-Metadaten.

### `wgx config`
- **Zweck:** Zeigt oder setzt Schlüssel in `.wgx.conf`.
- **Benutzung:**
  - `wgx config`/`wgx config show` → aktuelle Werte.
  - `wgx config set KEY=VALUE` → persistiert Wert mit sed-basiertem Update.

### `wgx selftest`
- **Zweck:** Mini-Sanity-Check für CLI, Abhängigkeiten und Git-Kontext.
- **Prüft:** Ausführbarkeit von `wgx`, `git`, `jq` usw., sowie das Vorhandensein eines Git-Repos.
```

### 📄 docs/Glossar.de.md

**Größe:** 712 B | **md5:** `54f0588fecc694d2fdc2cf93523202f9`

```markdown
# Glossar

> Englische Version: [Glossary.en.md](Glossary.en.md)

## wgx
Interne Toolchain und Sammel-Repository, das Build-Skripte, Templates und Dokumentation für verbundene Projekte bereitstellt.

## `profile.yml`
Zentrale Konfigurationsdatei, mit der lokale Profile (z. B. für Dev, CI oder spezielle Kunden) gesteuert werden. Sie definiert CLI-Parameter, Umgebungsvariablen und Pfade und dient als Bindeglied zwischen zentralem Contract und projektspezifischen Einstellungen.

## Contract (CLI-Contract)
Vereinbarung über Befehle, Optionen, Dateistrukturen und Seiteneffekte des wgx-CLI. Er legt fest, welche Schnittstellen stabil bleiben müssen, damit abhängige Projekte konsistent arbeiten können.
```

### 📄 docs/Glossary.en.md

**Größe:** 1 KB | **md5:** `0e59f7103d87d0ad7ed5912d978fde16`

```markdown
# Glossary

> Deutsche Version: [Glossar.de.md](Glossar.de.md)

## wgx
Internal toolchain and umbrella repository that delivers build scripts, templates and documentation for the connected projects.

## `profile.yml`
Central configuration file that controls local profiles (e.g. Dev, CI or customer specific setups). It defines CLI parameters, environment variables and paths and therefore ties the central contract to project specific settings.

## Contract (CLI contract)
Agreement about commands, options, directory structures and side effects of the wgx CLI. It defines which interfaces must remain stable so that downstream projects continue to operate consistently.

## Guard checklist
Set of minimal repository requirements (e.g. committed `uv.lock`, presence of `templates/profile.template.yml`, CI workflows) that `wgx guard` verifies before automation tasks are allowed to proceed.

## `wgx send`
High level command that prepares and submits pull or merge requests. It enforces guard checks, pushes the current branch and triggers the appropriate hosting CLI (`gh` or `glab`).
```

### 📄 docs/Language-Policy.md

**Größe:** 2 KB | **md5:** `f57d473c3cba8d169257961c97eb9a58`

```markdown
# Sprach-Policy

Dieses Repository nutzt aktuell **Deutsch** als bevorzugte Sprache für neu hinzukommende
benutzernahe Texte, Dokumentation und Code-Kommentare. Bereits vorhandene Inhalte
in Englisch dürfen bestehen bleiben. Das Team plant mittelfristig eine Umstellung auf
Englisch; bis dahin soll eine konsistente deutschsprachige Oberfläche Reibungen in PR-
Reviews vermeiden.

## Leitlinien

- **Neuer Inhalt**: Verfasse neue Benutzertexte und Dokumentation auf Deutsch. Nutze eine
  klare, gut verständliche Sprache und verzichte auf unnötige Anglizismen.
- **Bestehende englische Passagen**: Lass englische Stellen unverändert, sofern sie nicht
  unmittelbar von deiner Änderung betroffen sind. Falls du sie ohnehin anfasst, darfst du
  sie auf Deutsch übertragen.
- **CLI-Ausgaben & Skripte**: Richte neue Meldungen auf Deutsch aus. Bei bestehenden
  englischen Meldungen gilt die gleiche Regel wie oben: nur bei inhaltlichen Änderungen
  eindeutschen.
- **Commits & PRs**: Verwende nach Möglichkeit ebenfalls Deutsch. Stimmen alle Beteiligten
  zu, kann die Kommunikation für einzelne Beiträge auf Englisch erfolgen.

**Hinweis:** Gender-Schreibweisen (z. B. Doppelpunkt, Stern, Binnen-I) sind im gesamten
Repository nicht erlaubt. Nutze stattdessen die klassische Rechtschreibung.

## Übergang zur zukünftigen Englisch-Policy

Damit die spätere Migration zurück zu Englisch planbar bleibt, dokumentiere größere
Änderungen weiterhin so, dass sie leicht übersetzbar sind (z. B. klare Struktur,
sprechende Variablen). Sobald die Umstellung startet, wird diese Policy entsprechend
aktualisiert und vorhandene Texte sukzessive migriert.
```

### 📄 docs/Leitlinie.Quoting.de.md

**Größe:** 2 KB | **md5:** `38cffcd1d926aac0dee70c60c622906e`

```markdown
# Leitlinie: Shell-Quoting

Diese Leitlinie definiert einen verpflichtenden Grundstock für sicheres
Quoting in allen Bash-Skripten des Repositories. Sie ergänzt ShellCheck und
shfmt, ersetzt sie aber nicht.

## Zielsetzung

- **Vermeidung von Word-Splitting und Globbing:** Unkontrollierte
  Parameter-Expansion darf keine zusätzlichen Argumente erzeugen.
- **Stabile Übergabe von Daten:** Ausgaben von Subkommandos werden immer als
  ganze Zeichenketten übergeben.
- **Reproduzierbare Linter-Ergebnisse:** ShellCheck bleibt Referenz für neue
  Regeln; diese Leitlinie legt das Minimum fest, bevor ShellCheck greift.

## Baseline-Regeln

1. **Alle Variablen-Expansions quoten** – selbst bei offensichtlichen Fällen.
   ```bash
   printf '%s\n' "${repo_root}"
   mapfile -t lines < <(git status --short)
   ```
2. **Arrays immer mit `[@]` und Quotes verwenden.**
   ```bash
   for path in "${files[@]}"; do
     printf '→ %s\n' "$path"
   done
   ```
3. **Command-Substitutions sofort quoten.**
   ```bash
   latest_tag="$(git describe --tags --abbrev=0)"
   ```
4. **`printf` statt `echo` für kontrollierte Ausgaben nutzen.** So bleiben
   Backslashes, führende Bindestriche oder `-n` wörtlich erhalten.
5. **`read` nur mit `-r` verwenden.** Damit werden Backslashes nicht
   interpretiert:
   ```bash
   while IFS= read -r line; do
     printf '%s\n' "$line"
   done <"$file"
   ```
6. **Pfadangaben vor Globbing schützen.** Vor dem Gebrauch `set -f` bzw.
   `noglob` oder frühzeitig quoten:
   ```bash
   cp -- "$src" "$dst"
   ```
7. **Keine nackten `eval`-Aufrufe.** Falls unvermeidbar: dokumentieren,
   Eingabe vorher streng validieren.

## Überprüfung

- ShellCheck muss ohne Ignorieren von Quoting-Warnungen (`SC2086`, `SC2046`,
  `SC2016`, …) bestehen.
- shfmt darf keine Änderungen an bereits formatierten Quoting-Blöcken vornehmen.
- Neue Shell-Komponenten liefern einen kurzen Selfcheck (`wgx lint`) vor dem
  Commit.

## Quick-Check

Vor jedem Commit folgende Fragen beantworten:

- Sind alle Expansions (Variablen, Command-Substitutions, Pfade) gequotet?
- Wird beim Iterieren über Arrays `"${array[@]}"` benutzt?
- Besteht `wgx lint` ohne neue ShellCheck-Ausnahmen?

Wenn eine dieser Fragen mit „nein“ beantwortet wird, muss der Code nachgebessert
werden.
```

### 📄 docs/Module-Uebersicht.de.md

**Größe:** 2 KB | **md5:** `f2510e4c1e4f2b63ef52f8b28b05b120`

```markdown
# Module & Hilfsbibliotheken

Kurze Übersicht über die wichtigsten Dateien in `modules/`, `lib/`, `etc/` und `templates/`, damit Beitragende schneller die richtigen Einstiegspunkte finden.

## `modules/`

| Datei | Zweck |
| --- | --- |
| `modules/doctor.bash` | Enthält den Minimal-Doctor (Repo-Prüfung, Remote-Checks). Wird aktuell vom Legacy-Monolithen gerufen. |
| `modules/env.bash` | Neues Environment-Modul mit JSON/strict-Ausgaben sowie Termux-Fixups. Setzt `env_cmd` für `wgx env`. |
| `modules/guard.bash` | Port der Guard-Pipeline (Secrets, Konflikte, Pflichtdateien, optional Lint/Test). Wird von `wgx guard` sowie `wgx send`/`wgx quick` verwendet. |
| `modules/json.bash` | Hilfsfunktionen für JSON-Ausgabe (u. a. von Profil-/Task-Befehlen). |
| `modules/profile.bash` | Lädt `.wgx/profile.yml`, normalisiert Task-Namen und führt Task-Skripte aus. Grundlage für `wgx task`/`wgx tasks`. |
| `modules/semver.bash` | SemVer-Bump-Logik (Bump/Set, Tag-Parsing) für `wgx version` & `wgx release`. |
| `modules/status.bash` | Liefert Status-Zusammenfassungen, z. B. Ahead/Behind und Pfad-Erkennung. Wird von `wgx status` genutzt. |
| `modules/sync.bash` | Implementiert `sync_cmd` inklusive Commit-, Rebase- und Push-Flows. |

## `lib/`

| Datei | Zweck |
| --- | --- |
| `lib/core.bash` | Allgemeine Hilfsfunktionen (Logging, Fehlerbehandlung, Pfadauflösung, Snapshot-Logik), die von mehreren Kommandos shared werden. |

## `etc/`

| Datei | Zweck |
| --- | --- |
| `etc/config.example` | Default-Konfiguration, die `wgx init` nach `~/.config/wgx/config` kopiert. Dient als Vorlage für neue Installationen. |
| `etc/profile.example.yml` | Referenz-Profil für Projekte; dokumentiert unterstützte Sektionen (`python`, `contracts`, `tasks`). |

## `templates/`

| Datei | Zweck |
| --- | --- |
| `templates/profile.template.yml` | Minimal-Template, das Projekte in ihre Repositories kopieren sollen. Wird vom Guard als Muss-Kriterium geprüft. |
| `templates/docs/` | Ergänzende Dokumentations-Vorlagen (z. B. für ADRs). |

## Verwandte Artefakte

- `docs/Runbook.*` & `docs/Glossar.*` dienen als Einstiegspunkte für Onboarding und Terminologie (jetzt zweisprachig verfügbar).
- `docs/Command-Reference.de.md` (neu) listet alle Kommandos samt Optionen auf.

Diese Übersicht soll als Navigationshilfe dienen; Detailverhalten findet sich jeweils in den Quellskripten oder in der Befehlsreferenz.
```

### 📄 docs/Runbook.de.md

**Größe:** 4 KB | **md5:** `9a35d64b77627abc8cf384fcc2780f9f`

```markdown
# Runbook: wgx CLI

> Englische Version: [Runbook.en.md](Runbook.en.md)

## Quick-Links

- Contract-Kompatibilität prüfen: `wgx validate`
- Linting ausführen (auch für Git-Hooks): `wgx lint`
- Umgebung diagnostizieren: `wgx doctor`

## Häufige Fehler und Lösungen

### `profile.yml` wird nicht gefunden

- Prüfen, ob das Arbeitsverzeichnis korrekt gesetzt ist (z. B. Projektwurzel).
- Mit `wgx profile list` sicherstellen, dass das Profil geladen werden kann.
- Falls mehrere Profile vorhanden sind, den Pfad per `WGX_PROFILE_PATH` explizit setzen.

### `wgx`-Befehl schlägt mit Python-Fehlern fehl

- `wgx py up` ausführen, damit uv die im Profil hinterlegte Python-Version bereitstellt.
- `wgx py sync` starten, um Abhängigkeiten anhand des `uv.lock`-Files konsistent zu installieren.
- Falls ein Repository noch kein Lockfile besitzt, `uv pip sync requirements.txt` verwenden und anschließend `wgx py sync` etablieren.
- Bei globaler Installation prüfen, ob Version mit zentralem Contract kompatibel ist.

### `sudo apt-get update -y` schlägt mit „unsigned/403 responses" fehl

- Tritt häufig in abgeschotteten Netzen oder nach dem Hinzufügen externer Repositories auf. Prüfe zunächst die Systemzeit und ob ein Proxy/TLS-Intercepter im Einsatz ist (`echo $https_proxy`).
- Alte Paketlisten entfernen und neu herunterladen:

  ```bash
  sudo rm -rf /var/lib/apt/lists/*
  sudo apt-get clean
  sudo apt-get update
  ```

- Für zusätzliche Repositories sicherstellen, dass der passende Signatur-Schlüssel hinterlegt ist (statt `apt-key` den neuen Keyring-Weg nutzen):

  ```bash
  # Beispiel: Docker-Repository hinzufügen
  sudo install -d -m 0755 /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  echo "deb [signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu jammy stable" | sudo tee /etc/apt/sources.list.d/docker.list
  sudo apt-get update
  # Ersetze ggf. 'docker', die URL, 'jammy' (Distribution) und 'stable' (Komponenten) entsprechend deiner Quelle.
  ```

- Bleibt der Fehler bestehen, das Log (`/var/log/apt/term.log`) prüfen. Bei 403-Antworten hilft oft ein Mirror-Wechsel oder das Entfernen veralteter Einträge in `/etc/apt/sources.list.d/`.

### Git-Hooks blockieren Commits

- `wgx lint` manuell ausführen, um Fehler zu sehen.
- Falls Hook veraltet ist, Repository aktualisieren und `wgx setup` erneut laufen lassen.

## Tipps für Termux

- Termux-Repo aktualisieren (`pkg update`), bevor Python/Node installiert wird.
- Essentials installieren: `pkg install jq git python`.
- `uv` als Single-Binary in `$HOME/.local/bin` installieren:

  ```bash
  curl -LsSf https://astral.sh/uv/install.sh | sh
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.profile
  . ~/.profile
  ```

- Danach `wgx py up` ausführen – uv verwaltet Python-Versionen und virtuelle Umgebungen ohne zusätzliche Tools.
- Speicherzugriff auf das Projektverzeichnis gewähren (`termux-setup-storage`).

## Leitfaden: Von `requirements.txt` zu uv

1. Vorhandene Abhängigkeiten synchronisieren:

   ```bash
   uv pip sync requirements.txt
   ```

2. Projektmetadaten definieren (`pyproject.toml`), sofern noch nicht vorhanden.
3. Lockfile erzeugen und ins Repository aufnehmen:

   ```bash
   uv lock
   git add uv.lock
   ```

4. Für CI und lokale Entwickler `wgx py sync` dokumentieren; im Fehlerfall `uv sync --frozen` nutzen.
5. Optional weiterhin Artefakte exportieren (`uv pip compile --output-file requirements.txt`).

## CI mit uv (Kurzüberblick)

- uv installieren (z. B. per `curl -LsSf https://astral.sh/uv/install.sh | sh`).
- Globalen Cache cachen: `~/.cache/uv` mit einem Key aus uv-Version (`uv --version | awk '{print $2}'`) sowie `pyproject.toml` + `uv.lock`.
- Abhängigkeiten strikt via `uv sync --frozen` installieren.
- Tests mit `uv run …` starten (z. B. `uv run pytest -q`).

## Tipps für VS Code (Remote / Dev Containers)

- Die `profile.yml` als Workspace-File markieren, damit Änderungen synchronisiert werden.
- Aufgaben (`wgx`-Tasks) als VS Code Tasks integrieren, um Befehle mit einem Klick zu starten.
- Bei Dev Containers sicherstellen, dass das Volume die `~/.wgx`-Konfiguration persistiert, z. B.:

```json
{
  "mounts": [
    "source=${localEnv:HOME}/.wgx,target=/home/vscode/.wgx,type=bind,consistency=cached"
  ]
}
```
- Nutze `.devcontainer/setup.sh ensure-uv`, damit uv nach dem Container-Start verfügbar ist (inklusive PATH-Anpassung).
```

### 📄 docs/Runbook.en.md

**Größe:** 4 KB | **md5:** `87acec2050c41e882bbbc6389a87fe78`

```markdown
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
```

### 📄 docs/Runbook.md

**Größe:** 589 B | **md5:** `fbb1f67a83985f30f233774081c54515`

```markdown
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

## Troubleshooting
* `wgx selftest` starten; Logs unter `~/.local/state/wgx/`.
```

### 📄 docs/audit-ledger.md

**Größe:** 786 B | **md5:** `d20517eb267e0cf137dd5f960a501b57`

```markdown
# Audit Ledger

`lib/audit.bash` stellt mit `audit::log` und `audit::verify` eine
JSONL-basierte Audit-Kette bereit. Jeder Eintrag enthält UTC-Zeitstempel,
Git-Commit, das Ereignis und optionales Payload-JSON; ein SHA256-Hash schützt
die Verkettung (`prev_hash` → `hash`). Der Befehl `wgx audit verify`
überprüft die Kette und gibt standardmäßig nur Warnungen aus. Mit
`AUDIT_VERIFY_STRICT=1` oder `wgx audit verify --strict` wird ein Fehlerstatus
ausgelöst, wenn die Hash-Kette unterbrochen ist.

Das produktive Ledger lebt unter `.wgx/audit/ledger.jsonl` und wird
automatisch erweitert. Da es sich bei jedem Lauf ändert, ist die Datei von
Git ausgeschlossen. Für Dokumentationszwecke gibt es stattdessen
`docs/audit-ledger.sample.jsonl`, das den Aufbau exemplarisch zeigt.
```

### 📄 docs/audit-ledger.sample.jsonl

**Größe:** 939 B | **md5:** `7d6ace43130a7ad2119e84f9ea8eb4c5`

```plaintext
{"timestamp":"2024-01-01T12:00:00Z","event":"guard_start","git_sha":"0123456789abcdef0123456789abcdef01234567","payload":{"args":["--help"],"phase":"start"},"prev_hash":"0000000000000000000000000000000000000000000000000000000000000000","hash":"d3c8d7cf90be119bb40df6a5b7c11d5a4c6f1aa7da03fbe4b60980b3d3c4a1a0"}
{"timestamp":"2024-01-01T12:00:02Z","event":"guard_finish","git_sha":"0123456789abcdef0123456789abcdef01234567","payload":{"status":"ok","exit_code":0},"prev_hash":"d3c8d7cf90be119bb40df6a5b7c11d5a4c6f1aa7da03fbe4b60980b3d3c4a1a0","hash":"3d3e3a1c27e190aa81a7ed0423161bbd10bfc9972e231e9d86f8a62d0f49ff97"}
{"timestamp":"2024-01-01T12:05:00Z","event":"task_finish","git_sha":"fedcba9876543210fedcba9876543210fedcba98","payload":{"task":"test","status":"error","exit_code":1},"prev_hash":"3d3e3a1c27e190aa81a7ed0423161bbd10bfc9972e231e9d86f8a62d0f49ff97","hash":"4c41a4c9f72367dfefc6c1c9a83063f1ba026af8966a2f7f4eb5b3ddf6e44a35"}
```

### 📄 docs/cli.md

**Größe:** 11 KB | **md5:** `31af02f00311dfdf4655457a9c3fcf88`

```markdown
# wgx CLI Reference

> Generated by `scripts/gen-cli-docs.sh`. Do not edit manually.

## Global usage

```
wgx — Workspace Helper

Usage:
  wgx <command> [args]

Commands:
  audit
  clean
  config
  doctor
  env
  guard
  heal
  help
  hooks
  init
  lint
  quick
  release
  reload
  selftest
  send
  setup
  start
  status
  sync

<<TRUNCATED: max_file_lines=800>>
```

### 📄 merges/wgx_merge_2510262237__docs_archive.md

**Größe:** 32 KB | **md5:** `6a922f0430211f1227c8033fcdf16de9`

```markdown
### 📄 docs/archive/wgx_monolith_20250925T130147Z.md

**Größe:** 43 KB | **md5:** `19200edd8b7a24bb9e9240f43da57080`

```markdown
```bash
#!/usr/bin/env bash
# wgx – Weltgewebe CLI · Termux/WSL/macOS/Linux · origin-first
# Version: v2.0.2
# Lizenz: MIT (projektintern); Autorenteam: weltweberei.org
#
# RC-Codes:
#   0 = OK, 1 = WARN (fortsetzbar), 2 = BLOCKER (Abbruch)
#
# OFFLINE:  deaktiviert Netzwerkaktionen bestmöglich (fetch, npx pulls etc.)
# DRYRUN :  zeigt Kommandos an, führt sie aber nicht aus (wo sinnvoll)

# ─────────────────────────────────────────────────────────────────────────────
# SAFETY / SHELL MODE
# ─────────────────────────────────────────────────────────────────────────────
set -Eeuo pipefail
IFS=$'\n\t'
umask 077
shopt -s extglob nullglob
export LC_ALL=C LANG=C
set -o noclobber
trap 'ec=$?; cmd=$BASH_COMMAND; line=${BASH_LINENO[0]}; fn=${FUNCNAME[1]:-MAIN}; \
      ((ec)) && printf "❌ wgx: Fehler in %s (Zeile %s): %s (exit=%s)\n" \
      "$fn" "$line" "$cmd" "$ec" >&2' ERR

WGX_VERSION="2.0.2"
RC_OK=0; RC_WARN=1; RC_BLOCK=2

if [[ "${1-}" == "--version" || "${1-}" == "-V" ]]; then
  printf "wgx v%s\n" "$WGX_VERSION"; exit 0; fi

# ─────────────────────────────────────────────────────────────────────────────
# LOG / HELPERS
# ─────────────────────────────────────────────────────────────────────────────
_ok()   { printf "✅ %s\n" "$*"; }
_warn() { printf "⚠️  %s\n" "$*" >&2; }
_err()  { printf "❌ %s\n" "$*" >&2; }
info()  { printf "• %s\n"  "$*"; }
die()   { _err "$*"; exit 1; }
ok()    { _ok "$@"; }
warn()  { _warn "$@"; }
logv()  { ((VERBOSE)) && printf "… %s\n" "$*"; }
has()   { command -v "$1" >/dev/null 2>&1; }
trim()     { local s="$*"; s="${s#"${s%%[![:space:]]*}"}"; printf "%s" "${s%"${s##*[![:space:]]}"}"; }
to_lower() { tr '[:upper:]' '[:lower:]'; }
read_prompt(){ local __v="$1"; shift; local q="${1-}"; shift || true; local d="${1-}"; local ans
  if [[ -t 0 && -r /dev/tty ]]; then printf "%s " "$q"; IFS= read -r ans < /dev/tty || ans="$d"
  else ans="$d"; fi; [[ -z "$ans" ]] && ans="$d"; printf -v "$__v" "%s" "$ans"; }

# ─────────────────────────────────────────────────────────────────────────────
# GLOBAL DEFAULTS
# ─────────────────────────────────────────────────────────────────────────────
: "${ASSUME_YES:=0}"; : "${DRYRUN:=0}"; : "${TIMEOUT:=0}"; : "${NOTIMEOUT:=0}"
: "${VERBOSE:=0}"; : "${OFFLINE:=0}"
: "${WGX_BASE:=main}"; : "${WGX_SIGNING:=auto}"
: "${WGX_PREVIEW_DIFF_LINES:=120}"; : "${WGX_PR_LABELS:=}"
: "${WGX_CI_WORKFLOW:=CI}"; : "${WGX_AUTO_BRANCH:=0}"; : "${WGX_PM:=}"

# ─────────────────────────────────────────────────────────────────────────────
# PLATFORM / ENV
# ─────────────────────────────────────────────────────────────────────────────
PLATFORM="linux"
case "$(uname -s 2>/dev/null || echo x)" in
  Darwin) PLATFORM="darwin" ;;
  *)      PLATFORM="linux" ;;
esac
is_wsl(){ uname -r 2>/dev/null | grep -qiE 'microsoft|wsl2?'; }
is_termux(){
  [[ "${PREFIX-}" == *"/com.termux/"* ]] && return 0
  command -v termux-setup-storage >/dev/null 2>&1 && return 0
  return 1
}
is_codespace(){ [[ -n "${CODESPACE_NAME-}" ]]; }

# ─────────────────────────────────────────────────────────────────────────────
# REPO CONTEXT
# ─────────────────────────────────────────────────────────────────────────────
is_git_repo(){ git rev-parse --is-inside-work-tree >/dev/null 2>&1; }
require_repo(){
  has git || die "git nicht installiert."
  is_git_repo || die "Nicht im Git-Repo."
}

_root_resolve(){
  local here="$1"
  if has greadlink; then
    greadlink -f "$here"
  elif has readlink && readlink -f / >/dev/null 2>&1; then
    readlink -f "$here"
  else
    local target="$here" link base
    while link="$(readlink "$target" 2>/dev/null)"; do
      case "$link" in
        /*)
          target="$link"
          ;;
        *)
          base="$(cd "$(dirname "$target")" && pwd -P)"
          target="$base/$link"
          ;;
      esac
    done
    printf "%s" "$target"
  fi
}

ROOT(){
  local here
  here="$(_root_resolve "${BASH_SOURCE[0]}")"
  local fallback
  fallback="$(cd "$(dirname "$here")/.." && pwd -P)"
  local r
  r="$(git -C "${PWD}" rev-parse --show-toplevel 2>/dev/null || true)"
  if [[ -n "$r" ]]; then
    printf "%s" "$r"
  else
    printf "%s" "$fallback"
  fi
}

if r="$(git rev-parse --show-toplevel 2>/dev/null)"; then
  ROOT_DIR="$r"
else
  here="${BASH_SOURCE[0]}"
  base="$(cd "$(dirname "$here")" && pwd -P)"
  if [[ "$(basename "$base")" == "wgx" && "$(basename "$(dirname "$base")")" == "cli" ]]; then
    ROOT_DIR="$(cd "$base/../.." && pwd -P)"
  else
    ROOT_DIR="$(cd "$base/.." && pwd -P)"
  fi
fi

# CONFIG (.wgx.conf)
if [[ -f "$ROOT_DIR/.wgx.conf" ]]; then
  while IFS='=' read -r k v; do
    k="$(trim "$k")"; [[ -z "$k" || "$k" =~ ^# ]] && continue
    if [[ "$k" =~ ^[A-Z0-9_]+$ ]]; then
      v="${v%$'\r'}"
      [[ "$v" == *'$('* || "$v" == *'`'* || "$v" == *$'\0'* ]] \
        && { warn ".wgx.conf: unsicherer Wert für $k ignoriert"; continue; }
      printf -v _sanitized "%s" "$v"; declare -x "$k=$_sanitized"
    else
      warn ".wgx.conf: ungültiger Schlüssel '$k' ignoriert"
    fi
  done < "$ROOT_DIR/.wgx.conf"
fi

# ─────────────────────────────────────────────────────────────────────────────
# PORTABILITY HELPERS
# ─────────────────────────────────────────────────────────────────────────────
file_size_bytes(){ local f="$1" sz=0
  if   stat -c %s "$f" >/dev/null 2>&1; then sz=$(stat -c %s "$f")
  elif stat -f%z "$f" >/dev/null 2>&1;      then sz=$(stat -f%z "$f")
  else sz=$(wc -c < "$f" 2>/dev/null || echo 0); fi
  printf "%s" "$sz"; }

git_supports_magic(){ git -C "$1" ls-files -z -- ':(exclude)node_modules/**' >/dev/null 2>&1; }

mktemp_portable(){ local p="${1:-wgx}"
  if has mktemp; then
    mktemp -t "${p}.XXXXXX" 2>/dev/null || {
      local f="${TMPDIR:-/tmp}/${p}.$$.tmp"
      : > "$f" && printf "%s" "$f"
    }
  else
    local f="${TMPDIR:-/tmp}/${p}.$(date +%s).$$"
    : > "$f" || die "tmp fehlgeschlagen"
    printf "%s" "$f"
  fi
}

now_ts(){ date +"%Y-%m-%d %H:%M"; }

maybe_sign_flag(){ case "${WGX_SIGNING}" in
  off) return 1;; ssh) has git && git config --get gpg.format 2>/dev/null | grep -qi 'ssh' && echo "-S" || return 1;;
  gpg)
    has gpg && echo "-S" || return 1
    ;;
  auto)
    git config --get user.signingkey >/dev/null 2>&1 && echo "-S" || return 1
    ;;
  *) return 1;; esac; }

with_timeout(){ local t="${TIMEOUT:-0}"; (( NOTIMEOUT )) && exec "$@"
  (( t>0 )) && command -v timeout >/dev/null 2>&1 && timeout "$t" "$@" || exec "$@"; }

# ─────────────────────────────────────────────────────────────────────────────
# GIT HELPERS
# ─────────────────────────────────────────────────────────────────────────────
git_branch(){ git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "HEAD"; }
git_in_progress(){ [[ -d .git/rebase-merge || -d .git/rebase-apply || -f .git/MERGE_HEAD ]]; }

_fetch_once(){ [[ -n "${_WGX_FETCH_DONE-}" ]] && return 0; (( OFFLINE )) && { logv "offline: skip fetch"; return 0; }
  if git fetch -q --prune origin 2>/dev/null; then _WGX_FETCH_DONE=1; return 0
  else warn "git fetch origin fehlgeschlagen"; return 1; fi; }

remote_host_path(){ local u; u="$(git remote get-url origin 2>/dev/null || true)"; [[ -z "$u" ]] && { echo ""; return; }
  case "$u" in
    http*://*/*) local rest="${u#*://}"; local host="${rest%%/*}"; local path="${rest#*/}"; echo "$host $path";;
    ssh://git@*/*) local rest="${u#ssh://git@}"; local host="${rest%%/*}"; local path="${rest#*/}"; echo "$host $path";;
    git@*:*/*) local host="${u#git@}"; host="${host%%:*}"; local path="${u#*:}"; echo "$host $path";;
    *) echo "";;
  esac; }

host_kind(){ local hp host; hp="$(remote_host_path || true)"; host="${hp%% *}"
  case "$host" in github.com) echo github;; gitlab.com) echo gitlab;; codeberg.org) echo codeberg;;
  *) if [[ "$host" == *gitea* || "$host" == *forgejo* ]]; then echo gitea; else echo unknown; fi;; esac; }

compare_url(){ local hp host path; hp="$(remote_host_path || true)"; [[ -z "$hp" ]] && { echo ""; return; }
  host="${hp%% *}"; path="${hp#* }"; path="${path%.git}"
  case "$(host_kind)" in github) echo "https://$host/$path/compare/${WGX_BASE}...$(git_branch)";;
  gitlab) echo "https://$host/$path/-/compare/${WGX_BASE}...$(git_branch)";;
  codeberg) echo "https://$host/$path/compare/${WGX_BASE}...$(git_branch)";;
  gitea) echo "https://$host/$path/compare/${WGX_BASE}...$(git_branch)";; *) echo "";; esac; }

git_ahead_behind(){ local b="${1:-$(git_branch)}"
  ((OFFLINE)) || git fetch -q origin "$b" 2>/dev/null || true
  local ab; ab="$(git rev-list --left-right --count "origin/$b...$b" 2>/dev/null || echo "0 0")"
  local behind=0 ahead=0 IFS=' '; read -r behind ahead <<<"$ab" || true
  printf "%s %s\n" "${behind:-0}" "${ahead:-0}"; }

ab_read(){
  local ref="$1" ab
  ab="$(git_ahead_behind "$ref" 2>/dev/null || echo "0 0")"
  set -- $ab
  echo "${1:-0} ${2:-0}"
}

detect_web_dir(){ for d in apps/web web; do [[ -d "$d" ]] && { echo "$d"; return; }; done; echo ""; }
detect_api_dir(){ for d in apps/api api crates; do [[ -f "$d/Cargo.toml" ]] && { echo "$d"; return; }; done; echo ""; }

run_with_files_xargs0(){ local title="$1"; shift; if [[ -t 1 ]]; then info "$title"; fi
  if has xargs; then
    xargs -0 "$@" || return $?
  else
    local buf=() f
    while IFS= read -r -d '' f; do
      buf+=("$f")
    done
    [[ $# -gt 0 ]] && "$@" "${buf[@]}"
  fi
}
# ─────────────────────────────────────────────────────────────────────────────
# STATUS (kompakt)
# ─────────────────────────────────────────────────────────────────────────────
status_cmd(){
  if ! is_git_repo; then
    echo "=== wgx status ==="
    echo "root : $ROOT_DIR"
    echo "repo : (kein Git-Repo)"
    ok "Status OK"
    return $RC_OK
  fi
  local br web api behind=0 ahead=0
  br="$(git_branch)"; web="$(detect_web_dir || true)"; api="$(detect_api_dir || true)"
  local IFS=' '; read -r behind ahead < <(git_ahead_behind "$br") || true
  echo "=== wgx status ==="
  echo "root : $ROOT_DIR"
  echo "branch: $br (ahead:$ahead behind:$behind)  base:$WGX_BASE"
  echo "web  : ${web:-nicht gefunden}"
  echo "api  : ${api:-nicht gefunden}"
  (( OFFLINE )) && echo "mode : offline"
  ok "Status OK"
}

# ─────────────────────────────────────────────────────────────────────────────
# PREFLIGHT / GUARD (inkl. Secrets, Conflicts, Big Files)
# ─────────────────────────────────────────────────────────────────────────────
changed_files_cached(){ require_repo; git diff --cached --name-only -z | tr '\0' '\n' | sed '/^$/d'; }

# NUL-sicher inkl. Renames
changed_files_all(){
  require_repo
  local rec status path
  git status --porcelain -z \
  | while IFS= read -r -d '' rec; do
      status="${rec:0:2}"
      path="${rec:3}"
      if [[ "$status" =~ ^R ]]; then
        IFS= read -r -d '' path || true
      fi
      [[ -n "$path" ]] && printf '%s\n' "$path"
    done
}

auto_scope(){
  local files="$1" major="repo" m_web=0 m_api=0 m_docs=0 m_infra=0 m_devx=0 total=0
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    ((++total))
    case "$f" in
      apps/web/*) ((++m_web));;
      apps/api/*|crates/*) ((++m_api));;
      infra/*|deploy/*) ((++m_infra));;
      scripts/*|wgx|.wgx.conf) ((++m_devx));;
      docs/*|*.md|styles/*|.vale.ini) ((++m_docs));;
    esac
  done <<< "$files"
  (( total==0 )) && { echo "repo"; return; }
  local max=$m_docs; major="docs"
  (( m_web>max ))  && { max=$m_web;  major="web"; }
  (( m_api>max ))  && { max=$m_api;  major="api"; }
  (( m_infra>max ))&& { max=$m_infra; major="infra"; }
  (( m_devx>max )) && { max=$m_devx; major="devx"; }
  (( max * 100 >= 70 * total )) && echo "$major" || echo "meta"
}

validate_base_branch(){
  ((OFFLINE)) && return 0
  git rev-parse --verify "refs/remotes/origin/$WGX_BASE" >/dev/null 2>&1 || {
    warn "Basis-Branch origin/%s fehlt oder ist nicht erreichbar." "$WGX_BASE"
    return 1
  }
}

guard_run(){
  require_repo
  local FIX=0 LINT_OPT=0 TEST_OPT=0 DEEP_SCAN=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --fix) FIX=1;;
      --lint) LINT_OPT=1;;
      --test) TEST_OPT=1;;
      --deep-scan) DEEP_SCAN=1;;
      *) ;;
    esac
    shift || true
  done

  local rc=$RC_OK br; br="$(git_branch)"
  echo "=== Preflight (branch: $br, base: $WGX_BASE) ==="

  _fetch_once || (( rc=rc<RC_WARN ? RC_WARN : rc ))
  validate_base_branch || (( rc=rc<RC_WARN ? RC_WARN : rc ))

  if git_in_progress; then
    echo "[BLOCKER] rebase/merge läuft → wgx heal --continue | --abort"
    rc=$RC_BLOCK
  fi
  [[ "$br" == "HEAD" ]] && { echo "[WARN] Detached HEAD – Branch anlegen."; (( rc==RC_OK )) && rc=$RC_WARN; }

  local behind=0 ahead=0 IFS=' '
  read -r behind ahead < <(git_ahead_behind "$br") || true
  if (( behind>0 )); then
    echo "[WARN] Branch $behind hinter origin/$br → rebase auf origin/$WGX_BASE"
    if (( FIX )); then
      git fetch -q origin "$WGX_BASE" 2>/dev/null || true
      git rebase "origin/$WGX_BASE" || rc=$RC_BLOCK
    fi
    (( rc==RC_OK )) && rc=$RC_WARN
  fi

  # Konfliktmarker in modifizierten Dateien
  local with_markers=""
  while IFS= read -r -d '' f; do
    [[ -z "$f" ]] && continue
    grep -Eq '<<<<<<<|=======|>>>>>>>' -- "$f" 2>/dev/null && with_markers+="$f"$'\n'
  done < <(git ls-files -m -z)
  if [[ -n "$with_markers" ]]; then
    echo "[BLOCKER] Konfliktmarker:"
    printf '%s' "$with_markers" | sed 's/^/  - /'
    rc=$RC_BLOCK
  fi

  # Secret-/Größen-Checks auf staged
  local staged; staged="$(changed_files_cached || true)"
  if [[ -n "$staged" ]]; then
    local secrets
    secrets="$(
      printf "%s\n" "$staged" |
        grep -Ei '\.env(\.|$)|(^|/)(id_rsa|id_ed25519)(\.|$)|\.pem$|\.p12$|\.keystore$' || true
    )"
    if [[ -n "$secrets" ]]; then
      echo "[BLOCKER] mögliche Secrets im Commit (Dateinamen-Match):"
      printf "%s\n" "$secrets" | sed 's/^/  - /'
      if (( FIX )); then
        while IFS= read -r s; do
          [[ -n "$s" ]] && git restore --staged -- "$s" 2>/dev/null || true
        done <<< "$secrets"
        echo "→ Secrets aus dem Index entfernt (Dateien bleiben lokal)."
      fi
      rc=$RC_BLOCK
    fi

    if (( DEEP_SCAN )); then
      local leaked
      local secret_pattern
      secret_pattern='BEGIN (RSA|EC|OPENSSH) PRIVATE KEY'
      secret_pattern+='|AKIA[A-Z0-9]{16}'
      secret_pattern+='|ghp_[A-Za-z0-9]{36}'
      secret_pattern+='|glpat-[A-Za-z0-9_-]{20,}'
      secret_pattern+='|AWS_ACCESS_KEY_ID'
      secret_pattern+='|SECRET(_KEY)?'
      secret_pattern+='|TOKEN'
      secret_pattern+='|AUTHORIZATION:'
      secret_pattern+='|PASSWORD'
      leaked="$(
        git diff --cached -U0 |
          grep -Ei "$secret_pattern" \
          || true
      )"
      if [[ -n "$leaked" ]]; then
        echo "[BLOCKER] möglicher Secret-Inhalt im Diff:"
        echo "$leaked" | sed 's/^/  > /'
        rc=$RC_BLOCK
      fi
    fi

    # Big Files > 10MB (portabel)
    local big=0 sz; while IFS= read -r f; do
      [[ -f "$f" ]] || continue
      sz="$(file_size_bytes "$f")"
      if (( sz>10485760 )); then
        ((big++))
        printf '  - %s (%s B)\n' "$f" "$sz"
      fi
    done <<< "$staged"
    if (( big>0 )); then
      echo "[WARN] >10MB im Commit (siehe Liste oben)."
      (( rc==RC_OK )) && rc=$RC_WARN
    fi
  fi

  # Lockfile-Mix
  if git ls-files --error-unmatch pnpm-lock.yaml >/dev/null 2>&1 \
     && git ls-files --error-unmatch package-lock.json >/dev/null 2>&1; then
    echo "[WARN] pnpm-lock.yaml UND package-lock.json im Repo – Policy klären."
    (( rc==RC_OK )) && rc=$RC_WARN
  fi

  # Vale (nur Rückgabecode bewerten)
  if [[ -f ".vale.ini" ]]; then
    vale_maybe --staged || (( rc==RC_OK )) && rc=$RC_WARN
  fi

  case "$rc" in
    0) ok "Preflight sauber.";;
    1) warn "Preflight mit Warnungen.";;
    2) die "Preflight BLOCKER → bitte Hinweise beachten.";;
  esac
  printf "%s\n" "$rc"
}

# ─────────────────────────────────────────────────────────────────────────────
# SNAPSHOT (git stash)
# ─────────────────────────────────────────────────────────────────────────────
snapshot_make(){
  require_repo
  if [[ -z "$(git status --porcelain -z 2>/dev/null | head -c1)" ]]; then
    info "Kein Snapshot nötig (Arbeitsbaum sauber)."
    return 0
  fi
  local msg="snapshot@$(date +%s) $(git_branch)"
  git stash push -u -m "$msg" >/dev/null 2>&1 || true
  info "Snapshot erstellt (git stash list)."
}

# ─────────────────────────────────────────────────────────────────────────────
# LINT / TEST
# ─────────────────────────────────────────────────────────────────────────────
pm_detect(){
  local wd="$1"
  if [[ -n "${WGX_PM-}" ]]; then
    if has "$WGX_PM"; then echo "$WGX_PM"; return 0
    else warn "WGX_PM=$WGX_PM nicht gefunden, Auto-Detect aktiv."; fi
  fi
  if   [[ -f "$wd/pnpm-lock.yaml" ]] && has pnpm; then echo "pnpm"
  elif [[ -f "$wd/package-lock.json" ]] && has npm;  then echo "npm"
  elif [[ -f "$wd/yarn.lock"      ]] && has yarn; then echo "yarn"
  elif [[ -f "$wd/package.json"   ]]; then
    has pnpm && echo "pnpm" || has npm && echo "npm" || has yarn && echo "yarn" || echo ""
  else
    echo ""
  fi
}

run_soft(){
  local title="$1"; shift || true
  local rc=0
  if (( DRYRUN )); then
    if [[ $# -gt 0 ]]; then
      printf "DRY: %s → %q" "$title" "$1"; shift || true
      while [[ $# -gt 0 ]]; do printf " %q" "$1"; shift || true; done
      echo
    else
      printf "DRY: %s (kein Befehl übergeben)\n" "$title"
    fi
    return 0
  fi
  info "$title"
  if "$@"; then ok "$title ✓"; rc=0; else warn "$title ✗"; rc=1; fi
  printf "%s\n" "$rc"; return 0
}

lint_cmd(){
  require_repo
  local rc_total=$RC_OK

  # Vale
  vale_maybe || rc_total=$RC_WARN

  # Markdownlint (wenn vorhanden)
  if has markdownlint; then
    if [[ -n "$(git ls-files -z -- '*.md' 2>/dev/null | head -c1)" ]]; then
      git ls-files -z -- '*.md' 2>/dev/null \
        | run_with_files_xargs0 "markdownlint" markdownlint || rc_total=$RC_WARN
    fi
  fi

  # Web (Prettier/ESLint)
  local wd; wd="$(detect_web_dir || true)"
  if [[ -n "$wd" ]]; then
    local pm; pm="$(pm_detect "$wd")"
    local prettier_cmd="" eslint_cmd=""
    case "$pm" in
      pnpm) prettier_cmd="pnpm -s exec prettier"; eslint_cmd="pnpm -s exec eslint" ;;
      yarn) prettier_cmd="yarn -s prettier";     eslint_cmd="yarn -s eslint" ;;
      npm|"") prettier_cmd="npx --yes prettier"; eslint_cmd="npx --yes eslint" ;;
    esac

    if (( OFFLINE )); then
        [[ "$pm" == "npm" || "$pm" == "" ]] \
          && warn \
            "Offline: npx evtl. nicht verfügbar → Prettier/ESLint ggf. übersprungen."
    fi

    local has_gnu_find=0
    if find --version >/dev/null 2>&1; then
      find --version 2>/dev/null | grep -q GNU && has_gnu_find=1
    fi

    # Prettier Check (Node-Globs; node_modules/dist/build ausgeschlossen)
    if (( ! OFFLINE )); then
      if git_supports_magic "$wd" && (( has_gnu_find )); then
        git -C "$wd" ls-files -z \
          -- ':(exclude)node_modules/**' ':(exclude)dist/**' ':(exclude)build/**' \
             '*.js' '*.ts' '*.tsx' '*.jsx' '*.json' '*.css' '*.scss' '*.md' '*.svelte' 2>/dev/null \
        | run_with_files_xargs0 "Prettier Check" \
            sh -c '
              cd "$1"
              shift
              '"$prettier_cmd"' -c -- "$@"
            ' _ "$wd" \
        || run_with_files_xargs0 "Prettier Check (fallback npx)" \
            sh -c '
              cd "$1"
              shift
              npx --yes prettier -c -- "$@"
            ' _ "$wd" \
        || rc_total=$RC_WARN
      else
        find "$wd" \( -path "$wd/node_modules" -o -path "$wd/dist" -o -path "$wd/build" \) -prune -o \
             -type f \
             \( -name '*.js' -o \
                -name '*.ts' -o \
                -name '*.tsx' -o \
                -name '*.jsx' -o \
                -name '*.json' -o \
                -name '*.css' -o \
                -name '*.scss' -o \
                -name '*.md' -o \
                -name '*.svelte' \) \
             -print0 \
        | while IFS= read -r -d '' f; do
            rel="${f#$wd/}"
            printf '%s\0' "$rel"
          done \
        | run_with_files_xargs0 "Prettier Check" \
            sh -c '
              cd "$1"
              shift
              '"$prettier_cmd"' -c -- "$@"
            ' _ "$wd" \
        || { (( OFFLINE )) || run_with_files_xargs0 "Prettier Check (fallback npx)" \
               sh -c '
                 cd "$1"
                 shift
                 npx --yes prettier -c -- "$@"
               ' _ "$wd"; } \
        || rc_total=$RC_WARN
      fi
    fi

    # ESLint (nur wenn Konfig vorhanden)
    local has_eslint_cfg=0
    [[ -f "$wd/.eslintrc" || -f "$wd/.eslintrc.js" || -f "$wd/.eslintrc.cjs" || -f "$wd/.eslintrc.json" \
       || -f "$wd/eslint.config.js" || -f "$wd/eslint.config.mjs" || -f "$wd/eslint.config.cjs" ]] && has_eslint_cfg=1
    if (( has_eslint_cfg )); then
      run_soft "ESLint" bash -c '
        cd '"$wd"'
        $eslint_cmd -v >/dev/null 2>&1
        $eslint_cmd . --ext .js,.cjs,.mjs,.ts,.tsx,.svelte
      ' \
      || { if (( OFFLINE )); then warn "ESLint übersprungen (offline)"; false; \
           else run_soft "ESLint (fallback npx)" \
                  bash -c "cd '$wd' && npx --yes eslint . --ext .js,.cjs,.mjs,.ts,.tsx,.svelte"; fi; } \
      || rc_total=$RC_WARN
    fi
  fi

  # Rust (fmt + clippy, falls vorhanden)
  local ad; ad="$(detect_api_dir || true)"
  if [[ -n "$ad" && -f "$ad/Cargo.toml" ]] && has cargo; then
    run_soft "cargo fmt --check" bash -lc "cd '$ad' && cargo fmt --all -- --check" || rc_total=$RC_WARN
    if rustup component list 2>/dev/null | grep -q 'clippy.*(installed)'; then
      run_soft "cargo clippy (Hinweise)" bash -lc '
        cd '"$ad"'
        cargo clippy --all-targets --all-features -q
      ' || rc_total=$RC_WARN
    else
      warn "clippy nicht installiert – übersprungen."
    fi
  fi

  # Shell / Dockerfiles / Workflows
  if has shellcheck; then
    if [[ -n "$(git ls-files -z -- '*.sh' 2>/dev/null | head -c1)" || -f "./wgx" || -d "./scripts" ]]; then
      { git ls-files -z -- '*.sh' 2>/dev/null; git ls-files -z -- 'wgx' 'scripts/*' 2>/dev/null; } \
        | run_with_files_xargs0 "shellcheck" shellcheck || rc_total=$RC_WARN
    fi
  fi
  if has hadolint; then
    if [[ -n "$(git ls-files -z -- '*Dockerfile*' 2>/dev/null | head -c1)" ]]; then
      git ls-files -z -- '*Dockerfile*' 2>/dev/null \
        | run_with_files_xargs0 "hadolint" hadolint || rc_total=$RC_WARN
    fi
  fi
  if has actionlint && [[ -d ".github/workflows" ]]; then
    run_soft "actionlint" actionlint || rc_total=$RC_WARN
  fi

  (( rc_total==RC_OK )) && ok "Lint OK" || warn "Lint mit Hinweisen (rc=$rc_total)."
  printf "%s\n" "$rc_total"; return 0
}

pm_test(){
  local wd="$1"; local pm; pm="$(pm_detect "$wd")"
  case "$pm" in
    pnpm) (cd "$wd" && pnpm -s test -s) ;;
    npm)  (cd "$wd" && npm test -s) ;;
    yarn) (cd "$wd" && yarn -s test) ;;
    *)    return 0 ;;
  esac
}

test_cmd(){
  require_repo
  local rc_web=0 rc_api=0 wd ad pid_web= pid_api=
  trap '
    [[ -n "${pid_web-}" ]] && kill "$pid_web" 2>/dev/null || true
    [[ -n "${pid_api-}" ]] && kill "$pid_api" 2>/dev/null || true
  ' INT
  wd="$(detect_web_dir || true)"; ad="$(detect_api_dir || true)"
  if [[ -n "$wd" && -f "$wd/package.json" ]]; then
    info "Web-Tests…"; ( pm_test "$wd" ) & pid_web=$!
  fi
  if [[ -n "$ad" && -f "$ad/Cargo.toml" ]] && has cargo; then
    info "Rust-Tests…"; ( cd "$ad" && cargo test --all --quiet ) & pid_api=$!
  fi
  if [[ -n "${pid_web-}" ]]; then wait "$pid_web" || rc_web=1; fi
  if [[ -n "${pid_api-}" ]]; then wait "$pid_api" || rc_api=1; fi
  (( rc_web==0 && rc_api==0 )) && ok "Tests OK" || {
    [[ $rc_web -ne 0 ]] && warn "Web-Tests fehlgeschlagen."
    [[ $rc_api -ne 0 ]] && warn "Rust-Tests fehlgeschlagen."
    return 1
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# CODEOWNERS / Reviewer / Labels
# ─────────────────────────────────────────────────────────────────────────────
_codeowners_file(){
  if [[ -f ".github/CODEOWNERS" ]]; then echo ".github/CODEOWNERS"
  elif [[ -f "CODEOWNERS" ]]; then echo "CODEOWNERS"
  else echo ""; fi
}
declare -a CODEOWNERS_PATTERNS=(); declare -a CODEOWNERS_OWNERS=()

_sanitize_csv(){
  local csv="$1" IFS=, parts=(); read -ra parts <<<"$csv"
  local out=() seen="" p
  for p in "${parts[@]}"; do
    p="$(trim "$p")"; [[ -z "$p" ]] && continue
    [[ ",$seen," == *",$p,"* ]] && continue
    seen="${seen},$p"; out+=("$p")
  done
  local IFS=,; printf "%s" "${out[*]}"
}

_codeowners_reviewers(){ # liest \n-separierte Pfade von stdin
  CODEOWNERS_PATTERNS=(); CODEOWNERS_OWNERS=()
  local cof; cof="$(_codeowners_file)"; [[ -z "$cof" ]] && return 0
  local default_owners=() line
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="$(trim "$line")"
    [[ -z "$line" || "$line" =~ ^# ]] && continue
    line="${line%%#*}"; line="$(trim "$line")"; [[ -z "$line" ]] && continue
    local pat rest; pat="${line%%[[:space:]]*}"; rest="${line#"$pat"}"; rest="$(trim "$rest")"
    [[ -z "$pat" || -z "$rest" ]] && continue
    local -a arr; read -r -a arr <<<"$rest"
    if [[ "$pat" == "*" ]]; then
      default_owners=("${arr[@]}")
    else
      CODEOWNERS_PATTERNS+=("$pat")
      CODEOWNERS_OWNERS+=("$(printf "%s " "${arr[@]}")")
    fi
  done < "$cof"

  local files=() f; while IFS= read -r f; do [[ -n "$f" ]] && files+=("$f"); done

  # globstar temporär aktivieren (CODEOWNERS '**')
  local had_globstar=0
  if shopt -q globstar; then had_globstar=1; fi
  shopt -s globstar

  local seen="," i p matchOwners o
  for f in "${files[@]}"; do
    matchOwners=""
    for (( i=0; i<${#CODEOWNERS_PATTERNS[@]}; i++ )); do
      p="${CODEOWNERS_PATTERNS[$i]}"; [[ "$p" == /* ]] && p="${p:1}"
      case "$f" in $p) matchOwners="${CODEOWNERS_OWNERS[$i]}";; esac
    done
    [[ -z "$matchOwners" && ${#default_owners[@]} -gt 0 ]] && matchOwners="$(printf "%s " "${default_owners[@]}")"
    for o in $matchOwners; do
      [[ "$o" == @* ]] && o="${o#@}"
      [[ -z "$o" || "$o" == */* ]] && continue   # Teams (org/team) absichtlich ausgelassen
      [[ ",$seen," == *,"$o",* ]] && continue
      seen="${seen}${o},"
      printf "%s\n" "$o"
    done
  done

  if (( ! had_globstar )); then shopt -u globstar; fi
}

derive_labels(){
  local branch scope="$1"
  branch="$(git_branch)"
  local pref="${branch%%/*}"
  local L=()
  case "$pref" in
    feat)       L+=("feature");;
    fix|hotfix) L+=("bug");;
    docs)       L+=("docs");;
    refactor)   L+=("refactor");;
    test|tests) L+=("test");;
    ci)         L+=("ci");;
    perf)       L+=("performance");;
    chore)      L+=("chore");;
    build)      L+=("build");;
  esac
  case "$scope" in
    web)   L+=("area:web");;
    api)   L+=("area:api");;
    infra) L+=("area:infra");;
    devx)  L+=("area:devx");;
    docs)  L+=("area:docs");;
    meta)  L+=("area:meta");;
    repo)  L+=("area:repo");;
  esac
  # Benutzerspezifische Labels aus ENV hinzufügen
  if [[ -n "${WGX_PR_LABELS-}" ]]; then
    IFS=, read -ra add <<<"$WGX_PR_LABELS"
    for a in "${add[@]}"; do a="$(trim "$a")"; [[ -n "$a" ]] && L+=("$a"); done
  fi
  # Deduplizieren
  local out=() seen="" x
  for x in "${L[@]}"; do
    [[ ",$seen," == *,"$x",* ]] && continue
    seen="$seen,$x"; out+=("$x")
  done
  printf "%s" "$(IFS=,; echo "${out[*]}")"
}

pr_title_from_scope(){
  local scope="$1" branch; branch="$(git_branch)"
  local ticket=""
  [[ "$branch" =~ ([A-Z]+-[0-9]+) ]] && ticket="${BASH_REMATCH[1]}"
  local base="${branch#*/}"
  [[ "$base" == "$branch" ]] && base="$branch"
  base="${base//-/ }"
  base="$(echo "$base" | sed 's/\b\w/\U&/g')"
  if [[ -n "$ticket" ]]; then
    printf "[%s] %s (%s)\n" "$scope" "$base" "$ticket"
  else
    printf "[%s] %s\n" "$scope" "$base"
  fi
}

preview_diff(){
  local n="${WGX_PREVIEW_DIFF_LINES:-120}"
  git -c color.ui=always diff --staged | sed -n "1,${n}p"
  local more; more="$(git diff --staged | wc -l | awk '{print $1}')"
  (( more>n )) && printf "… (%d weitere Zeilen)\n" "$((more-n))" || true
}

<<TRUNCATED: max_file_lines=800>>
```

### 📄 merges/wgx_merge_2510262237__etc.md

**Größe:** 480 B | **md5:** `e5282d5abf7fa0a7c84538d072588e2b`

```markdown
### 📄 etc/config.example

**Größe:** 368 B | **md5:** `07296d5ac8d3e0ae5a9638b4b7c3e554`

```plaintext
# ~/.config/wgx/config
#
# Dieses Beispiel zeigt die wichtigsten Optionen. Kopiere die Datei nach
# ~/.config/wgx/config und passe die Werte an dein Projekt an.

[core]
base = main
signing = auto
preview_diff_lines = 120
pm = auto

[modules]
# Aktivierte Module kommasepariert, z. B. "canvas,gitflow"
enable =

[git]
pr_labels = "ready-for-review"
ci_workflow = "CI"
```
```

### 📄 merges/wgx_merge_2510262237__etc_ci.md

**Größe:** 1 KB | **md5:** `8b9da131030c003e384bf5e92bb45319`

```markdown
### 📄 etc/ci/run-with-files.sh

**Größe:** 1 KB | **md5:** `8503c9011dd4238164cf7c503bcc5195`

```bash
#!/usr/bin/env bash
set -e
set -u
if ! set -o pipefail 2>/dev/null; then
  if [[ ${WGX_DEBUG:-0} != 0 ]]; then
    echo "run-with-files.sh: 'pipefail' wird nicht unterstützt; führe ohne fort." >&2
  fi
fi

usage() {
  cat <<'USAGE' >&2
Usage: run-with-files.sh [--per-file] <empty-message> <command> [args...]

Reads file paths (one per line) from standard input, filters out empty entries,
and executes the provided command with the resulting list of files.

Without --per-file the command is run once with all files as arguments. When
--per-file is supplied the command is invoked separately for each file.
USAGE
}

per_file=false
if [[ ${1:-} == "--per-file" ]]; then
  per_file=true
  shift
fi

if [[ $# -lt 2 ]]; then
  usage
  exit 1
fi

empty_message="$1"
shift

mapfile -t raw_files </dev/stdin

files=()
for file in "${raw_files[@]}"; do
  # Normalize potential CRLF endings to gracefully handle Windows-edited files.
  file="${file%$'\r'}"
  [[ -z "$file" ]] && continue
  files+=("$file")
done

if [[ ${#files[@]} -eq 0 ]]; then
  echo "$empty_message"
  exit 0
fi

if [[ "$per_file" == true ]]; then
  printf '%s\0' "${files[@]}" | xargs -0 -r -n1 -- "$@"
else
  printf '%s\0' "${files[@]}" | xargs -0 -r -- "$@"
fi
```
```

### 📄 merges/wgx_merge_2510262237__index.md

**Größe:** 82 KB | **md5:** `48b8602de2953c24dbc868637f9cf1ad`

```markdown
# Ordner-Merge: wgx

**Zeitpunkt:** 2025-10-26 22:37
**Quelle:** `/home/alex/repos/wgx`
**Dateien (gefunden):** 128
**Gesamtgröße (roh):** 407 KB

**Exclude:** ['.gitignore']

## 📁 Struktur

- wgx/
  - .editorconfig
  - .gitattributes
  - .gitignore
  - .hauski-reports
  - .markdownlint.jsonc
  - .pre-commit-config.yaml
  - .vale.ini
  - CHANGELOG.md
  - CONTRIBUTING.md
  - Justfile
  - LICENSE
  - README.md
  - uv.lock
  - wgx
  - archiv/
    - wgx
  - tests/
    - .gitkeep
    - assertions.bats
    - clean.bats
    - cli_permissions.bats
    - env.bats
    - example_wgx.bats
    - guard.bats
    - help.bats
    - metrics_snapshot.bats
    - profile_parse_tasks.bats
    - profile_state.bats
    - profile_tasks.bats
    - reload.bats
    - semver.bats
    - semver_caret.bats
    - shell_ci.bats
    - sync.bats
    - tasks.bats
    - test_helper.bash
    - validate.bats
    - test_helper/
      - bats-support/
        - load
      - bats-assert/
        - load
  - cmd/
    - audit.bash
    - clean.bash
    - config.bash
    - doctor.bash
    - env.bash
    - guard.bash
    - heal.bash
    - hooks.bash
    - init.bash
    - lint.bash
    - quick.bash
    - release.bash
    - reload.bash
    - selftest.bash
    - send.bash
    - setup.bash
    - start.bash
    - status.bash
    - sync.bash
    - task.bash
    - tasks.bash
    - test.bash
    - validate.bash
    - version.bash
    - init/
      - wizard.sh
  - cli/
    - wgx
  - docs/
    - .gitkeep
    - ADR-0001__central-cli-contract.de.md
    - ADR-0002__python-env-manager-uv.de.md
    - Command-Reference.de.md
    - Glossar.de.md
    - Glossary.en.md
    - Language-Policy.md
    - Leitlinie.Quoting.de.md
    - Module-Uebersicht.de.md
    - Runbook.de.md
    - Runbook.en.md
    - Runbook.md
    - audit-ledger.md
    - audit-ledger.sample.jsonl
    - cli.md
    - quickstart.md
    - readiness.md
    - uv-integration-audit.de.md
    - wgx-konzept.md
    - wgx-mycelium-v-omega.de.md
    - archive/
      - wgx_monolith_20250925T130147Z.md
  - .local/
    - README.md
  - .github/
    - actions/
      - wgx-check/
        - action.yml
      - run-bats/
        - action.yml
    - workflows/
      - ci.yml
      - cli-docs-check.yml
      - compat-on-demand.yml
      - contracts.yml
      - metrics.yml
      - release.yml
      - security.yml
      - shell-docs.yml
      - tests-on-demand.yml
      - wgx-guard.yml
  - lib/
    - audit.bash
    - core.bash
    - hauski.bash
  - templates/
    - .gitkeep
    - profile.template.yml
    - docs/
      - README.additions.md
    - .wgx/
      - profile.local.example.yml
      - profile.yml
  - .vscode/
    - tasks.json
  - .vale/
    - styles/
      - wgxlint/
        - GermanComments.yml
      - hauski/
        - GermanProse/
          - GermanProse.yml
        - GermanComments/
          - GermanComments.yml
  - .wgx/
    - .gitignore
    - profile.example.yml
    - audit/
      - .gitkeep
  - installers/
    - .gitkeep
  - policies/
    - deny.toml
    - perf.json
    - slo.yaml
  - modules/
    - .gitkeep
    - doctor.bash
    - env.bash
    - guard.bash
    - json.bash
    - profile.bash
    - semver.bash
    - status.bash
  - .git/
    - COMMIT_EDITMSG
    - FETCH_HEAD
    - HEAD
    - ORIG_HEAD
    - config
    - description
    - index
    - packed-refs
    - hooks/
      - applypatch-msg.sample
      - commit-msg.sample
      - fsmonitor-watchman.sample
      - post-update.sample
      - pre-applypatch.sample
      - pre-commit.sample
      - pre-merge-commit.sample
      - pre-push
      - pre-push.sample
      - pre-rebase.sample
      - pre-receive.sample
      - prepare-commit-msg.sample
      - push-to-checkout.sample
      - update.sample
    - refs/
      - remotes/
        - origin/
          - HEAD
          - alert-autofix-1
          - alert-autofix-2
          - alert-autofix-4
          - feat-which-command
          - main
          - refactor-core-logic
          - refactor/
            - vereinfachung-verzeichnispfad
          - fix/
            - lint-errors
            - shell-linting-errors
            - shell-script-errors
            - shellcheck-errors
            - shellcheck-warnings
            - shfmt-formatting
          - chore/
            - fix-inconsistencies
          - codex/
            - add-actions-write-permission-for-cache
            - add-automated-cli-reference-generation
            - add-bats-assert-to-tests
            - add-cargo-installation-check-to-workflow
            - add-checksum-verification-to-ci-workflow
            - add-fallback-support-for-root-keys
            - add-metrics-snapshot-and-validation
            - add-minimal-privileged-ci-check-for-cli-docs
            - add-missing-token-input-to-workflow
            - add-no-secrets-warning-and-ci-fallback
            - add-official-profile-templates
            - add-pre-commit-hooks-and-ci-improvements
            - add-pre-commit-hooks-for-scripts-and-docs
            - add-readiness-matrix,-audit-ledger,-profile-wizard
            - add-self-validation-in-wgx
            - add-semantah-documentation-to-wgx
            - add-semver-tests-for-caret-ranges
            - add-syntax-check-for-modified-shell-files
            - add-tests-for-metrics-snapshot
            - add-timeout-to-github-actions-workflow
            - add-tracked-profile.example.yml-file
            - add-validate-subcommand-to-router
            - add-wgx-meta-layer-configuration
            - add-wgx-profile-file-for-ci
            - apply-patch-to-wgx-guard-workflow
            - check-documentation-completeness
            - check-for-errors-in-the-code
            - check-if-ci-patches-are-implemented
            - check-workflows-for-functionality
            - convert-yaml-to-json-for-ajv-validation
            - create-codex-ready-task-instructions
            - create-comprehensive-wgx-documentation
            - create-new-pr-for-setup.sh-changes
            - create-new-pr-for-setup.sh-updates
            - enable-vale-prose-for-markdown
            - enhance-ci-for-changed-files-only
            - ensure-wgx-guard.yml-exists-and-matches-rules
            - evaluate-uv-package-manager-integration
            - finalize-clean-command-enhancements
            - find-errors-in-the-code-940qbt
            - find-errors-in-the-code-agdv7s
            - find-errors-in-the-code-ixxgdb
            - find-errors-in-the-code-w1f9e2
            - find-errors-in-the-repo
            - fix-action-file-not-found-error
            - fix-apt-get-update-unsigned-response-error
            - fix-argument-parsing-in-sync.bash
            - fix-argument-parsing-in-sync.bash-bbp3vt
            - fix-assert_success-command-missing-in-bats-tests
            - fix-assertion-for-env-doctor-test
            - fix-bash-availability-in-wgx-guard-workflow
            - fix-bats-action-version-in-ci.yml
            - fix-bats-core-action-version-in-workflow
            - fix-bats-installation-due-to-repository-403-errors
            - fix-bats-test-assert_error-not-found
            - fix-bats-test-failures-for-reload-and-sync
            - fix-bats-test-failures-in-reload,-sync,-validate
            - fix-bats-test-suite-issues
            - fix-bats-tests-for-clean-dry-run
            - fix-bats-tests-for-reload-and-sync
            - fix-bats-tests-helper-not-found-error
            - fix-case-handling-in-shell-script
            - fix-case-statement-in-shell-script
            - fix-case-statement-syntax-errors
            - fix-ci-flag-and-add-validation
            - fix-ci-job-52514329845-issues
            - fix-ci-job-for-missing-bash-and-config-files
            - fix-ci-job-image-and-shellscript-errors
            - fix-ci-job-shell-script-errors
            - fix-ci-process-failures-due-to-missing-files
            - fix-clean-command-exit-code-errors
            - fix-clean-script-dry-run-exit-code
            - fix-cmd_clean-to-return-exit-0
            - fix-compatibility-issue-for-empty-tasks
            - fix-double-branch-creation-in-tests
            - fix-dry-run-command-error-in-tests
            - fix-dry-run-command-execution-errors
            - fix-dry-run-command-exit-status
            - fix-dry-run-exit-code-for-clean-command
            - fix-dry-run-exit-status-in-clean-command
            - fix-dry-run-implementation-in-cmd_clean
            - fix-dry-run-test-failures-in-clean-script
            - fix-env-doctor-command-output-error
            - fix-env-doctor-stderr-output
            - fix-error-message-in-env-doctor-command
            - fix-error-output-location-in-env-doctor-test
            - fix-exit-code-123-in-script-processing
            - fix-exit-code-for-clean-dry-run
            - fix-exit-code-for-dry-run-clean-command
            - fix-exit-code-for-dry-run-in-clean
            - fix-exit-code-for-dry-run-in-clean-command
            - fix-exit-code-for-dry-run-in-clean-command-97hgar
            - fix-exit-code-handling-and-timeouts
            - fix-exit-code-handling-with-errexit
            - fix-exit-status-for-dry-run-tests
            - fix-failing-bats-tests-for-reload-and-sync
            - fix-failing-bats-tests-for-reload-and-sync-iymcz5
            - fix-failing-bats-tests-for-reload-and-sync-wmbojw
            - fix-failing-tests-for-wgx-clean-command
            - fix-fallback-file-guard-logic
            - fix-formatting-of-shell-scripts
            - fix-github-action-permissions-error
            - fix-guard-job-to-error-on-missing-profiles
            - fix-inconsistent-sync-cancellation-message
            - fix-incorrect-exit-code-in-clean-command
            - fix-job-52514767913-errors
            - fix-job-runner-for-bash-installation
            - fix-job-to-use-runner-with-pre-installed-bash
            - fix-markdownlint-errors-and-shell-script-formatting
            - fix-markdownlint-errors-in-documentation
            - fix-markdownlint-errors-in-markdown-files
            - fix-markdownlint-errors-in-markdown-files-i9h0yw
            - fix-markdownlint-errors-in-readme.md
            - fix-markdownlint-violations-in-markdown-files
            - fix-minor-issues-in-reload-and-sync-scripts
            - fix-missing-bats-assert-helper-commands
            - fix-missing-bats-support-file-error
            - fix-missing-dependencies-lock-file
            - fix-missing-profile.yml-or-profile.example.yml
            - fix-missing-semver_in_caret_range-command
            - fix-missing-token-input-in-workflow
            - fix-multiple-test-failures-in-bats-suite
            - fix-reload-and-sync-bash-commands
            - fix-sed-regex-syntax-in-ci-workflow
            - fix-semantic-version-comparison-in-script
            - fix-shell-declaration-in-workflow
            - fix-shell-formatting-check-errors
            - fix-shell-formatting-check-failure
            - fix-shell-script-case-handling
            - fix-shell-script-case-statement-errors
            - fix-shell-script-for-posix-compatibility
            - fix-shell-script-formatting-check
            - fix-shell-script-formatting-error
            - fix-shell-script-formatting-error-wfn3to
            - fix-shell-script-formatting-errors
            - fix-shell-script-logic-in-setup.sh
            - fix-shell-script-syntax-error
            - fix-shell-script-syntax-errors
            - fix-snapshot-script-and-permissions-warnings
            - fix-stderr-output-for-env-doctor-command
            - fix-symlink-resolution-for-wgx_dir
            - fix-sync-aborted-error-message
            - fix-sync-test-failure-on-dirty-working-tree
            - fix-syntax-error-in-bash-case-statement
            - fix-syntax-error-in-bash-case-statements
            - fix-test-errors-in-bats-suite
            - fix-test-failures-due-to-branch-name-mismatch
            - fix-test-failures-in-clean.bash
            - fix-test-failures-in-shell-scripts
            - fix-test-failures-in-workflow-jobs
            - fix-tests-for-wgx-env-doctor-command
            - fix-uninitialized-variable-error-in-bash-script
            - fix-unknown-option-error-in-sync_cmd
            - fix-vale-download-issue-in-ci-workflow
            - fix-wgx-clean-dry-run-exit-status
            - fix-wgx-clean-exit-code-handling
            - fix-wgx-clean-exit-code-handling-dnvusx
            - fix-workflow-directory-for-cargo-audit
            - fix-working-directory-for-cargo-commands
            - harden-run-bats-action-dependencies
            - harden-wgx-guard-and-profile-handling
            - harmonize-.devcontainer-setup
            - implement-intelligent-ci-optimizations
            - implement-wgx-metrics-snapshot-and-validation
            - install-bash-in-runner-image
            - install-bats-assert-and-bats-support
            - integrate-uv-into-wgx-cli
            - introduce-wgx-ci,-guard,-and-docs
            - investigate-wgx-validate-command-inconsistencies
            - locate-error-in-code
            - locate-errors-in-code
            - locate-errors-in-code-vfm1gh
            - locate-errors-in-the-code
            - locate-errors-in-the-code-ku98as
            - merge-improvements-for-setup-scripts
            - merge-prs-and-update-templates
            - migrate-github-organization-and-repositories
            - move-_record_error-function-definition-up
            - optimize-sync-command-and-add-tests
            - preserve-shell-semantics-for-str-tasks
            - provide-vs-code-task-templates
            - recreate-pr-with-optimized-changes
            - refactor-bilingual-documentation-for-language-consistency
            - refactor-error-code-handling-in-sync.bash
            - refactor-file-normalization-logic-in-ci-workflow
            - refactor-semver-caret-tests
            - refactor-semver_caret.bats-tests
            - refactor-sudo-detection-and-bash-install
            - refactor-wgx-cli-for-v1.1-support
            - remove-check-target-from-setup.sh
            - remove-empty-line-in-info_present-logic
            - remove-npm-cache-from-workflow
            - remove-package.json-if-unused
            - remove-sudo-calls-from-installation-scripts
            - remove-unsupported-timeout-argument
            - replace-apt-installs-with-cached-binaries
            - replace-ci-configuration-for-wgx-repo
            - restore-validate-run-and-add-lints
            - review-code-changes-for-pr-creation
            - setup-policies-directory-in-wgx-repo
            - untersuchung-auf-fehler-im-repo
            - update-actions-permissions-in-metrics.yml
            - update-bats-action-version-in-workflow
            - update-bats-action-version-to-v1
            - update-bats-tests-for-main-branch
            - update-bigfile-detection-in-guard.bash
            - update-bigfile-detection-in-guard.bash-kbkacr
            - update-bigfile-detection-in-guard.bash-w4teg0
            - update-cli-documentation
            - update-cli-documentation-ipz0ty
            - update-cli-documentation-mcp3ni
            - update-cli-documentation-reference
            - update-documentation-to-german
            - update-error-message-to-english
            - update-error-messages-to-english
            - update-info-function-to-default-to-stdout
            - update-language-policy-to-german-first
            - update-license-clarification-in-readme
            - update-license-file-and-readme
            - update-quoting-guidelines-and-linter-settings
            - update-readme.md-section
            - update-runner-image-to-include-bash
            - update-sync.bash-for-compatible-git-pull
            - update-tasks-command-for-json-support
            - update-usage-documentation-for-run-with-files.sh
            - update-vale_version-to-valid-release
            - update-workflow-to-use-bash-enabled-runner
            - validate-github_token-before-using
            - verify-ci-enforcement-of-uv-sync-setup
            - verify-new-metrics-flow-end-to-end
            - verify-shebang-and-shellcheck-coverage
            - implement-secure-reload/
              - sync-options
            - check-executable-bits-for-cli/
              - wgx
            - add-.wgx/
              - profile.example.yml-file
              - profile.yml-file
              - profile.yml-file-for-job-51981849226
            - update-bats-core/
              - bats-action-version
              - bats-action-version-uvy8lf
            - fix-inline-python-type-annotations-for-3.8/
              - 3.9
            - add-documentation-in-wgx/
              - docs
            - enhance-ci/
              - cd-workflows-with-new-features
            - fix-formatting-issue-in-.sh/
              - bash-scripts
            - fix-bats-core/
              - bats-action-version-in-workflow
              - bats-action-version-reference
          - bugfix/
            - code-cleanup-and-fixes
          - feat/
            - add-cli-help-functions
      - tags/
      - heads/
        - main
        - backup/
          - main-20251010-110156
          - main-20251013-065004
          - main-20251017-182435
          - main-20251017-213716
          - main-20251018-090520
          - main-20251021-124303
          - main-20251023-070600
          - main-20251023-090517
          - main-20251023-114024
          - main-20251024-160436
          - main-20251024-213738
          - main-20251026-162044
          - main-20251026-223652
    - logs/
      - HEAD
      - refs/
        - remotes/
          - origin/
            - HEAD
            - alert-autofix-1
            - alert-autofix-2
            - alert-autofix-4
            - feat-which-command
            - main
            - refactor-core-logic
            - refactor/
              - vereinfachung-verzeichnispfad
            - fix/
              - lint-errors
              - shell-linting-errors
              - shell-script-errors
              - shellcheck-errors
              - shellcheck-warnings
              - shfmt-formatting
            - chore/
              - fix-inconsistencies
            - codex/
              - add-actions-write-permission-for-cache
              - add-automated-cli-reference-generation
              - add-bats-assert-to-tests
              - add-cargo-installation-check-to-workflow
              - add-checksum-verification-to-ci-workflow
              - add-fallback-support-for-root-keys
              - add-metrics-snapshot-and-validation
              - add-minimal-privileged-ci-check-for-cli-docs
              - add-missing-token-input-to-workflow
              - add-no-secrets-warning-and-ci-fallback
              - add-official-profile-templates
              - add-pre-commit-hooks-and-ci-improvements
              - add-pre-commit-hooks-for-scripts-and-docs
              - add-readiness-matrix,-audit-ledger,-profile-wizard
              - add-self-validation-in-wgx
              - add-semantah-documentation-to-wgx
              - add-semver-tests-for-caret-ranges
              - add-syntax-check-for-modified-shell-files
              - add-tests-for-metrics-snapshot
              - add-timeout-to-github-actions-workflow
              - add-tracked-profile.example.yml-file
              - add-validate-subcommand-to-router
              - add-wgx-meta-layer-configuration
              - add-wgx-profile-file-for-ci
              - apply-patch-to-wgx-guard-workflow
              - check-documentation-completeness
              - check-for-errors-in-the-code
              - check-if-ci-patches-are-implemented
              - check-workflows-for-functionality
              - convert-yaml-to-json-for-ajv-validation
              - create-codex-ready-task-instructions
              - create-comprehensive-wgx-documentation
              - create-new-pr-for-setup.sh-changes
              - create-new-pr-for-setup.sh-updates
              - enable-vale-prose-for-markdown
              - enhance-ci-for-changed-files-only
              - ensure-wgx-guard.yml-exists-and-matches-rules
              - evaluate-uv-package-manager-integration
              - finalize-clean-command-enhancements
              - find-errors-in-the-code-940qbt
              - find-errors-in-the-code-agdv7s
              - find-errors-in-the-code-ixxgdb
              - find-errors-in-the-code-w1f9e2
              - find-errors-in-the-repo
              - fix-action-file-not-found-error
              - fix-apt-get-update-unsigned-response-error
              - fix-argument-parsing-in-sync.bash
              - fix-argument-parsing-in-sync.bash-bbp3vt
              - fix-assert_success-command-missing-in-bats-tests
              - fix-assertion-for-env-doctor-test
              - fix-bash-availability-in-wgx-guard-workflow
              - fix-bats-action-version-in-ci.yml
              - fix-bats-core-action-version-in-workflow
              - fix-bats-installation-due-to-repository-403-errors
              - fix-bats-test-assert_error-not-found
              - fix-bats-test-failures-for-reload-and-sync
              - fix-bats-test-failures-in-reload,-sync,-validate
              - fix-bats-test-suite-issues
              - fix-bats-tests-for-clean-dry-run
              - fix-bats-tests-for-reload-and-sync
              - fix-bats-tests-helper-not-found-error
              - fix-case-handling-in-shell-script
              - fix-case-statement-in-shell-script
              - fix-case-statement-syntax-errors
              - fix-ci-flag-and-add-validation
              - fix-ci-job-52514329845-issues
              - fix-ci-job-for-missing-bash-and-config-files
              - fix-ci-job-image-and-shellscript-errors
              - fix-ci-job-shell-script-errors
              - fix-ci-process-failures-due-to-missing-files
              - fix-clean-command-exit-code-errors
              - fix-clean-script-dry-run-exit-code
              - fix-cmd_clean-to-return-exit-0
              - fix-compatibility-issue-for-empty-tasks
              - fix-double-branch-creation-in-tests
              - fix-dry-run-command-error-in-tests
              - fix-dry-run-command-execution-errors
              - fix-dry-run-command-exit-status
              - fix-dry-run-exit-code-for-clean-command
              - fix-dry-run-exit-status-in-clean-command
              - fix-dry-run-implementation-in-cmd_clean
              - fix-dry-run-test-failures-in-clean-script
              - fix-env-doctor-command-output-error
              - fix-env-doctor-stderr-output
              - fix-error-message-in-env-doctor-command
              - fix-error-output-location-in-env-doctor-test
              - fix-exit-code-123-in-script-processing
              - fix-exit-code-for-clean-dry-run
              - fix-exit-code-for-dry-run-clean-command
              - fix-exit-code-for-dry-run-in-clean
              - fix-exit-code-for-dry-run-in-clean-command
              - fix-exit-code-for-dry-run-in-clean-command-97hgar
              - fix-exit-code-handling-and-timeouts
              - fix-exit-code-handling-with-errexit
              - fix-exit-status-for-dry-run-tests
              - fix-failing-bats-tests-for-reload-and-sync
              - fix-failing-bats-tests-for-reload-and-sync-iymcz5
              - fix-failing-bats-tests-for-reload-and-sync-wmbojw
              - fix-failing-tests-for-wgx-clean-command
              - fix-fallback-file-guard-logic
              - fix-formatting-of-shell-scripts
              - fix-github-action-permissions-error
              - fix-guard-job-to-error-on-missing-profiles
              - fix-inconsistent-sync-cancellation-message
              - fix-incorrect-exit-code-in-clean-command
              - fix-job-52514767913-errors
              - fix-job-runner-for-bash-installation
              - fix-job-to-use-runner-with-pre-installed-bash
              - fix-markdownlint-errors-and-shell-script-formatting
              - fix-markdownlint-errors-in-documentation
              - fix-markdownlint-errors-in-markdown-files
              - fix-markdownlint-errors-in-markdown-files-i9h0yw
              - fix-markdownlint-errors-in-readme.md
              - fix-markdownlint-violations-in-markdown-files
              - fix-minor-issues-in-reload-and-sync-scripts
              - fix-missing-bats-assert-helper-commands
              - fix-missing-bats-support-file-error
              - fix-missing-dependencies-lock-file
              - fix-missing-profile.yml-or-profile.example.yml
              - fix-missing-semver_in_caret_range-command
              - fix-missing-token-input-in-workflow
              - fix-multiple-test-failures-in-bats-suite
              - fix-reload-and-sync-bash-commands
              - fix-sed-regex-syntax-in-ci-workflow
              - fix-semantic-version-comparison-in-script
              - fix-shell-declaration-in-workflow
              - fix-shell-formatting-check-errors
              - fix-shell-formatting-check-failure
              - fix-shell-script-case-handling
              - fix-shell-script-case-statement-errors
              - fix-shell-script-for-posix-compatibility
              - fix-shell-script-formatting-check
              - fix-shell-script-formatting-error
              - fix-shell-script-formatting-error-wfn3to
              - fix-shell-script-formatting-errors
              - fix-shell-script-logic-in-setup.sh
              - fix-shell-script-syntax-error
              - fix-shell-script-syntax-errors
              - fix-snapshot-script-and-permissions-warnings
              - fix-stderr-output-for-env-doctor-command
              - fix-symlink-resolution-for-wgx_dir
              - fix-sync-aborted-error-message
              - fix-sync-test-failure-on-dirty-working-tree
              - fix-syntax-error-in-bash-case-statement
              - fix-syntax-error-in-bash-case-statements
              - fix-test-errors-in-bats-suite
              - fix-test-failures-due-to-branch-name-mismatch
              - fix-test-failures-in-clean.bash
              - fix-test-failures-in-shell-scripts
              - fix-test-failures-in-workflow-jobs
              - fix-tests-for-wgx-env-doctor-command
              - fix-uninitialized-variable-error-in-bash-script
              - fix-unknown-option-error-in-sync_cmd
              - fix-vale-download-issue-in-ci-workflow
              - fix-wgx-clean-dry-run-exit-status
              - fix-wgx-clean-exit-code-handling
              - fix-wgx-clean-exit-code-handling-dnvusx
              - fix-workflow-directory-for-cargo-audit
              - fix-working-directory-for-cargo-commands
              - harden-run-bats-action-dependencies
              - harden-wgx-guard-and-profile-handling
              - harmonize-.devcontainer-setup
              - implement-intelligent-ci-optimizations
              - implement-wgx-metrics-snapshot-and-validation
              - install-bash-in-runner-image
              - install-bats-assert-and-bats-support
              - integrate-uv-into-wgx-cli
              - introduce-wgx-ci,-guard,-and-docs
              - investigate-wgx-validate-command-inconsistencies
              - locate-error-in-code
              - locate-errors-in-code
              - locate-errors-in-code-vfm1gh
              - locate-errors-in-the-code
              - locate-errors-in-the-code-ku98as
              - merge-improvements-for-setup-scripts
              - merge-prs-and-update-templates
              - migrate-github-organization-and-repositories
              - move-_record_error-function-definition-up
              - optimize-sync-command-and-add-tests
              - preserve-shell-semantics-for-str-tasks
              - provide-vs-code-task-templates
              - recreate-pr-with-optimized-changes
              - refactor-bilingual-documentation-for-language-consistency
              - refactor-error-code-handling-in-sync.bash
              - refactor-file-normalization-logic-in-ci-workflow
              - refactor-semver-caret-tests
              - refactor-semver_caret.bats-tests
              - refactor-sudo-detection-and-bash-install
              - refactor-wgx-cli-for-v1.1-support
              - remove-check-target-from-setup.sh
              - remove-empty-line-in-info_present-logic
              - remove-npm-cache-from-workflow
              - remove-package.json-if-unused
              - remove-sudo-calls-from-installation-scripts
              - remove-unsupported-timeout-argument
              - replace-apt-installs-with-cached-binaries
              - replace-ci-configuration-for-wgx-repo
              - restore-validate-run-and-add-lints
              - review-code-changes-for-pr-creation
              - setup-policies-directory-in-wgx-repo
              - untersuchung-auf-fehler-im-repo
              - update-actions-permissions-in-metrics.yml
              - update-bats-action-version-in-workflow
              - update-bats-action-version-to-v1
              - update-bats-tests-for-main-branch
              - update-bigfile-detection-in-guard.bash
              - update-bigfile-detection-in-guard.bash-kbkacr
              - update-bigfile-detection-in-guard.bash-w4teg0
              - update-cli-documentation
              - update-cli-documentation-ipz0ty
              - update-cli-documentation-mcp3ni
              - update-cli-documentation-reference
              - update-documentation-to-german
              - update-error-message-to-english
              - update-error-messages-to-english
              - update-info-function-to-default-to-stdout
              - update-language-policy-to-german-first
              - update-license-clarification-in-readme
              - update-license-file-and-readme
              - update-quoting-guidelines-and-linter-settings
              - update-readme.md-section
              - update-runner-image-to-include-bash
              - update-sync.bash-for-compatible-git-pull
              - update-tasks-command-for-json-support
              - update-usage-documentation-for-run-with-files.sh
              - update-vale_version-to-valid-release
              - update-workflow-to-use-bash-enabled-runner
              - validate-github_token-before-using
              - verify-ci-enforcement-of-uv-sync-setup
              - verify-new-metrics-flow-end-to-end
              - verify-shebang-and-shellcheck-coverage
              - implement-secure-reload/
                - sync-options
              - check-executable-bits-for-cli/
                - wgx
              - add-.wgx/
                - profile.example.yml-file
                - profile.yml-file
                - profile.yml-file-for-job-51981849226
              - update-bats-core/
                - bats-action-version
                - bats-action-version-uvy8lf
              - fix-inline-python-type-annotations-for-3.8/
                - 3.9
              - add-documentation-in-wgx/
                - docs
              - enhance-ci/
                - cd-workflows-with-new-features
              - fix-formatting-issue-in-.sh/
                - bash-scripts
              - fix-bats-core/
                - bats-action-version-in-workflow
                - bats-action-version-reference
            - bugfix/
              - code-cleanup-and-fixes
            - feat/
              - add-cli-help-functions
        - heads/
          - main
          - backup/
            - main-20251010-110156
            - main-20251013-065004
            - main-20251017-182435
            - main-20251017-213716
            - main-20251018-090520
            - main-20251021-124303
            - main-20251023-070600
            - main-20251023-090517
            - main-20251023-114024
            - main-20251024-160436
            - main-20251024-213738
            - main-20251026-162044
            - main-20251026-223652
    - branches/
    - info/
      - exclude
    - objects/
      - de/
        - 26422c768a6a16eeb816cd125f701e0012a08e
        - 59d2e6e83fa608647eca603f11dc20b35f3159
        - 5ac338a77caba5234ea6788a2339411057aa68
        - 9c35db1e8a49b1a075c04ab735e95b5ea329c4
        - f58a180988555dc8e8719e1baed487df94f27e
      - b0/
        - 07051f1488492768e40b0d8186b9f2873494f3
        - 9a8bbad585ef5e0afd2cd8a8757017ffc0e01f
      - 48/
        - 66dcb32dda593a50b09fedc32337f8ceef7149

<<TRUNCATED: max_file_lines=800>>
```

### 📄 merges/wgx_merge_2510262237__installers.md

**Größe:** 113 B | **md5:** `b1aa51a1c74693feedeb7badc2efc679`

```markdown
### 📄 installers/.gitkeep

**Größe:** 0 B | **md5:** `d41d8cd98f00b204e9800998ecf8427e`

```plaintext

```
```

### 📄 merges/wgx_merge_2510262237__lib.md

**Größe:** 14 KB | **md5:** `99a145ee57aefa46dc8eb051d8638904`

```markdown
### 📄 lib/audit.bash

**Größe:** 4 KB | **md5:** `249168f29a71f87b5c07850d6b599498`

```bash
#!/usr/bin/env bash

_audit_default_dir() {
  local base="${WGX_DIR:-"$(pwd)"}"
  printf '%s/.wgx/audit' "$base"
}

audit::_ledger_path() {
  local target="${WGX_AUDIT_LOG:-}"
  if [[ -z "$target" ]]; then
    target="$(_audit_default_dir)/ledger.jsonl"
  fi
  printf '%s' "$target"
}

audit::log() {
  local event="${1:-}"
  local payload
  payload="$2"
  if [[ -z "$payload" ]]; then
    payload="{}"
  fi
  if [[ -z "$event" ]]; then
    printf 'audit::log: missing event name\n' >&2
    return 1
  fi
  if ! command -v python3 >/dev/null 2>&1; then
    printf 'audit::log: python3 not available – skipping log.\n' >&2
    return 0
  fi
  local ledger
  ledger="$(audit::_ledger_path)" || return 1
  local dir
  dir="$(dirname "$ledger")"
  mkdir -p "$dir"
  local timestamp
  timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  local git_sha
  git_sha="$(git rev-parse HEAD 2>/dev/null || printf '%040d' 0)"
  local prev_line=""
  if [[ -s "$ledger" ]]; then
    prev_line="$(tail -n 1 "$ledger" 2>/dev/null || printf '')"
  fi
  AUDIT_EVENT="$event" \
  AUDIT_PAYLOAD="$payload" \
  AUDIT_TIMESTAMP="$timestamp" \
  AUDIT_SHA="$git_sha" \
  AUDIT_PREV_LINE="$prev_line" \
  python3 - "$ledger" <<'PY'
import json
import os
import sys
import hashlib
from pathlib import Path

ledger_path = Path(sys.argv[1])
event = os.environ.get("AUDIT_EVENT", "")
payload_raw = os.environ.get("AUDIT_PAYLOAD", "{}")
timestamp = os.environ.get("AUDIT_TIMESTAMP") or ""
git_sha = os.environ.get("AUDIT_SHA") or ""
prev_line = os.environ.get("AUDIT_PREV_LINE", "").strip()
prev_hash = "0" * 64
if prev_line:
    try:
        prev_hash = json.loads(prev_line).get("hash", "0" * 64)
        if not isinstance(prev_hash, str) or len(prev_hash) != 64:
            raise ValueError
    except Exception:
        prev_hash = hashlib.sha256(prev_line.encode("utf-8")).hexdigest()
try:
    payload = json.loads(payload_raw)
except Exception:
    payload = {"raw": payload_raw}
entry = {
    "timestamp": timestamp,
    "event": event,
    "git_sha": git_sha,
    "payload": payload,
    "prev_hash": prev_hash,
}
body = json.dumps(entry, sort_keys=True, separators=(",", ":"))
entry["hash"] = hashlib.sha256(body.encode("utf-8")).hexdigest()
with ledger_path.open("a", encoding="utf-8") as fh:
    fh.write(json.dumps(entry, sort_keys=True, separators=(",", ":")))
    fh.write("\n")
PY
}

audit::verify() {
  local strict=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --strict)
        strict=1
        shift
        ;;
      --help|-h)
        cat <<'USAGE'
audit::verify [--strict]
  Prüft die Hash-Kette in .wgx/audit/ledger.jsonl.
  Rückgabewert 0 bei gültiger Kette.
  Mit --strict (oder AUDIT_VERIFY_STRICT=1) führt eine Verletzung zu exit != 0.
USAGE
        return 0
        ;;
      --*)
        printf 'audit::verify: unknown option %s\n' "$1" >&2
        return 1
        ;;
      *)
        break
        ;;
    esac
  done
  if ! command -v python3 >/dev/null 2>&1; then
    printf 'audit::verify: python3 not available.\n' >&2
    return 0
  fi
  local ledger
  ledger="$(audit::_ledger_path)" || return 1
  if [[ ! -s "$ledger" ]]; then
    printf 'audit::verify: ledger empty (%s).\n' "$ledger"
    return 0
  fi
  local output
  if output=$(AUDIT_STRICT_MODE="$strict" python3 - "$ledger" <<'PY'
import json
import os
import sys
import hashlib
from pathlib import Path

ledger_path = Path(sys.argv[1])
prev_hash = "0" * 64
line_no = 0
for raw in ledger_path.read_text(encoding="utf-8").splitlines():
    line = raw.strip()
    if not line:
        continue
    line_no += 1
    try:
        entry = json.loads(line)
    except Exception:
        print(f"invalid_json line={line_no}")
        sys.exit(1)
    if entry.get("prev_hash") != prev_hash:
        print(f"prev_hash_mismatch line={line_no}")
        sys.exit(1)
    data = dict(entry)
    digest = data.pop("hash", None)
    body = json.dumps(data, sort_keys=True, separators=(",", ":"))
    expected = hashlib.sha256(body.encode("utf-8")).hexdigest()
    if digest != expected:
        print(f"hash_mismatch line={line_no}")
        sys.exit(1)
    prev_hash = digest or "0" * 64
print("OK")
PY
); then
    printf '%s\n' "$output"
    return 0
  else
    local rc=$?
    if [[ -n "$output" ]]; then
      printf '%s\n' "$output" >&2
    fi
    if ((strict)) || [[ ${AUDIT_VERIFY_STRICT:-0} != 0 ]]; then
      return $rc
    fi
    printf 'audit::verify: non-strict mode, treating failure as warning.\n' >&2
    return 0
  fi
}
```

### 📄 lib/core.bash

**Größe:** 9 KB | **md5:** `24861ddfdeeb3be3ef2aeef9a77bea4e`

```bash
#!/usr/bin/env bash

# ---------- Logging ----------

: "${WGX_NO_EMOJI:=0}"
: "${WGX_QUIET:=0}"
: "${WGX_INFO_STDERR:=0}"

if [[ "$WGX_NO_EMOJI" != 0 ]]; then
  _OK="[OK]"
  _WARN="[WARN]"
  _ERR="[ERR]"
  _DOT="*"
else
  _OK="✅"
  _WARN="⚠️"
  _ERR="❌"
  _DOT="•"
fi

if ! type -t debug >/dev/null 2>&1; then
  debug() {
    [[ ${WGX_DEBUG:-0} != 0 ]] || return 0
    [[ ${WGX_QUIET:-0} != 0 ]] && return
    printf 'DEBUG %s\n' "$*" >&2
  }
fi

if ! type -t info >/dev/null 2>&1; then
  info() {
    # Default: STDOUT (wie bisher). Für CI/quiet-Logs optional auf STDERR umleitbar.
    [[ ${WGX_QUIET:-0} != 0 ]] && return
    if [[ ${WGX_INFO_STDERR:-0} != 0 ]]; then
      printf '%s %s\n' "$_DOT" "$*" >&2
    else
      printf '%s %s\n' "$_DOT" "$*"
    fi
  }
fi

if ! type -t ok >/dev/null 2>&1; then
  ok() {
    [[ ${WGX_QUIET:-0} != 0 ]] && return
    printf '%s %s\n' "$_OK" "$*" >&2
  }
fi

if ! type -t warn >/dev/null 2>&1; then
  warn() {
    printf '%s %s\n' "$_WARN" "$*" >&2
  }
fi

if ! type -t die >/dev/null 2>&1; then
  die() {
    printf '%s %s\n' "$_ERR" "$*" >&2
    exit 1
  }
fi

# ---------- Env / Defaults ----------
: "${WGX_VERSION:=2.0.3}"
: "${WGX_BASE:=main}"

# ── Module autoload ─────────────────────────────────────────────────────────
_load_modules() {
  local base="${WGX_DIR:-}"
  if [ -z "$base" ]; then
    base="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  fi
  local d="${base}/modules"
  if [ -d "$d" ]; then
    for f in "$d"/*.bash; do
      # shellcheck source=/dev/null
      [ -r "$f" ] && source "$f"
    done
  fi
}

# ---------- Git helpers ----------
git_current_branch() { git rev-parse --abbrev-ref HEAD 2>/dev/null || echo ""; }
git_is_repo_root() {
  # We intentionally use `pwd` instead of `pwd -P` to avoid resolving
  # symlinks, which simplifies behavior and aligns with the project's focus on
  # straightforward, common use cases.
  local top
  top=$(git rev-parse --show-toplevel 2>/dev/null) || return 1
  [ "$(pwd)" = "$top" ]
}
git_has_remote() {
  local remote="${1:-origin}"
  git remote 2>/dev/null | grep -qx "$remote"
}

# Hard Reset auf origin/$WGX_BASE + Cleanup
git_workdir_dirty() {
  git status --porcelain=v1 --untracked-files=normal 2>/dev/null | grep -q .
}

git_workdir_status_short() {
  git status --short 2>/dev/null || true
}

# Helper: Finde den ersten existierenden Remote-Branch aus einer Kandidatenliste
_git_resolve_branch() {
  local remote="$1"
  shift
  local candidate
  for candidate in "$@"; do
    [ -z "$candidate" ] && continue
    if git rev-parse --verify "${remote}/${candidate}" >/dev/null 2>&1; then
      printf '%s' "$candidate"
      return 0
    fi
  done
  return 1
}

_git_parse_remote_branch_spec() {
  local spec="$1"
  local default_remote="${2:-origin}"
  local remote="$default_remote"
  local branch="$spec"

  if [ -z "$branch" ]; then
    printf '%s %s\n' "$remote" ""
    return 0
  fi

  if [[ "$spec" == */* ]]; then
    local candidate_remote="${spec%%/*}"
    local candidate_branch="${spec#*/}"
    if git remote 2>/dev/null | grep -qx "$candidate_remote"; then
      remote="$candidate_remote"
      branch="$candidate_branch"
    fi
  fi

  printf '%s %s\n' "$remote" "$branch"
}

git_hard_reload() {
  if ! git remote -v | grep -q . 2>/dev/null; then
    die "Kein Remote-Repository konfiguriert."
  fi

  # 1. Argumente parsen
  local dry_run=0 base=""
  while [ $# -gt 0 ]; do
    case "$1" in
    --dry-run | -n)
      dry_run=1
      ;;
    --)
      shift
      break
      ;;
    -*)
      die "git_hard_reload: unerwartetes Argument '$1'"
      ;;
    *)
      if [ -z "$base" ]; then
        base="$1"
      else
        die "git_hard_reload: zu viele Argumente"
      fi
      ;;
    esac
    shift
  done

  debug "git_hard_reload: dry_run=${dry_run} base='${base}'"

  if ((dry_run)); then
    local remote target_branch base_branch full_ref
    if [ -n "$base" ]; then
      read -r remote base_branch < <(_git_parse_remote_branch_spec "$base" "origin")
      [ -z "$remote" ] && remote="origin"
      if [ -z "$base_branch" ]; then
        die "git_hard_reload: Ungültiger Basis-Branch '${base}'."
      fi
      target_branch="$base_branch"
    else
      local upstream
      upstream="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"
      if [ -n "$upstream" ]; then
        remote="${upstream%%/*}"
        target_branch="${upstream#*/}"
      else
        remote="origin"
        target_branch="${WGX_BASE:-main}"
      fi
    fi

    full_ref="${remote}/${target_branch}"
    info "[DRY-RUN] Geplante Schritte:"
    info "[DRY-RUN] git fetch --all --prune"
    info "[DRY-RUN] git reset --hard ${full_ref}"
    info "[DRY-RUN] git clean -fdx"
    ok "[DRY-RUN] Reload fertig (${full_ref})."
    return 0
  fi

  info "Fetch von allen Remotes (inkl. prune)…"
  debug "git_hard_reload: running 'git fetch --all --prune'"
  git fetch --all --prune || die "git fetch fehlgeschlagen"

  local remote target_branch base_branch
  if [ -n "$base" ]; then
    read -r remote base_branch < <(_git_parse_remote_branch_spec "$base" "origin")
    debug "git_hard_reload: parsed base spec '${base}' -> remote='${remote}' branch='${base_branch}'"
    if [ -z "$base_branch" ]; then
      die "git_hard_reload: Ungültiger Basis-Branch '${base}'."
    fi
    target_branch="$(_git_resolve_branch "$remote" "$base_branch")"
    if [ -z "$target_branch" ]; then
      die "git_hard_reload: Branch '${base}' nicht auf '${remote}' gefunden."
    fi
  else
    local upstream
    upstream="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"
    if [ -n "$upstream" ]; then
      remote="${upstream%%/*}"
      target_branch="${upstream#*/}"
    else
      remote="origin"
      target_branch="$(_git_resolve_branch "$remote" "$WGX_BASE" "main" "master")"
    fi
  fi

  if [ -z "$target_branch" ]; then
    die "git_hard_reload: Konnte keinen gültigen Ziel-Branch finden."
  fi

  local full_ref="${remote}/${target_branch}"
  debug "git_hard_reload: resolved remote ref '${full_ref}'"

  info "Kompletter Reset auf ${full_ref}… (alle lokalen Änderungen gehen verloren)"
  debug "git_hard_reload: running 'git reset --hard ${full_ref}'"
  git reset --hard "${full_ref}" || die "git reset --hard fehlgeschlagen"

  info "Untracked & ignorierte Dateien/Verzeichnisse bereinigen (clean -fdx)…"
  debug "git_hard_reload: running 'git clean -fdx'"
  git clean -fdx || die "git clean fehlgeschlagen"

  ok "Reload fertig (${full_ref})."
  return 0
}

# Optional: Safety Snapshot (Stash), nicht default-aktiv
snapshot_make() {
  git stash push -u -m "wgx snapshot $(date -u +%FT%TZ)" >/dev/null 2>&1 || true
  info "Snapshot (Stash) erstellt."
}

# ---------- Router ----------
wgx_command_files() {
  [ -d "$WGX_DIR/cmd" ] || return 0
  for f in "$WGX_DIR/cmd"/*.bash; do
    [ -r "$f" ] || continue
    printf '%s\n' "$f"
  done
}

wgx_available_commands() {
  local -a cmds
  cmds=(help)
  local file name
  while IFS= read -r file; do
    name=$(basename "$file")
    name=${name%.bash}
    cmds+=("$name")
  done < <(wgx_command_files)

  printf '%s\n' "${cmds[@]}" | sort -u
}

wgx_print_command_list() {
  while IFS= read -r cmd; do
    printf '  %s\n' "$cmd"
  done < <(wgx_available_commands)
}

wgx_usage() {
  cat <<USAGE
wgx — Workspace Helper

Usage:
  wgx <command> [args]

Commands:
$(wgx_print_command_list)

Env:
  WGX_BASE       Basis-Branch für reload (default: main)

More:
  wgx --list     Nur verfügbare Befehle anzeigen

USAGE
}

# ── Command dispatcher ──────────────────────────────────────────────────────
wgx_main() {
  if (($# == 0)); then
    wgx_usage
    return 1
  fi

  local sub="$1"
  shift || true

  case "$sub" in
  help | -h | --help)
    wgx_usage
    return 0
    ;;
  --list | commands)
    wgx_available_commands
    return 0
    ;;
  esac

  _load_modules

  # 1) Direkter Funktionsaufruf: cmd_<sub>
  if declare -F "cmd_${sub}" >/dev/null 2>&1; then
    "cmd_${sub}" "$@"
    return
  fi

  # 2) Datei sourcen und erneut versuchen
  local f="${WGX_DIR}/cmd/${sub}.bash"
  if [ -r "$f" ]; then
    # shellcheck source=/dev/null
    source "$f"
    if declare -F "cmd_${sub}" >/dev/null 2>&1; then
      "cmd_${sub}" "$@"
    elif declare -F "wgx_command_main" >/dev/null 2>&1; then
      wgx_command_main "$@"
    else
      echo "❌ Befehl '${sub}': weder cmd_${sub} noch wgx_command_main definiert." >&2
      return 127
    fi
    return
  fi

  echo "❌ Unbekannter Befehl: ${sub}" >&2
  wgx_usage >&2
  return 1
}
```

### 📄 lib/hauski.bash

**Größe:** 1002 B | **md5:** `9acf403404b3bf719ec29f5317b0802c`

```bash
#!/usr/bin/env bash

hauski::enabled() {
  [[ ${HAUSKI_ENABLE:-0} != 0 ]]
}

hauski::emit() {
  hauski::enabled || return 0
  local event="${1:-}" payload="${2:-{}}"
  if [[ -z "$event" ]]; then
    return 1
  fi
  if ! command -v curl >/dev/null 2>&1; then
    return 0
  fi
  if ! command -v python3 >/dev/null 2>&1; then
    return 0
  fi
  local timestamp
  timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  local body
  body=$(python3 - "$event" "$payload" "$timestamp" <<'PY'
import json
import sys

event = sys.argv[1]
payload_raw = sys.argv[2]
timestamp = sys.argv[3]
try:
    payload = json.loads(payload_raw)
except Exception:
    payload = {"raw": payload_raw}
print(json.dumps({"event": event, "timestamp": timestamp, "payload": payload}))
PY
)
  curl -fsS -X POST -H 'Content-Type: application/json' \
    --connect-timeout 1 \
    --max-time 2 \
    --retry 0 \
    --data "$body" \
    http://127.0.0.1:7070/v1/events >/dev/null 2>&1 && \
    printf 'hauski: delivered %s\n' "$event" >&2
}
```
```

### 📄 merges/wgx_merge_2510262237__modules.md

**Größe:** 39 KB | **md5:** `b21b24b253d0104e77ff441dbf2c378b`

```markdown
### 📄 modules/.gitkeep

**Größe:** 0 B | **md5:** `d41d8cd98f00b204e9800998ecf8427e`

```plaintext

```

### 📄 modules/doctor.bash

**Größe:** 820 B | **md5:** `a958c1fb9af2d24cdc5f1a53f9a751e4`

```bash
#!/usr/bin/env bash

# Doctor module: basic repository health checks

doctor_cmd() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    cat <<'USAGE'
Usage:
  wgx doctor

Description:
  Führt eine grundlegende Diagnose des Repositorys und der Umgebung durch.
  Prüft, ob 'git' installiert ist, ob der Befehl innerhalb eines Git-Worktrees
  ausgeführt wird und ob ein 'origin'-Remote konfiguriert ist.

Options:
  -h, --help    Diese Hilfe anzeigen.
USAGE
    return 0
  fi

  if ! command -v git >/dev/null 2>&1; then
    echo "❌ git fehlt." >&2
    return 1
  fi

  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "❌ nicht im Git-Repo." >&2
    return 1
  fi

  if ! git remote -v | grep -q '^origin'; then
    echo "⚠️ Kein origin-Remote." >&2
  fi

  echo "✅ WGX Doctor OK."
}
```

### 📄 modules/env.bash

**Größe:** 5 KB | **md5:** `375c3b2fac777ac9a2975ff139910daf`

```bash
#!/usr/bin/env bash
set -e
set -u
set -E
if ! set -o pipefail 2>/dev/null; then
  if [[ ${WGX_DEBUG:-0} != 0 ]]; then
    echo "env module: 'pipefail' wird nicht unterstützt; fahre ohne fort." >&2
  fi
fi

export LC_ALL="${LC_ALL:-C}"

# Environment inspection utilities.

env::_detect_platform() {
  local name
  if command -v uname >/dev/null 2>&1; then
    name="$(uname -s 2>/dev/null || echo unknown)"
  else
    name="unknown"
  fi
  printf '%s' "$name"
}

env::_is_termux() {
  [[ -n ${TERMUX_VERSION:-} ]] && return 0
  [[ ${PREFIX:-} == */com.termux/* ]] && return 0
  [[ -n ${ANDROID_ROOT:-} && -n ${ANDROID_DATA:-} ]] && [[ ${HOME:-} == */com.termux/* ]] && return 0
  return 1
}

env::_have() {
  command -v "$1" >/dev/null 2>&1
}

env::_tool_status() {
  local tool="$1" label="${2:-$1}"
  shift 2 || true
  if env::_have "$tool"; then
    local version=""
    if (($#)); then
      version="$("$@" 2>/dev/null | head -n1 | tr -d '\r')"
    fi
    if [[ -n $version ]]; then
      printf '• %s: available (%s)\n' "$label" "$version"
    else
      printf '• %s: available\n' "$label"
    fi
  else
    printf '• %s: missing\n' "$label"
  fi
}

env::_doctor_report() {
  local platform
  platform="$(env::_detect_platform)"
  printf '=== wgx env doctor (%s) ===\n' "$platform"
  printf 'WGX_DIR : %s\n' "${WGX_DIR:-$(pwd)}"
  printf 'OFFLINE : %s\n' "${OFFLINE:-0}"
  env::_tool_status git "git" git --version
  env::_tool_status gh "gh" gh --version
  env::_tool_status glab "glab" glab --version
  env::_tool_status node "node" node --version
  env::_tool_status npm "npm" npm --version
  env::_tool_status python3 "python3" python3 --version
  env::_tool_status uv "uv" uv --version
  env::_tool_status docker "docker" docker --version
  printf '\nPaths:\n'
  printf '  PATH: %s\n' "${PATH:-}"
}

env::_json_escape() {
  local s="${1-}"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '"%s"' "$s"
}

env::_doctor_json() {
  printf '{'
  printf '"platform":'
  env::_json_escape "$(env::_detect_platform)"
  printf ',"offline":'
  env::_json_escape "${OFFLINE:-0}"
  printf ',"tools":{'
  local first=1
  local tool
  for tool in git gh glab node npm python3 uv docker; do
    local have="missing" ver=""
    if env::_have "$tool"; then
      have="available"
      case "$tool" in
      git) ver="$(git --version 2>/dev/null | head -n1)" ;;
      gh) ver="$(gh --version 2>/dev/null | head -n1)" ;;
      glab) ver="$(glab --version 2>/dev/null | head -n1)" ;;
      node) ver="$(node --version 2>/dev/null | head -n1)" ;;
      npm) ver="$(npm --version 2>/dev/null | head -n1)" ;;
      python3) ver="$(python3 --version 2>/dev/null | head -n1)" ;;
      uv) ver="$(uv --version 2>/dev/null | head -n1)" ;;
      docker) ver="$(docker --version 2>/dev/null | head -n1)" ;;
      esac
    fi
    ((first)) || printf ','
    first=0
    printf '"%s":{' "$tool"
    printf '"status":'
    env::_json_escape "$have"
    printf ',"version":'
    env::_json_escape "$ver"
    printf '}'
  done
  printf '},"path":'
  env::_json_escape "${PATH:-}"
  printf '}'
  printf '\n'
}

env::_termux_fixups() {
  local rc=0
  if ! env::_have git; then
    warn "git is not available – unable to apply git defaults."
    return 1
  fi

  if git config --global --get core.filemode >/dev/null 2>&1; then
    log_info "git core.filemode already configured."
  else
    if git config --global core.filemode false >/dev/null 2>&1; then
      log_info "Configured git core.filemode=false for Termux."
    else
      warn "Failed to configure git core.filemode for Termux."
      rc=1
    fi
  fi

  return $rc
}

env::_fix_unsupported_msg() {
  printf '%s\n' "--fix is currently only supported on Termux"
}

env::_apply_fixes() {
  if env::_is_termux; then
    if env::_termux_fixups; then
      ok "Termux fixes applied."
      return 0
    fi
    warn "Some Termux fixes failed."
    return 1
  fi

  env::_fix_unsupported_msg
  return 0
}

env_cmd() {
  local sub="doctor" fix=0 strict=0 json=0
  local apply_fixes=0

  while (($#)); do
    case "$1" in
    doctor)
      sub="doctor"
      ;;
    --fix)
      fix=1
      ;;
    --strict)
      strict=1
      ;;
    --json)
      json=1
      ;;
    -h | --help)
      cat <<'USAGE'
Usage: wgx env doctor [--fix] [--strict] [--json]
  doctor     Inspect the local environment (default)
  --fix      Apply recommended platform specific tweaks (Termux only)
  --strict   Exit non-zero if essential tools are missing (e.g., git)
  --json     Machine-readable output (minimal JSON)
USAGE
      return 0
      ;;
    --)
      shift
      break
      ;;
    *)
      die "Usage: wgx env doctor [--fix] [--strict] [--json]"
      ;;
    esac
    shift
  done

  if ((fix)); then
    if env::_is_termux; then
      apply_fixes=1
    else
      env::_fix_unsupported_msg
    fi
  fi

  case "$sub" in
  doctor)
    if ((json)); then
      env::_doctor_json
    else
      env::_doctor_report
    fi
    if ((apply_fixes)); then
      env::_apply_fixes || return $?
    fi
    if [[ $strict -ne 0 ]]; then
      if ! env::_have git; then
        warn "git missing (strict mode)"
        return 2
      fi
    fi
    return 0
    ;;
  *)
    die "Usage: wgx env doctor [--fix] [--strict] [--json]"
    ;;
  esac
}

wgx_command_main() {
  env_cmd "$@"
}
```

### 📄 modules/guard.bash

**Größe:** 4 KB | **md5:** `3685345b73710f7536b20fb86df0915e`

```bash
#!/usr/bin/env bash

# Guard-Modul: Lint- und Testläufe (aus Monolith portiert)

_guard_command_available() {
  local name="$1"
  if declare -F "cmd_${name}" >/dev/null 2>&1; then
    return 0
  fi
  local base_dir="${WGX_DIR:-"$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"}"
  [[ -r "${base_dir}/cmd/${name}.bash" ]]
}

_guard_require_file() {
  local path="$1" message="$2"
  if [[ -f "$path" ]]; then
    printf '  • %s ✅\n' "$message"
    return 0
  fi
  printf '  ✗ %s missing\n' "$message" >&2
  return 1
}

guard_run() {
  local run_lint=0 run_test=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
    --lint) run_lint=1 ;;
    --test) run_test=1 ;;
    -h | --help)
      cat <<'USAGE'
Usage:
  wgx guard [--lint] [--test]

Description:
  Führt eine Reihe von Sicherheits- und Qualitätsprüfungen für das Repository aus.
  Dies ist ein Sicherheitsnetz, das vor dem Erstellen eines Pull Requests ausgeführt wird.
  Standardmäßig werden sowohl Linting als auch Tests ausgeführt.

Checks:
  - Sucht nach potentiellen Secrets im Staging-Bereich.
  - Sucht nach verbleibenden Konfliktmarkern im Code.
  - Prüft auf übergroße Dateien (>= 1MB).
  - Verifiziert das Vorhandensein von wichtigen Repository-Dateien (z.B. uv.lock).
  - Führt 'wgx lint' aus (falls --lint angegeben oder Standard).
  - Führt 'wgx test' aus (falls --test angegeben oder Standard).

Options:
  --lint        Nur die Linting-Prüfungen ausführen.
  --test        Nur die Test-Prüfungen ausführen.
  -h, --help    Diese Hilfe anzeigen.
USAGE
      return 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      return 1
      ;;
    esac
    shift
  done

  # Standard: beides
  if [[ $run_lint -eq 0 && $run_test -eq 0 ]]; then
    run_lint=1
    run_test=1
  fi

  # 1. Staged Secrets checken
  echo "▶ Checking for secrets..."
  if git diff --cached | grep -E "AKIA|SECRET|PASSWORD" >/dev/null; then
    echo "❌ Potentielles Secret im Commit gefunden!" >&2
    return 1
  fi

  # 2. Konfliktmarker checken
  echo "▶ Checking for conflict markers..."
  if grep -R -E '^(<<<<<<< |=======|>>>>>>> )' . --exclude-dir=.git >/dev/null 2>&1; then
    echo "❌ Konfliktmarker gefunden!" >&2
    return 1
  fi

  # 3. Bigfiles checken
  echo "▶ Checking for oversized files..."
  if git ls-files -z |
    xargs -0 du -sb 2>/dev/null |
    awk 'BEGIN { found = 0 } $1 >= 1048576 { print; found = 1 } END { exit(found ? 0 : 1) }'; then
    echo "❌ Zu große Dateien im Repo!" >&2
    return 1
  fi

  # 4. Repository Guard-Checks
  echo "▶ Verifying repository guard checklist..."
  local checklist_ok=1
  _guard_require_file "uv.lock" "uv.lock vorhanden" || checklist_ok=0
  _guard_require_file ".github/workflows/shell-docs.yml" "Shell/Docs CI-Workflow vorhanden" || checklist_ok=0
  _guard_require_file "templates/profile.template.yml" "Profile-Template vorhanden" || checklist_ok=0
  _guard_require_file "docs/Runbook.md" "Runbook dokumentiert" || checklist_ok=0
  if [[ $checklist_ok -eq 0 ]]; then
    echo "❌ Guard checklist failed." >&2
    return 1
  fi

  # 5. Lint (wenn gewünscht)
  if [[ $run_lint -eq 1 ]]; then
    if _guard_command_available lint; then
      echo "▶ Running lint checks..."
      ./wgx lint || return 1
    else
      echo "⚠️ lint command not available, skipping lint step." >&2
    fi
  fi

  # 6. Tests (wenn gewünscht)
  if [[ $run_test -eq 1 ]]; then
    if _guard_command_available test; then
      echo "▶ Running tests..."
      ./wgx test || return 1
    else
      echo "⚠️ test command not available, skipping test step." >&2
    fi
  fi

  echo "✔ Guard finished successfully."
}
```

### 📄 modules/json.bash

**Größe:** 445 B | **md5:** `77f7435663d5da94f27da6d5b902ec82`

```bash
#!/usr/bin/env bash

# shellcheck shell=bash

json_escape() {
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$1" <<'PY'
import json
import sys
print(json.dumps(sys.argv[1])[1:-1])
PY
  else
    printf '%s' "$1"
  fi
}

json_quote() {
  printf '"%s"' "$(json_escape "$1")"
}

json_bool_value() {
  [[ $1 == true || $1 == false ]] || die "invalid boolean: $1"
  printf '%s' "$1"
}

json_join() {
  local IFS=','
  printf '%s' "$*"
}
```

### 📄 modules/profile.bash

**Größe:** 31 KB | **md5:** `3ae38a282841f90aa903b41665abf4cd`

```bash
#!/usr/bin/env bash

# shellcheck shell=bash

PROFILE_FILE=""
PROFILE_VERSION=""
WGX_REQUIRED_RANGE=""
WGX_REQUIRED_MIN=""
WGX_REPO_KIND=""
WGX_DIR_WEB=""
WGX_DIR_API=""
WGX_DIR_DATA=""
WGX_PROFILE_LOADED=""

# shellcheck disable=SC2034
WGX_AVAILABLE_CAPS=(task-array status-dirs tasks-json validate env-defaults env-overrides workflows)

declare -ga WGX_REQUIRED_CAPS=()
declare -ga WGX_ENV_KEYS=()

declare -gA WGX_ENV_BASE_MAP=()
declare -gA WGX_ENV_DEFAULT_MAP=()
declare -gA WGX_ENV_OVERRIDE_MAP=()

declare -ga WGX_TASK_ORDER=()
declare -gA WGX_TASK_CMDS=()
declare -gA WGX_TASK_DESC=()
declare -gA WGX_TASK_GROUP=()
declare -gA WGX_TASK_SAFE=()

declare -gA WGX_WORKFLOW_TASKS=()

profile::_reset() {
  PROFILE_VERSION=""
  WGX_REQUIRED_RANGE=""
  WGX_REQUIRED_MIN=""
  WGX_REPO_KIND=""
  WGX_DIR_WEB=""
  WGX_DIR_API=""
  WGX_DIR_DATA=""
  WGX_REQUIRED_CAPS=()
  WGX_ENV_KEYS=()
  WGX_TASK_ORDER=()
  WGX_ENV_BASE_MAP=()
  WGX_ENV_DEFAULT_MAP=()
  WGX_ENV_OVERRIDE_MAP=()
  WGX_TASK_CMDS=()
  WGX_TASK_DESC=()
  WGX_TASK_GROUP=()
  WGX_TASK_SAFE=()
  WGX_WORKFLOW_TASKS=()
  WGX_PROFILE_LOADED=""
}

profile::_detect_file() {
  PROFILE_FILE=""
  local base
  for base in ".wgx/profile.yml" ".wgx/profile.yaml" ".wgx/profile.json"; do
    if [[ -f $base ]]; then
      PROFILE_FILE="$base"
      return 0
    fi
  done
  return 1
}

profile::_have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

profile::_abspath() {
  local p="$1" resolved=""
  if profile::_have_cmd python3; then
    if resolved="$(python3 - "$p" <<'PY' 2>/dev/null
import os
import sys

print(os.path.abspath(sys.argv[1]))
PY
)"; then
      if [[ -n $resolved ]]; then
        printf '%s\n' "$resolved"
        return 0
      fi
    fi
  fi
  if command -v readlink >/dev/null 2>&1; then
    resolved="$(readlink -f -- "$p" 2>/dev/null || true)"
    if [[ -n $resolved ]]; then
      printf '%s\n' "$resolved"
    else
      printf '%s\n' "$p"
    fi
    return 0
  fi
  printf '%s\n' "$p"
}

profile::_normalize_task_name() {
  local name="$1"
  name="${name//_/ -}"
  name="${name// /}"
  printf '%s' "${name,,}"
}

profile::_python_parse() {
  local file="$1" output
  profile::_have_cmd python3 || return 1
  output="$(
    python3 - "$file" <<'PY'
import ast
import json
import os
import shlex
import sys
from typing import Any, Dict, List


def _parse_scalar(value: str) -> Any:
    text = value.strip()
    if text == "":
        return ""
    lowered = text.lower()
    if lowered in {"true", "yes"}:
        return True
    if lowered in {"false", "no"}:
        return False
    if lowered in {"null", "none", "~"}:
        return None
    try:
        return ast.literal_eval(text)
    except Exception:
        return text


def _convert_frame(frame: Dict[str, Any], kind: str) -> None:
    if frame["type"] == kind:
        return
    parent = frame["parent"]
    key = frame["key"]
    if kind == "list":
        new_value: List[Any] = []
        if parent is None:
            frame["container"] = new_value
        elif isinstance(parent, list):
            parent[key] = new_value
        else:
            parent[key] = new_value
        frame["container"] = new_value
        frame["type"] = "list"
    else:
        new_value: Dict[str, Any] = {}
        if parent is None:
            frame["container"] = new_value
        elif isinstance(parent, list):
            parent[key] = new_value
        else:
            parent[key] = new_value
        frame["container"] = new_value
        frame["type"] = "dict"


def _parse_simple_yaml(path: str) -> Any:
    root: Dict[str, Any] = {}
    stack: List[Dict[str, Any]] = [
        {"indent": -1, "container": root, "parent": None, "key": None, "type": "dict"}
    ]

    with open(path, "r", encoding="utf-8") as handle:
        for raw_line in handle:
            line = raw_line.rstrip("\n")
            stripped = line.split("#", 1)[0].rstrip()
            if not stripped:
                continue
            indent = len(line) - len(line.lstrip(" "))
            content = stripped.lstrip()

            while len(stack) > 1 and indent <= stack[-1]["indent"]:
                stack.pop()

            frame = stack[-1]
            container = frame["container"]

            if content.startswith("- "):
                value_part = content[2:].strip()
                _convert_frame(frame, "list")
                container = frame["container"]
                if not value_part:
                    item: Dict[str, Any] = {}
                    container.append(item)
                    stack.append(
                        {
                            "indent": indent,
                            "container": item,
                            "parent": container,
                            "key": len(container) - 1,
                            "type": "dict",
                        }
                    )
                    continue
                if value_part.endswith(":") or ": " in value_part:
                    key, rest = value_part.split(":", 1)
                    key = key.strip()
                    rest = rest.strip()
                    item: Dict[str, Any] = {}
                    container.append(item)
                    frame_item = {
                        "indent": indent,
                        "container": item,
                        "parent": container,
                        "key": len(container) - 1,
                        "type": "dict",
                    }
                    stack.append(frame_item)
                    if rest:
                        item[key] = _parse_scalar(rest)
                    else:
                        item[key] = {}
                        stack.append(
                            {
                                "indent": indent,
                                "container": item[key],
                                "parent": item,
                                "key": key,
                                "type": "dict",
                            }
                        )
                    continue
                container.append(_parse_scalar(value_part))
                continue

            if content.endswith(":") or ": " in content:
                key, value_part = content.split(":", 1)
                key = key.strip()
                value_part = value_part.strip()
                _convert_frame(frame, "dict")
                container = frame["container"]
                if value_part == "":
                    container[key] = {}
                    stack.append(
                        {
                            "indent": indent,
                            "container": container[key],
                            "parent": container,
                            "key": key,
                            "type": "dict",
                        }
                    )
                else:
                    container[key] = _parse_scalar(value_part)
                continue

            if isinstance(container, list):
                container.append(_parse_scalar(content))
            elif isinstance(container, dict):
                container[content] = True

    return root


def _load_manifest(path: str) -> Any:
    _, ext = os.path.splitext(path)
    ext = ext.lower()
    if ext in {".yaml", ".yml"}:
        try:
            import yaml  # type: ignore
        except Exception:
            try:
                return _parse_simple_yaml(path)
            except Exception:
                return {}
        with open(path, "r", encoding="utf-8") as handle:
            return yaml.safe_load(handle) or {}
    if ext == ".json":
        with open(path, "r", encoding="utf-8") as handle:
            return json.load(handle) or {}
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle) or {}


path = sys.argv[1]
data = _load_manifest(path) or {}

wgx = data.get('wgx')
if not isinstance(wgx, dict):
    wgx = {}

# Backwards compatibility: allow certain keys (e.g. tasks) at the top level.
# Older profiles stored "tasks" directly on the root object. Newer profiles nest
# them inside the "wgx" block. We support both to avoid breaking existing
# repositories.
root_tasks = data.get('tasks') if isinstance(data, dict) else None
root_repo_kind = data.get('repoKind') if isinstance(data, dict) else None
root_dirs = data.get('dirs') if isinstance(data, dict) else None
root_env = data.get('env') if isinstance(data, dict) else None
root_env_defaults = data.get('envDefaults') if isinstance(data, dict) else None
root_env_overrides = data.get('envOverrides') if isinstance(data, dict) else None
root_workflows = data.get('workflows') if isinstance(data, dict) else None

platform_keys = []
plat = sys.platform
if plat.startswith('darwin'):
    platform_keys.append('darwin')
elif plat.startswith('linux'):
    platform_keys.append('linux')
elif plat.startswith('win'):
    platform_keys.append('win32')
elif plat.startswith('cygwin') or plat.startswith('msys'):
    platform_keys.append('win32')
platform_keys.append('default')

def select_variant(value):
    if isinstance(value, dict):
        for key in platform_keys:
            if key in value and value[key] not in (None, ''):
                return value[key]
        for entry in value.values():
            if entry not in (None, ''):
                return entry
        return None
    return value

def as_bool(value):
    if isinstance(value, bool):
        return value
    if isinstance(value, int):
        return value != 0
    if isinstance(value, str):
        return value.strip().lower() in ("1", "true", "yes", "on")
    return False

def normalize_list(value):
    if value is None:
        return []
    if isinstance(value, (list, tuple)):

<<TRUNCATED: max_file_lines=800>>
```

### 📄 merges/wgx_merge_2510262237__part001.md

**Größe:** 43 B | **md5:** `ad150e6cdda3920dbef4d54c92745d83`

```markdown
<!-- chunk:1 created:2025-10-26 22:37 -->
```

### 📄 merges/wgx_merge_2510262237__policies.md

**Größe:** 1 KB | **md5:** `6c676e74e0977bb095d6a672b9a0463f`

```markdown
### 📄 policies/deny.toml

**Größe:** 250 B | **md5:** `aaa94e21b7604b738348fb00d4bf7cb3`

```toml
[graph]
depth = 5

[bans]
bare_version = "deny"
multiple_versions = "deny"

[licenses]
allow = ["MIT", "Apache-2.0", "BSD-3-Clause", "BSD-2-Clause"]

[advisories]
vulnerability = "deny"
unmaintained = "deny"
yanked = "deny"

[exceptions]
crates = []
```

### 📄 policies/perf.json

**Größe:** 399 B | **md5:** `4d21b279ff5b7439b4145e458e136eb9`

```json
{
  "version": 1,
  "scripts": {
    "wgx:build": {
      "budget_ms": 120000,
      "description": "Full build should complete within two minutes"
    },
    "wgx:test": {
      "budget_ms": 1200000,
      "description": "Unit test suite should complete within twenty minutes"
    },
    "wgx:lint": {
      "budget_ms": 60000,
      "description": "Linting must stay under one minute"
    }
  }
}
```

### 📄 policies/slo.yaml

**Größe:** 165 B | **md5:** `9dfb58ec10e4150d1677150d22dc2fab`

```yaml
version: 1
ci:
  max_runtime_minutes: 30
  max_memory_mb: 4096
  actions:
    - name: unit-tests
      timeout_minutes: 20
    - name: lint
      timeout_minutes: 5
```
```

### 📄 merges/wgx_merge_2510262237__root.md

**Größe:** 18 KB | **md5:** `624698f00c523583cc9a5bfd3c89c58c`

```markdown
### 📄 .editorconfig

**Größe:** 188 B | **md5:** `9300170d1d2d72e9e9f67c4654217ad2`

```plaintext
root = true

[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
indent_style = space
indent_size = 2
trim_trailing_whitespace = true

[*.md]
trim_trailing_whitespace = false
```

### 📄 .gitattributes

**Größe:** 36 B | **md5:** `e6d0d1ca3507da50046da02aa2380b7b`

```plaintext
* text=auto eol=lf
*.sh text eol=lf
```

### 📄 .gitignore

**Größe:** 523 B | **md5:** `6e3c88d693b1164ff0c8d588b72a53d6`

```plaintext
# Logs & tmp
*.log
*.bak
*.swp
.DS_Store
.tmp/
metrics.json

# Local helper state
/.local/

# Local wgx profiles
.wgx/profile.yml
.wgx/profile.yaml
.wgx/profile.json

# Audit temp signatures
.wgx/audit/*.sig
.wgx/audit/ledger.jsonl

# Local cache directory (created by helper scripts)
/.local/*
!/.local/README.md

# Generated readiness artifacts (published via CI)
/artifacts/readiness.json
/artifacts/readiness-table.md
/artifacts/readiness-badge.svg

# Generated artifact directory (covers future additions)
/artifacts/
```

### 📄 .markdownlint.jsonc

**Größe:** 110 B | **md5:** `40b09b9f7920446e079580c72126008c`

```plaintext
{
  "default": true,
  "MD013": { "line_length": 120, "tables": false },
  "MD033": false,
  "MD041": false
}
```

### 📄 .pre-commit-config.yaml

**Größe:** 560 B | **md5:** `7979245efaf30c9ac79954b1cc725b99`

```yaml
repos:
  - repo: https://github.com/jumanjihouse/pre-commit-hooks
    rev: v4.2.0
    hooks:
      - id: shellcheck
        args: ["-S", "style"]
        files: "\\.(sh|bash)$"
      - id: shfmt
        args: ["-i", "2", "-ci", "-sr"]
        files: "\\.(sh|bash)$"
  - repo: https://github.com/igorshubovych/markdownlint-cli
    rev: v0.43.0
    hooks:
      - id: markdownlint
        files: "\\.(md|mdx)$"
  - repo: https://github.com/errata-ai/vale
    rev: v3.8.0
    hooks:
      - id: vale
        args: ["--no-exit", "."]
        files: "\\.(md|mdx)$"
```

### 📄 .vale.ini

**Größe:** 253 B | **md5:** `134893adb24951cb75e06d5ec76d1f78`

```plaintext
StylesPath = .vale/styles
MinAlertLevel = warning

# Code-Dateien (ohne Shell)
[*.{rs,ts,js,py}]
BasedOnStyles = wgxlint

[*.{md,mdx}]
BasedOnStyles = hauski/GermanProse

# Shell-Skripte (inkl. .bash)
[*.{sh,bash}]
BasedOnStyles = hauski/GermanComments
```

### 📄 CHANGELOG.md

**Größe:** 132 B | **md5:** `fa56d43184094ef2755ce69e0c5f8713`

```markdown
# Changelog

## 2.0.0 (YYYY-MM-DD)
- Initiale modulare Struktur; Shell & Docs CI; UV-Frozen-Sync in CI; guard-Checks; Runbook-Stub.
```

### 📄 CONTRIBUTING.md

**Größe:** 2 KB | **md5:** `9575003f4de752a6859d137b774655cc`

```markdown
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
markdownlint $(git ls-files "*.md" "*.mdx")
vale .
```

> Tipp: `pre-commit install` setzt das als Hook vor jeden Commit.
```

### 📄 Justfile

**Größe:** 1 KB | **md5:** `d97fb596e4c9f9a7fd4d2a59bcfeb1ac`

```plaintext
set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

default: devcontainer-check

devcontainer-check:
    .devcontainer/setup.sh check

devcontainer-install:
    .devcontainer/setup.sh install all

METRICS_SCHEMA_URL := "https://raw.githubusercontent.com/heimgewebe/metarepo/contracts-v1/contracts/wgx/metrics.json"

wgx command +args:
    case "$command" in \
      metrics)
        just wgx-metrics {{args}}
        ;;
      *)
        echo "Unbekannter wgx-Befehl: $command" >&2
        exit 1
        ;;
    esac

wgx-metrics subcommand +args:
    case "$subcommand" in \
      snapshot)
        scripts/wgx-metrics-snapshot.sh {{args}}
        ;;
      *)
        echo "Unbekannter wgx metrics-Befehl: $subcommand" >&2
        exit 1
        ;;
    esac

contracts action +args:
    case "$action" in \
      validate)
        npx --yes ajv-cli@5 validate -s "${METRICS_SCHEMA_URL}" -d metrics.json {{args}}
        ;;
      *)
        echo "Unbekannter contracts-Befehl: $action" >&2
        exit 1
        ;;
    esac
```

### 📄 LICENSE

**Größe:** 1 KB | **md5:** `b1badb0d593eb56678704b11a573ddb2`

```plaintext
MIT License

Copyright (c) 2025 weltweberei.org

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
```

### 📄 README.md

**Größe:** 11 KB | **md5:** `8d5d0df49ae36a6d09ead11412777467`

```markdown
![WGX](https://img.shields.io/badge/wgx-enabled-blue)

# wgx – Weltgewebe CLI

Eigenständiges CLI für Git-/Repo-Workflows (Termux, WSL, Linux, macOS). License: MIT; intended for internal use but repository is publicly visible.

## Lizenz & Nutzung

Dieses Repository steht unter der **MIT-Lizenz** (siehe `./LICENSE`).
Die Lizenzdatei bleibt **unverändert**, damit gängige Tools die Lizenz korrekt erkennen.

**Beabsichtigte Nutzung:** WGX ist primär für den internen Einsatz innerhalb der
heimgewebe-Ökosphäre gedacht, das Repository ist jedoch öffentlich sichtbar.
Diese Klarstellung ändert **nicht** die Lizenzrechte, sondern dient nur der
Transparenz bezüglich Support-Erwartungen und Projektfokus.

**Hinweis für Beiträge/Dateiköpfe:** In neuen Dateien bitte nach Möglichkeit den
SPDX-Kurzidentifier verwenden, z. B.:

```
# SPDX-License-Identifier: MIT
```

## Schnellstart

> 📘 **Sprach-Policy:** Neue Beiträge sollen derzeit deutschsprachige, benutzernahe Texte verwenden.
> Details stehen in [docs/Language-Policy.md](docs/Language-Policy.md); eine spätere Umstellung auf Englisch ist dort skizziert.

```bash
git clone <DEIN-REPO>.git wgx
cd wgx

# (optional) im Devcontainer öffnen
# VS Code → „Reopen in Container“

# wgx in den PATH verlinken
mkdir -p "$HOME/.local/bin"
ln -sf "$PWD/cli/wgx" "$HOME/.local/bin/wgx"
export PATH="$HOME/.local/bin:$PATH"

# Smoke-Test
wgx --help
wgx doctor

# Erstlauf
wgx init
wgx clean
wgx send "feat: initial test run"
```

### `wgx clean`

`wgx clean` räumt temporäre Dateien im Workspace auf. Standardmäßig werden nur sichere Caches entfernt (`--safe`). Weitere Modi lassen sich kombinieren:

- `--build` löscht Build-Artefakte wie `dist/`, `build/`, `.venv/`, `.uv/` usw.
- `--git` räumt gemergte Branches sowie Remote-Referenzen auf. Funktioniert nur in einem sauberen Git-Arbeitsverzeichnis.
- `--deep` führt ein destruktives `git clean -xfd` aus und benötigt zusätzlich `--force`. Ein sauberer Git-Tree ist Pflicht.
- `--dry-run` zeigt alle Schritte nur an – ideal, um vor destruktiven Varianten zu prüfen, was passieren würde.

💡 Tipp: `wgx clean --dry-run --git` hilft beim schnellen Check, welche Git-Aufräumarbeiten anstehen. Sobald der Tree sauber ist, kann `wgx clean --git` (oder `--deep --force`) sicher laufen.

Falls ein Befehl unbekannt ist, kannst du die verfügbaren Subcommands auflisten:

```bash
wgx --list 2>/dev/null || wgx commands 2>/dev/null || ls -1 cmd/
```

## WGX Readiness

Der Workflow [`wgx-guard`](.github/workflows/wgx-guard.yml) generiert pro Lauf
eine Readiness-Matrix und veröffentlicht sie als Artefakte (`readiness.json`,
`readiness-table.md`, `readiness-badge.svg`). Die Dateien werden nicht
versioniert, um Git-Lärm zu vermeiden. Du findest sie im neuesten erfolgreichen
CI-Lauf oder lokal nach `./scripts/gen-readiness.sh`; Details stehen in
[docs/readiness.md](docs/readiness.md). Ergänzend erklärt
[docs/audit-ledger.md](docs/audit-ledger.md) die Audit-Logs und Beispiele.

## Entwicklungs-Schnellstart

- In VS Code öffnen → „Reopen in Container“
- CI lokal ausführen (gespiegelt durch GitHub Actions, via `tests/shell_ci.bats` abgesichert):

  ```bash
  bash -n $(git ls-files '*.sh' '*.bash')
  shfmt -d $(git ls-files '*.sh' '*.bash')
  shellcheck -S style $(git ls-files '*.sh' '*.bash')
  bats -r tests
  ```
- Node.js tooling ist nicht erforderlich; npm-/pnpm-Workflows sind deaktiviert, und es existiert kein `package.json` mehr.

- Mehr Hinweise im [Quickstart](docs/quickstart.md).

## Python-Stack (uv als Standard)

- wgx nutzt [uv](https://docs.astral.sh/uv/) als Default-Laufzeit für Python-Versionen, Lockfiles und Tools.
- Die wichtigsten Wrapper-Kommandos:

  ```bash
  wgx py up         # gewünschte Python-Version via uv bereitstellen
  wgx py sync       # Abhängigkeiten anhand von uv.lock installieren
  wgx py run test   # uv run <task>, z. B. Tests
  wgx tool add ruff # CLI-Tools wie pipx, nur über uv
  ```

- Projekte deklarieren das Verhalten in `.wgx/profile.yml`:

  ```yaml
  python:
    manager: uv
    version: "3.12"
    lock: true
    tools:
      - ruff
      - pyright
  contracts:
    uv_lock_present: true
    uv_sync_frozen: true
  ```

- Die `contracts`-Einträge lassen sich via `wgx guard` automatisiert überprüfen.
- Übergang aus bestehenden `requirements.txt`: `uv pip sync requirements.txt`, anschließend `uv lock`.
- Optional für Fremdsysteme: `uv pip compile --output-file requirements.txt` erzeugt kompatible Artefakte.
- Wer eine alternative Toolchain benötigt, kann in `profile.yml` auf `manager: pip` zurückfallen.
- `python.version` akzeptiert exakte Versionen (`3.12`) oder Bereiche (`3.12.*`).

- CI-Empfehlung (GitHub Actions, gekürzt):

  ```yaml
  - name: Install uv
    run: |
      curl -LsSf https://astral.sh/uv/install.sh | sh
      echo "UV_VERSION=$($HOME/.local/bin/uv --version | awk '{print $2}')" >> "$GITHUB_ENV"
  - name: Cache uv
    uses: actions/cache@v4
    with:
      path: ~/.cache/uv
      key: uv-${{ runner.os }}-${{ env.UV_VERSION || 'latest' }}-${{ hashFiles('**/pyproject.toml', '**/uv.lock') }}
  - name: Sync deps (frozen)
    run: ~/.local/bin/uv sync --frozen
  - name: Test
    run: ~/.local/bin/uv run pytest -q
  ```

- WGX-Contracts (durchsetzbar via `wgx guard`):
  - `contract:uv_lock_present` → `uv.lock` ist committed
  - `contract:uv_sync_frozen` → Pipelines nutzen `uv sync --frozen`

- Beispiele für `wgx py run`:

  ```bash
  wgx py run "python -m http.server"
  wgx py run pytest -q
  ```

- Devcontainer-Hinweis: kombiniere die Installation mit dem Sync, z. B. `"postCreateCommand": "bash -lc '.devcontainer/setup.sh ensure-uv && ~/.local/bin/uv sync'"`.
- Für regulierte Umgebungen kann die Installation statt `curl | sh` über gepinnte Paketquellen erfolgen.
- Weitere Hintergründe stehen in [docs/ADR-0002__python-env-manager-uv.de.md](docs/ADR-0002__python-env-manager-uv.de.md) und im [Runbook](docs/Runbook.de.md#leitfaden-von-requirementstxt-zu-uv).

## Kommandos

### reload

Destruktiv: setzt den Workspace hart auf `origin/$WGX_BASE` zurück (`git reset --hard` + `git clean -fdx`).

- Bricht ab, wenn das Arbeitsverzeichnis nicht sauber ist (außer mit `--force`).
- Mit `--dry-run` werden nur die Schritte angezeigt, ohne etwas zu verändern.
- Optional sichert `--snapshot` vorher in einen Git-Stash.

**Alias**: `sync-remote`.

### sync

Holt Änderungen vom Remote (`git pull --rebase --autostash --ff-only`). Scheitert das, wird automatisch auf `origin/$WGX_BASE` rebased.

- Schützt vor unbeabsichtigtem Lauf auf einem „dirty“ Working Tree (Abbruch ohne `--force`).
- `--dry-run` zeigt nur die geplanten Git-Kommandos.
- Über `--base <branch>` lässt sich der Fallback-Branch für den Rebase explizit setzen.
- Gibt es zusätzlich ein Positionsargument, hat `--base` Vorrang und weist mit einer Warnung darauf hin.

## Repository-Layout

```text
.
├─ cli/                 # Einstieg: ./cli/wgx (Dispatcher)
├─ cmd/                 # EIN Subcommand = EINE Datei
├─ lib/                 # Wiederverwendbare Bash-Bibliotheken
├─ modules/             # Optionale Erweiterungen
├─ etc/                 # Default-Konfigurationen
├─ templates/           # Vorlagen (PR-Text, Hooks, ...)
├─ tests/               # Automatisierte Shell-Tests
├─ installers/          # Installations-Skripte
└─ docs/                # Handbücher, ADRs
```

Der eigentliche Dispatcher liegt unter `cli/wgx`.
Alle Subcommands werden über die Dateien im Ordner `cmd/` geladen und greifen dabei auf die Bibliotheken in `lib/` zurück.
Wiederkehrende Helfer (Logging, Git-Hilfen, Environment-Erkennung usw.) sind im Kernmodul `lib/core.bash` gebündelt.

## Dokumentation & Referenzen

- **Runbook (DE/EN):** [docs/Runbook.de.md](docs/Runbook.de.md) mit [englischer Kurzfassung](docs/Runbook.en.md) für internationales Onboarding.
- **Glossar (DE/EN):** [docs/Glossar.de.md](docs/Glossar.de.md) sowie [docs/Glossary.en.md](docs/Glossary.en.md) erklären Schlüsselbegriffe.
- **Befehlsreferenz:** [docs/Command-Reference.de.md](docs/Command-Reference.de.md) listet alle `wgx`-Subcommands samt Optionen.
- **Module & Vorlagen:** [docs/Module-Uebersicht.de.md](docs/Module-Uebersicht.de.md) beschreibt Aufbau und Zweck von `modules/`, `lib/`, `etc/` und `templates/`.

## Vision & Manifest

Für die vollständige, integrierte Produktvision („Repo-Betriebssystem“) lies
**[docs/wgx-mycelium-v-omega.de.md](docs/wgx-mycelium-v-omega.de.md)**.
Sie bündelt Bedienkanon, Fleet, Memory, Policies, Offline, Registry und Roadmap.
WGX macht Abläufe reproduzierbar, erklärt Policies und liefert Evidence-Packs für PRs – im Einzelrepo und in der Fleet.

## Konfiguration

Standardwerte liegen unter `etc/config.example`.
Beim ersten Lauf von `wgx init` werden die Werte nach `~/.config/wgx/config` kopiert.
Anschließend kannst du sie dort projektspezifisch anpassen.

## .wgx/profile (v1 / v1.1)

- **Datei**: `.wgx/profile.yml` (oder `.yaml` / `.json`)
- **Fallback**: Falls keine `.wgx/profile.yml` eingecheckt ist, nutzt CI die versionierte `.wgx/profile.example.yml` als Vorlage – sie muss daher im Repository bleiben.
- **Hinweis**: Lokale Profile im Arbeitsbaum sind per `.gitignore` ausgeschlossen. Hinterlegt daher ein Beispielprofil (z.B. `profile.example.yml`) im Repo, wenn die Guard-Jobs ein manifestiertes Profil erwarten.
- **Details**: Kapitel [6. Profile v1 / v1.1](docs/wgx-mycelium-v-omega.de.md#6-profile-v1--v11-minimal--reich) im Mycelium-Manifest erläutert Struktur, Defaults und Erweiterungen.
- **apiVersion**:
  - `v1`: einfache Strings für `tasks.<name>`
  - `v1.1`: reichere Spezifikation (Arrays, desc/group/safe, envDefaults/Overrides, requiredWgx-Objekt)

### Minimales Beispiel (v1)

```yaml
wgx:
  apiVersion: v1
  requiredWgx: "^2.0"
  repoKind: "generic"
  tasks:
    test: "cargo test --workspace"
```

### Erweitertes Beispiel (v1.1)

```yaml
wgx:
  apiVersion: v1.1
  requiredWgx:
    range: "^2.0"
    min: "2.0.3"
    caps: ["task-array","status-dirs"]
  repoKind: "hauski"
  dirs: { web: "", api: "crates", data: ".local/state/hauski" }
  env:
    RUST_LOG: "info,hauski=debug"
  envDefaults:
    RUST_BACKTRACE: "1"
  envOverrides: {}
  tasks:
    doctor: { desc: "Sanity-Checks", safe: true, cmd: ["cargo","run","-p","hauski-cli","--","doctor"] }
    test:   { desc: "Workspace-Tests", safe: true, cmd: ["cargo","test","--workspace","--","--nocapture"] }
    serve:  { desc: "Entwicklungsserver", cmd: ["cargo","run","-p","hauski-cli","--","serve"] }
```

## Tests

Automatisierte Tests werden über `tests/` organisiert (z. B. mit [Bats](https://bats-core.readthedocs.io/)).
Ergänzende Checks kannst du via `wgx selftest` starten.
Die Quoting-Grundregeln sind in der [Leitlinie: Shell-Quoting](docs/Leitlinie.Quoting.de.md)
gebündelt.

## Architekturhinweis — nur modulare Struktur

Seit 2025-09-25 ist die modulare Struktur verbindlich (`cli/`, `cmd/`, `lib/`, `etc/`, `modules/`).
Der alte Monolith wurde archiviert: `docs/archive/wgx_monolith_*.md`.
```

### 📄 uv.lock

**Größe:** 96 B | **md5:** `274f9223e08a5aa733e4b7d865f2face`

```plaintext
# Placeholder uv lockfile.
# Generate with `uv sync --frozen` once pyproject.toml is available.
```

### 📄 wgx

**Größe:** 277 B | **md5:** `894519f136d7f76ea167bffe40a8030e`

```plaintext
#!/usr/bin/env bash
set -e
set -u
if ! set -o pipefail 2>/dev/null; then
  if [[ ${WGX_DEBUG:-0} != 0 ]]; then
    echo "wgx wrapper: 'pipefail' wird nicht unterstützt; fahre ohne fort." >&2
  fi
fi
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$DIR/cli/wgx" "$@"
```
```

### 📄 merges/wgx_merge_2510262237__scripts.md

**Größe:** 9 KB | **md5:** `ddc9e5cceed59aad4dd4162686474c87`

```markdown
### 📄 scripts/gen-cli-docs.sh

**Größe:** 2 KB | **md5:** `fb209069c2bcc717a00db54561f9e91c`

```bash
#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C
export LANG=C

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
cd "$repo_root"

out_file="docs/cli.md"

mkdir -p "$(dirname "$out_file")"

tmp_file="$(mktemp)"
trap 'rm -f "$tmp_file"' EXIT

if ! top_help=$(./wgx --help 2>&1); then
  echo "Failed to capture top-level help output" >&2
  exit 1
fi

mapfile -t commands < <(./wgx --list | grep -v '^[[:space:]]*$' | sort -u)

{
  echo "# wgx CLI Reference"
  echo
  echo "> Generated by \`scripts/gen-cli-docs.sh\`. Do not edit manually."
  echo
  echo "## Global usage"
  echo
  echo '```'
  printf '%s\n' "$top_help"
  echo '```'
  echo
  echo "## Commands"
  echo
} >"$tmp_file"

for cmd in "${commands[@]}"; do
  echo "### ${cmd}" >>"$tmp_file"
  echo >>"$tmp_file"

  cmd_help=""
  exit_code=0
  # Try common help flags and the `help <cmd>` fallback
  if ! cmd_help=$(./wgx "$cmd" --help 2>&1); then
    exit_code=$?
    if ! cmd_help=$(./wgx "$cmd" -h 2>&1); then
      exit_code=$?
      if ! cmd_help=$(./wgx help "$cmd" 2>&1); then
        exit_code=$?
      else
        exit_code=0
      fi
    else
      exit_code=0
    fi
  fi

  has_structured_help=0
  saw_general_help=0
  if [[ $exit_code -eq 0 ]]; then
    if printf '%s\n' "$cmd_help" | grep -qi '^usage'; then
      if [[ "$cmd" == "help" ]] || [[ "$cmd_help" != "$top_help" ]]; then
        has_structured_help=1
      else
        saw_general_help=1
        cmd_help=""
      fi
    fi
  fi

  if (( has_structured_help )); then
    echo '```' >>"$tmp_file"
    printf '%s\n' "$cmd_help" >>"$tmp_file"
    echo '```' >>"$tmp_file"
  else
    if (( saw_general_help )); then
      echo "_Command does not provide structured --help output._" >>"$tmp_file"
    elif [[ -z "$cmd_help" && $exit_code -eq 0 ]]; then
      echo "_No dedicated --help output available._" >>"$tmp_file"
    elif [[ $exit_code -eq 0 ]]; then
      echo "_Command does not provide structured --help output._" >>"$tmp_file"
    else
      echo "_Failed to capture --help output (exit ${exit_code})._" >>"$tmp_file"
      if [[ -n "$cmd_help" ]]; then
        echo >>"$tmp_file"
        echo '```' >>"$tmp_file"
        printf '%s\n' "$cmd_help" >>"$tmp_file"
        echo '```' >>"$tmp_file"
      fi
    fi
  fi

  echo >>"$tmp_file"
done

mv "$tmp_file" "$out_file"
```

### 📄 scripts/gen-readiness.sh

**Größe:** 4 KB | **md5:** `c936182b101c965f4a6e2a00140de0d6`

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_DIR"

if ! command -v python3 >/dev/null 2>&1; then
  echo "::notice::python3 not found - skipping readiness generation"
  exit 0
fi

ARTIFACT_DIR="$REPO_DIR/artifacts"
mkdir -p "$ARTIFACT_DIR"

read -r summary_count average < <(python3 - "$REPO_DIR" "$ARTIFACT_DIR" <<'PY'
import json
import time
import sys
from pathlib import Path

repo = Path(sys.argv[1])
artifact_dir = Path(sys.argv[2])
modules_dir = repo / "modules"
cmd_dir = repo / "cmd"
docs_dir = repo / "docs"
tests_dir = repo / "tests"

names = set()
if modules_dir.is_dir():
    names.update(path.stem for path in modules_dir.glob("*.bash"))
if cmd_dir.is_dir():
    names.update(path.stem for path in cmd_dir.glob("*.bash"))

modules = sorted(names)

def iter_files(root: Path):
    if not root.exists():
        return
    for path in root.rglob("*"):
        if path.is_file():
            yield path

def count_matches(root: Path, token: str, *, docs=False):
    token_lower = token.lower()
    total = 0
    for path in iter_files(root):
        stem = path.stem.lower()
        name = path.name.lower()
        if docs and path.suffix.lower() not in {".md", ".rst", ".txt"}:
            continue
        if token_lower in stem or token_lower in name:
            total += 1
    return total

rows = []
summary_score = 0
for name in modules:
    tests = count_matches(tests_dir, name)
    docs = count_matches(docs_dir, name, docs=True)
    cli = (cmd_dir / f"{name}.bash").is_file()
    score = (1 if tests > 0 else 0) + (1 if cli else 0) + (1 if docs > 0 else 0)
    if score == 3:
        status = "ready"
    elif score == 2:
        status = "progress"
    elif score == 1:
        status = "partial"
    else:
        status = "seed"
    coverage = int(round(score * 100 / 3))
    summary_score += score
    rows.append({
        "module": name,
        "status": status,
        "tests": tests,
        "cli": cli,
        "docs": docs,
        "coverage": coverage,
    })

summary_count = len(rows)
average = int(round((summary_score * 100 / (summary_count * 3)) if summary_count else 0))

data = {
    "generated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    "modules": rows,
    "summary": {"count": summary_count, "average_completion": average},
}

(artifact_dir / "readiness.json").write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")

lines = [
    "| Module | Status | Tests | CLI | Docs | Coverage |",
    "| --- | --- | --- | --- | --- | --- |",
]
if rows:
    for row in rows:
        lines.append(f"| {row['module']} | {row['status']} | {row['tests']} | {'✅' if row['cli'] else '—'} | {row['docs']} | {row['coverage']}% |")
else:
    lines.append("| _none_ | — | 0 | — | 0 | 0% |")
(artifact_dir / "readiness-table.md").write_text("\n".join(lines) + "\n", encoding="utf-8")

color = "#4c1"
if average < 40:
    color = "#e05d44"
elif average < 70:
    color = "#dfb317"

badge = f"""<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"190\" height=\"20\" role=\"img\" aria-label=\"WGX Readiness: {average}%\">
  <linearGradient id=\"smooth\" x2=\"0\" y2=\"100%\">
    <stop offset=\"0\" stop-color=\"#bbb\" stop-opacity=\".1\"/>
    <stop offset=\"1\" stop-opacity=\".1\"/>
  </linearGradient>
  <mask id=\"round\">
    <rect width=\"190\" height=\"20\" rx=\"3\" fill=\"#fff\"/>
  </mask>
  <g mask=\"url(#round)\">
    <rect width=\"120\" height=\"20\" fill=\"#555\"/>
    <rect x=\"120\" width=\"70\" height=\"20\" fill=\"{color}\"/>
    <rect width=\"190\" height=\"20\" fill=\"url(#smooth)\"/>
  </g>
  <g aria-hidden=\"true\" fill=\"#fff\" text-anchor=\"middle\" font-family=\"Verdana,DejaVu Sans,sans-serif\" text-rendering=\"geometricPrecision\" font-size=\"110\">
    <text x=\"600\" y=\"140\" transform=\"scale(.1)\" fill=\"#fff\">WGX Readiness</text>
    <text x=\"1530\" y=\"140\" transform=\"scale(.1)\" fill=\"#fff\">{average}%</text>
  </g>
</svg>
"""
(artifact_dir / "readiness-badge.svg").write_text(badge, encoding="utf-8")

print(summary_count, average)
PY
)

if [[ -s "$ARTIFACT_DIR/readiness.json" ]]; then
  echo "Readiness matrix generated at artifacts/readiness.json (modules: $summary_count, avg: ${average}%)."
else
  echo "[readiness] ::warning:: Failed to produce readiness.json" >&2
fi
```

### 📄 scripts/wgx-metrics-snapshot.sh

**Größe:** 2 KB | **md5:** `cb3c1acab6ee0433d149f619a8e6dcbb`

```bash
#!/usr/bin/env bash

set -e
set -u

if ! set -o pipefail 2>/dev/null; then
  if [[ ${WGX_DEBUG:-0} != 0 ]]; then
    echo "wgx-metrics-snapshot: 'pipefail' wird nicht unterstützt; fahre ohne fort." >&2
  fi
fi

print_json=0
output_path=${WGX_METRICS_OUTPUT:-metrics.json}

usage() {
  cat <<'EOF'
wgx-metrics-snapshot.sh [--json] [--output PATH]

Erzeugt eine metrics.json gemäß contracts-v1 (ts, host, updates, backup, drift).

  --json           JSON zusätzlich zur Datei auf STDOUT ausgeben
  --output PATH    Ziel-Datei (Standard: metrics.json oder WGX_METRICS_OUTPUT)
EOF
}

while ((${#})); do
  case "$1" in
  --json)
    print_json=1
    ;;
  --output)
    if (($# < 2)); then
      echo "--output erwartet einen Pfad" >&2
      usage >&2
      exit 1
    fi
    output_path=$2
    shift
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    echo "Unbekannte Option: $1" >&2
    usage >&2
    exit 1
    ;;
  esac
  shift
done

if [[ -z ${output_path} ]]; then
  echo "Der Ausgabe-Pfad darf nicht leer sein" >&2
  exit 1
fi

output_dir=$(dirname "$output_path")
if [[ ! -d $output_dir ]]; then
  if ! mkdir -p "$output_dir"; then
    echo "Konnte Ausgabe-Verzeichnis '$output_dir' nicht anlegen" >&2
    exit 1
  fi
fi

ts=$(date +%s)
host=$(hostname)

# Updates (Platzhalter – OS-spezifisch später ersetzen)
updates_os=${UPDATES_OS:-0}
updates_pkg=${UPDATES_PKG:-0}
updates_flatpak=${UPDATES_FLATPAK:-0}

# Backup-Status (Platzhalter)
if date -d "yesterday" +%F >/dev/null 2>&1; then
  last_ok=$(date -d "yesterday" +%F)
else
  last_ok=$(date -v-1d +%F) # BSD/macOS
fi
age_days=${BACKUP_AGE_DAYS:-1}

# Template-Drift (Platzhalter)
drift_templates=${DRIFT_TEMPLATES:-0}

json=$(jq -n \
  --arg host "$host" \
  --arg last_ok "$last_ok" \
  --argjson ts "$ts" \
  --argjson uos "$updates_os" \
  --argjson upkg "$updates_pkg" \
  --argjson ufp "$updates_flatpak" \
  --argjson age "$age_days" \
  --argjson drift "$drift_templates" \
  '{
    ts: $ts,
    host: $host,
    updates: { os: $uos, pkg: $upkg, flatpak: $ufp },
    backup: { last_ok: $last_ok, age_days: $age },
    drift: { templates: $drift }
  }')

printf '%s\n' "$json" >"$output_path"

if ((print_json != 0)); then
  printf '%s\n' "$json"
fi
```
```

### 📄 merges/wgx_merge_2510262237__templates.md

**Größe:** 710 B | **md5:** `c9213e0102c1caca78ed0e991b79da2b`

```markdown
### 📄 templates/.gitkeep

**Größe:** 0 B | **md5:** `d41d8cd98f00b204e9800998ecf8427e`

```plaintext

```

### 📄 templates/profile.template.yml

**Größe:** 478 B | **md5:** `e5d7b07eed979a5957c2c6880ebf6634`

```yaml
wgx:
  apiVersion: v1.1
  requiredWgx:
    range: "^2.0"
    min: "2.0.0"
    caps: ["task-array","status-dirs"]
  repoKind: "generic"
  envDefaults:
    RUST_BACKTRACE: "1"
  tasks:
    doctor: { desc: "Sanity-Checks", safe: true, cmd: ["wgx","doctor"] }
    test:   { desc: "Run Bats",        safe: true, cmd: ["bats","-r","tests"] }
python:
  manager: uv
  version: "3.12"
  lock: true
  tools: [ "ruff", "pyright" ]
contracts:
  uv_lock_present: true
  uv_sync_frozen: true
```
```

### 📄 merges/wgx_merge_2510262237__templates_.wgx.md

**Größe:** 281 B | **md5:** `07e086a8bcf9c1368b8ee60519dc8369`

```markdown
### 📄 templates/.wgx/profile.local.example.yml

**Größe:** 151 B | **md5:** `48d1d58e527725a261902c0ef0342773`

```yaml
# Copy to .wgx/profile.local.yml and tweak for your machine
wgx:
  envOverrides:
    RUST_LOG: "info,wgx=debug"
  dirs:
    data: "~/.local/state/wgx"
```
```

### 📄 merges/wgx_merge_2510262237__templates_docs.md

**Größe:** 783 B | **md5:** `806fcf58af5f3ba9f7a8a4877afeb80d`

```markdown
### 📄 templates/docs/README.additions.md

**Größe:** 655 B | **md5:** `2fccc715b601d965fe993b35201c9772`

```markdown
# Für Dummies – Was macht dieses Repo?
Dieses Projekt nutzt **WGX** als schlanken Helfer: ein paar Standard-Kommandos (up | list | run | doctor | validate | smoke)
machen Arbeiten im Terminal einfacher. Du musst nicht „programmieren“ können – du führst nur Kommandos aus.

**Wichtigste Idee:** Ein `/.wgx/profile.yml` beschreibt, welche Tools/Checks für dieses Repo gelten.
WGX liest das ein und führt passende Aufgaben aus (z. B. Format, Lint, Tests).

## WGX-Kurzstart
```bash
wgx --help
wgx doctor     # prüft Umgebung
wgx clean      # räumt Temp-/Build-Artefakte auf
wgx send "feat: initial test run"  # Beispiel-Commit/Push-Helfer
```
```
```

### 📄 merges/wgx_merge_2510262237__tests.md

**Größe:** 30 KB | **md5:** `dc682d25fc1e0fb01e8b6c05c1d3d9dc`

```markdown
### 📄 tests/.gitkeep

**Größe:** 0 B | **md5:** `d41d8cd98f00b204e9800998ecf8427e`

```plaintext

```

### 📄 tests/assertions.bats

**Größe:** 4 KB | **md5:** `66917295732241896c35a5123f2ff8d8`

```plaintext
#!/usr/bin/env bats

load test_helper
load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

# ------------------------------------------------------------
#  Test: assert_equal and assert_not_equal
# ------------------------------------------------------------

@test "assert_equal succeeds for identical strings" {
  run bash -lc 'source tests/test_helper/bats-assert/load; assert_equal "foo" "foo"'
  assert_success
}

@test "assert_equal fails and shows diff for different multiline values" {
  run bash -lc 'source tests/test_helper/bats-assert/load; assert_equal $'"'"'line1\nline2\n'"'"' $'"'"'line1\nlineX\n'"'"''
  assert_failure
  # Diff output should contain 'lineX'
  [[ "$output" == *"lineX"* ]]
  [[ "$output" == *"expected"* ]]
}

@test "assert_not_equal succeeds for different strings" {
  run bash -lc 'source tests/test_helper/bats-assert/load; assert_not_equal "foo" "bar"'
  assert_success
}

@test "assert_not_equal fails for equal strings" {
  run bash -lc 'source tests/test_helper/bats-assert/load; assert_not_equal "foo" "foo"'
  assert_failure
  [[ "$output" == *"Expected values to differ"* ]]
}

# ------------------------------------------------------------
#  Test: assert_json_equal and assert_json_not_equal
# ------------------------------------------------------------

@test "assert_json_equal ignores key order" {
  local a='{"b":1,"a":2}'
  local b='{"a":2,"b":1}'
  run bash -lc 'source tests/test_helper/bats-assert/load; assert_json_equal "$1" "$2"' _ "$a" "$b"
  assert_success
}

@test "assert_json_equal fails on semantic difference" {
  local a='{"a":1}'
  local b='{"a":2}'
  run bash -lc 'source tests/test_helper/bats-assert/load; assert_json_equal "$1" "$2"' _ "$a" "$b"
  assert_failure
  [[ "$output" == *"assert_equal failed"* ]]
}

@test "assert_json_not_equal succeeds on difference" {
  local a='{"x":1}'
  local b='{"x":2}'
  run bash -lc 'source tests/test_helper/bats-assert/load; assert_json_not_equal "$1" "$2"' _ "$a" "$b"
  assert_success
}

@test "assert_json_not_equal fails on equal JSON" {
  local a='{"x":1,"y":2}'
  local b='{"y":2,"x":1}'
  run bash -lc 'source tests/test_helper/bats-assert/load; assert_json_not_equal "$1" "$2"' _ "$a" "$b"
  assert_failure
  [[ "$output" == *"Expected values to differ"* ]]
}

# ------------------------------------------------------------
#  Test: JSON normalization fallback behavior
# ------------------------------------------------------------

@test "_json_normalize works with jq or python3" {
  if ! command -v jq >/dev/null 2>&1 && ! command -v python3 >/dev/null 2>&1; then
    skip "neither jq nor python3 available"
  fi
  local j='{"z":1,"a":2}'
  run bash -lc 'source tests/test_helper/bats-assert/load; _json_normalize <<<"$1"' _ "$j"
  assert_success
  # Keys sorted lexicographically
  assert_output partial '"a":2'
  assert_output partial '"z":1'
}

# ------------------------------------------------------------
#  Test: edge/error cases
# ------------------------------------------------------------

@test "assert_json_equal reports invalid JSON" {
  local bad='{"a":1'
  run bash -lc 'source tests/test_helper/bats-assert/load; assert_json_equal "$1" "$2"' _ "$bad" '{"a":1}'
  assert_failure
  [[ "$output" == *"invalid"* ]]
}

@test "assert_json_not_equal reports invalid JSON" {
  local bad='[1,2'
  run bash -lc 'source tests/test_helper/bats-assert/load; assert_json_not_equal "$1" "$2"' _ "$bad" '[1,2,3]'
  assert_failure
  [[ "$output" == *"invalid"* ]]
}

# ------------------------------------------------------------
#  Sanity check for regression: plain success
# ------------------------------------------------------------

@test "assertions library loads cleanly" {
  run bash -lc 'source tests/test_helper/bats-assert/load; echo OK'
  assert_success
  assert_output "OK"
}

# EOF
```

### 📄 tests/clean.bats

**Größe:** 3 KB | **md5:** `f60f70700561721909733607862cab73`

```plaintext
#!/usr/bin/env bats

load test_helper

setup() {
  local test_dir repo_root
  if [ -n "${BATS_TEST_FILENAME:-}" ]; then
    test_dir="$(cd "$(dirname "${BATS_TEST_FILENAME}")" && pwd)"
  else
    test_dir="$(pwd)"
  fi
  repo_root="$(cd "$test_dir/.." && pwd)"

  export WGX_DIR="$(pwd)"
  export PATH="$repo_root/cli:$PATH"
  export WGX_CLI_ROOT="$repo_root"
}

teardown() {
  rm -rf .pytest_cache .mypy_cache dist build target .tox .nox .venv .uv .pdm-build node_modules dirty-tree.txt
}

run_clean_in_dir() {
  local target="$1"
  shift
  local runner
  runner="$(mktemp)"
  cat <<'SCRIPT' >"$runner"
#!/usr/bin/env bash
set -e
set -u
if ! set -o pipefail 2>/dev/null; then
  if [[ ${WGX_DEBUG:-0} != 0 ]]; then
    echo "clean-runner: 'pipefail' wird nicht unterstützt; fahre ohne fort." >&2
  fi
fi
CLI_ROOT="$1"
TARGET="$2"
shift 2
export WGX_DIR="$TARGET"
source "$CLI_ROOT/lib/core.bash"
source "$CLI_ROOT/cmd/clean.bash"
cd "$TARGET"
cmd_clean "$@"
exit $?
SCRIPT
  chmod +x "$runner"
  run "$runner" "$WGX_CLI_ROOT" "$target" "$@"
  rm -f "$runner"
}

init_git_repo() {
  local repo
  repo="$(mktemp -d)"
  git -C "$repo" init >/dev/null 2>&1
  (cd "$repo" && git config user.email "wgx@example.test" && git config user.name "WGX Test")
  printf '%s' 'tracked' >"$repo/tracked.txt"
  git -C "$repo" add tracked.txt >/dev/null 2>&1
  git -C "$repo" commit -m 'init' >/dev/null 2>&1
  echo "$repo"
}

@test "clean removes cache directories by default" {
  mkdir -p .pytest_cache/foo
  mkdir -p dist/keep
  run wgx clean
  assert_success
  [ ! -d .pytest_cache ]
  [ -d dist ]
}

@test "clean --dry-run keeps files intact" {
  mkdir -p .mypy_cache/foo
  run wgx clean --dry-run
  assert_success
  [ -d .mypy_cache ]
}

@test "clean --build removes build artefacts" {
  mkdir -p dist/foo build/bar
  run wgx clean --build
  assert_success
  [ ! -d dist ]
  [ ! -d build ]
}

@test "clean --git --dry-run succeeds" {
  run wgx clean --git --dry-run
  assert_success
  [[ "$output" =~ "Clean (Dry-Run) abgeschlossen." ]]
}

@test "clean --git aborts on dirty worktree" {
  local repo
  repo="$(init_git_repo)"
  echo 'dirty' >>"$repo"/tracked.txt
  run_clean_in_dir "$repo" --git
  assert_failure
  [[ "$output" =~ "Arbeitsverzeichnis ist nicht sauber" ]]
  rm -rf "$repo"
}

@test "clean --deep without --force warns" {
  run wgx clean --deep
  [ "$status" -ne 0 ]
  [[ "$output" =~ "--deep ist destruktiv" ]]
}

@test "clean --deep --force removes untracked files in repo" {
  local repo
  repo="$(init_git_repo)"
  touch "$repo"/scratch.txt
  run_clean_in_dir "$repo" --deep --force
  assert_success
  [ ! -f "$repo"/scratch.txt ]
  rm -rf "$repo"
}

@test "clean --deep --force aborts on dirty repo" {
  local repo
  repo="$(init_git_repo)"
  echo 'dirty' >>"$repo"/tracked.txt
  run_clean_in_dir "$repo" --deep --force
  assert_failure
  [[ "$output" =~ "Arbeitsverzeichnis ist nicht sauber" ]]
  rm -rf "$repo"
}
```

### 📄 tests/cli_permissions.bats

**Größe:** 248 B | **md5:** `0a753f99184ce8d39e2d2254c42523bc`

```plaintext
#!/usr/bin/env bats

load test_helper

setup() {
  export WGX_DIR="$(pwd)"
  export PATH="$WGX_DIR/cli:$PATH"
}

@test "CLI entrypoint has executable bit set" {
  run git ls-files -s cli/wgx
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == 100755* ]]
}
```

### 📄 tests/env.bats

**Größe:** 988 B | **md5:** `97e89f59da256da9cdb4e93880d095ea`

```plaintext
#!/usr/bin/env bats

load test_helper

setup() {
  export WGX_DIR="$(pwd)"
  export PATH="$WGX_DIR/cli:$PATH"
}

@test "env doctor reports tool availability" {
  run wgx env doctor
  assert_success
  assert_output --partial "wgx env doctor"
  assert_output --partial "git"
}

@test "env doctor --json emits minimal JSON" {
  run wgx env doctor --json
  assert_success
  assert_output --partial '"tools"'
  assert_output --partial '"platform"'
}

@test "env doctor --fix is a no-op outside Termux" {
  unset TERMUX_VERSION
  run wgx env doctor --fix
  assert_success
  assert_output --partial "--fix is currently only supported on Termux"
}

@test "env doctor --strict fails when git is missing" {
  local tmpbin
  tmpbin="$(mktemp -d)"
  for cmd in bash dirname readlink uname head tr; do
    ln -s "$(command -v "$cmd")" "$tmpbin/$cmd"
  done
  run env PATH="$tmpbin" "$WGX_DIR/cli/wgx" env doctor --strict
  local strict_status=$status
  rm -rf "$tmpbin"
  [ "$strict_status" -ne 0 ]
}
```

### 📄 tests/example_wgx.bats

**Größe:** 352 B | **md5:** `1575579e9f9d763df66961ab47fb3d17`

```plaintext
#!/usr/bin/env bats

load test_helper

setup() {
  export PATH="$PWD/cli:$PATH"
}

@test "wgx shows help with -h" {
  run wgx -h
  assert_success
  assert_output --partial "wgx"
  assert_output --partial "help"
}

@test "wgx shows help with --help" {
  run wgx --help
  assert_success
  assert_output --partial "wgx"
  assert_output --partial "help"
}
```

### 📄 tests/guard.bats

**Größe:** 448 B | **md5:** `3a861a1080476d6a78282bbb6f23a66b`

```plaintext
#!/usr/bin/env bats

load test_helper

setup() {
  export WGX_DIR="$(pwd)"
  export PATH="$WGX_DIR/cli:$PATH"
}

teardown() {
  local bigfile="tmp_guard_bigfile"
  git reset --quiet HEAD "$bigfile" >/dev/null 2>&1 || true
  rm -f "$bigfile"
}

@test "guard fails on files >=1MB" {
  local bigfile="tmp_guard_bigfile"
  truncate -s 1M "$bigfile"
  git add "$bigfile"

  run wgx guard
  assert_failure
  assert_output --partial "Zu große Dateien"
}
```

### 📄 tests/help.bats

**Größe:** 421 B | **md5:** `6f36408619dc58a6d902ae2ddb1fd53d`

```plaintext
#!/usr/bin/env bats

load test_helper

setup() {
  export WGX_DIR="$(pwd)"
  export PATH="$WGX_DIR/cli:$PATH"
}

@test "--list shows available commands" {
  run wgx --list
  [ "$status" -eq 0 ]
  [[ "${lines[*]}" =~ reload ]]
  [[ "${lines[*]}" =~ doctor ]]
}

@test "help output includes dynamic command list" {
  run wgx --help
  [ "$status" -eq 0 ]
  [[ "${output}" =~ "Commands:" ]]
  [[ "${output}" =~ "reload" ]]
}
```

### 📄 tests/metrics_snapshot.bats

**Größe:** 2 KB | **md5:** `a27a3f9ae3c640661f37936f29e42e05`

```plaintext
#!/usr/bin/env bats

load test_helper

setup() {
  export WGX_DIR="$(pwd)"
  export PATH="$WGX_DIR/cli:$PATH"
  TMPDIR="$(mktemp -d)"
  # Werkzeug-Check: jq wird von den Tests benötigt
  if ! command -v jq >/dev/null 2>&1; then
    skip "jq nicht gefunden – Tests werden übersprungen"
  fi
}

teardown() {
  rm -rf "$TMPDIR"
  # Aufräumen, falls im Repo-Root geschrieben wurde
  rm -f metrics.json
  rm -rf snapshots
}

@test "metrics snapshot creates file at default path (metrics.json) with required keys" {
  run scripts/wgx-metrics-snapshot.sh
  assert_success
  [ -f metrics.json ]
  # required top-level keys present
  run jq -e 'has("ts") and has("host") and has("updates") and has("backup") and has("drift")' metrics.json
  assert_success
}

@test "metrics snapshot respects WGX_METRICS_OUTPUT env" {
  export WGX_METRICS_OUTPUT="$TMPDIR/from-env.json"
  run scripts/wgx-metrics-snapshot.sh
  assert_success
  [ -f "$WGX_METRICS_OUTPUT" ]
  run jq -e 'has("ts") and has("host")' "$WGX_METRICS_OUTPUT"
  assert_success
}

@test "metrics snapshot errors on unknown option" {
  run scripts/wgx-metrics-snapshot.sh --definitely-unknown-flag
  assert_failure
  [[ "$output" =~ "Unbekannte Option" ]]
}

@test "metrics snapshot --output writes to custom path" {
  out="$TMPDIR/custom.json"
  run scripts/wgx-metrics-snapshot.sh --output "$out"
  assert_success
  [ -f "$out" ]
  run jq -e '.backup | has("last_ok") and has("age_days")' "$out"
  assert_success
}

@test "metrics snapshot --json prints valid JSON to stdout" {
  out="$TMPDIR/std.json"
  run scripts/wgx-metrics-snapshot.sh --json --output "$out"
  assert_success
  # stdout must be JSON and match file content structure-wise
  echo "$output" > "$TMPDIR/stdout.json"
  run jq -e type "$TMPDIR/stdout.json"
  assert_success
  run jq -e 'has("ts") and has("host") and has("updates") and has("backup") and has("drift")' "$TMPDIR/stdout.json"
  assert_success
}

@test "metrics snapshot fails on empty output path" {
  run scripts/wgx-metrics-snapshot.sh --output ""
  assert_failure
  [[ "$output" =~ "Der Ausgabe-Pfad darf nicht leer sein" ]]
}

@test "metrics snapshot creates parent directory for custom path" {
  nested="$TMPDIR/snapshots/metrics.json"
  run scripts/wgx-metrics-snapshot.sh --output "$nested"
  assert_success
  [ -f "$nested" ]
}
```

### 📄 tests/profile_parse_tasks.bats

**Größe:** 2 KB | **md5:** `19ba988cea06b5c19cb8639070a691bd`

```plaintext
#!/usr/bin/env bats

load test_helper

setup() {
  REPO_ROOT="$(pwd)"
  export WGX_DIR="$REPO_ROOT"
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  # Stub python3 to force flat parser to be exercised when profile::load runs.
  cat >"$BATS_TEST_TMPDIR/bin/python3" <<'SH'
#!/usr/bin/env bash
exit 1
SH
  chmod +x "$BATS_TEST_TMPDIR/bin/python3"
  export PATH="$REPO_ROOT/cli:$BATS_TEST_TMPDIR/bin:/usr/bin:/bin"
  source "$REPO_ROOT/modules/profile.bash"
  WORKDIR="$BATS_TEST_TMPDIR/work"
  mkdir -p "$WORKDIR/.wgx"
  cd "$WORKDIR"
  profile::_reset
}

teardown() {
  profile::_reset
}

@test "flat parser loads inline and nested tasks without python" {
  cat >"$WORKDIR/.wgx/profile.yml" <<'YAML'
wgx:
  tasks:
    inline: echo inline
    nested:
      desc: Build project
      group: dev
      safe: true
      cmd: echo nested
    caution:
      cmd: echo caution
      safe: No
YAML

  profile::load "$WORKDIR/.wgx/profile.yml"
  assert_equal 0 "$?"

  assert_equal "inline nested caution" "${WGX_TASK_ORDER[*]}"

  assert_equal "STR:echo inline" "${WGX_TASK_CMDS[inline]}"
  assert_equal "" "${WGX_TASK_DESC[inline]}"
  assert_equal "" "${WGX_TASK_GROUP[inline]}"
  assert_equal "0" "${WGX_TASK_SAFE[inline]}"

  assert_equal "STR:echo nested" "${WGX_TASK_CMDS[nested]}"
  assert_equal "Build project" "${WGX_TASK_DESC[nested]}"
  assert_equal "dev" "${WGX_TASK_GROUP[nested]}"
  assert_equal "1" "${WGX_TASK_SAFE[nested]}"

  assert_equal "STR:echo caution" "${WGX_TASK_CMDS[caution]}"
  assert_equal "0" "${WGX_TASK_SAFE[caution]}"

  assert_equal "v1" "$PROFILE_VERSION"
}

@test "flat parser normalizes safe flag casing and defaults" {
  cat >"$WORKDIR/.wgx/profile.yml" <<'YAML'
wgx:
  tasks:
    safe_upper:
      safe: YES
      cmd: echo safe upper
    safe_mixed:
      safe: On
      cmd: echo safe mixed
    safe_false:
      safe: off
      cmd: echo unsafe
    metadata_only:
      desc: Example task
YAML

  profile::load "$WORKDIR/.wgx/profile.yml"
  assert_equal 0 "$?"

  assert_equal "1" "${WGX_TASK_SAFE[safe_upper]}"
  assert_equal "1" "${WGX_TASK_SAFE[safe_mixed]}"
  assert_equal "0" "${WGX_TASK_SAFE[safe_false]}"
  assert_equal "0" "${WGX_TASK_SAFE[metadata_only]}"

  assert_equal "STR:echo safe upper" "${WGX_TASK_CMDS[safe_upper]}"
  assert_equal "STR:echo safe mixed" "${WGX_TASK_CMDS[safe_mixed]}"
  assert_equal "STR:echo unsafe" "${WGX_TASK_CMDS[safe_false]}"
  assert_equal "STR:" "${WGX_TASK_CMDS[metadata_only]}"
  assert_equal "Example task" "${WGX_TASK_DESC[metadata_only]}"
}
```

### 📄 tests/profile_state.bats

**Größe:** 1014 B | **md5:** `778360019a3f19727426d1ec3fe46cc4`

```plaintext
#!/usr/bin/env bats

load test_helper

setup() {
  REPO_ROOT="$(pwd)"
}

@test "profile::ensure_loaded clears cached data when manifest disappears" {
  WORKDIR="$BATS_TEST_TMPDIR/project"
  mkdir -p "$WORKDIR/.wgx"
  cat >"$WORKDIR/.wgx/profile.yml" <<'YAML'
wgx:
  apiVersion: v1
  repoKind: webapp
YAML

  helper_script="$BATS_TEST_TMPDIR/check_profile.sh"
  cat >"$helper_script" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$1"
WORKDIR="$2"
export WGX_DIR="$REPO_ROOT"
source "$REPO_ROOT/lib/core.bash"
source "$REPO_ROOT/modules/profile.bash"
cd "$WORKDIR"
profile::load ".wgx/profile.yml"
printf 'before=%s\n' "${WGX_REPO_KIND}"
rm -f .wgx/profile.yml
if profile::ensure_loaded; then
  printf 'ensure=ok\n'
else
  printf 'ensure=fail\n'
fi
printf 'after=%s\n' "${WGX_REPO_KIND}"
SH
  chmod +x "$helper_script"

  run "$helper_script" "$REPO_ROOT" "$WORKDIR"
  assert_success
  assert_line --index 0 -- "before=webapp"
  assert_line --index 1 -- "ensure=fail"
  assert_line --index 2 -- "after="
}
```

### 📄 tests/profile_tasks.bats

**Größe:** 4 KB | **md5:** `e04784ee146d65632e6c162742c86a7d`

```plaintext
#!/usr/bin/env bats

load test_helper

setup() {
  REPO_ROOT="$(pwd)"
}

@test "profile::load falls back to root tasks when nested tasks are empty" {
  WORKDIR="$BATS_TEST_TMPDIR/fallback"
  mkdir -p "$WORKDIR/.wgx"
  cat >"$WORKDIR/.wgx/profile.yml" <<'YAML'
wgx:
  apiVersion: v1
  tasks: {}
tasks:
  Build App:
    cmd:
      - npm
      - run
      - build
    args:
      - --prod
    safe: "yes"
YAML

  helper_script="$BATS_TEST_TMPDIR/check_fallback.sh"
  cat >"$helper_script" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$1"
WORKDIR="$2"
source "$REPO_ROOT/lib/core.bash"
source "$REPO_ROOT/modules/profile.bash"
cd "$WORKDIR"
profile::load ".wgx/profile.yml"
printf 'order=%s\n' "${WGX_TASK_ORDER[*]}"
printf 'cmd=%s\n' "${WGX_TASK_CMDS[buildapp]}"
printf 'safe=%s\n' "${WGX_TASK_SAFE[buildapp]}"
SH
  chmod +x "$helper_script"

  run env WGX_PROFILE_DEPRECATION=quiet "$helper_script" "$REPO_ROOT" "$WORKDIR"
  assert_success
  assert_line --index 0 -- "order=buildapp"
  assert_line --index 1 -- "cmd=ARRJSON:[\"npm\", \"run\", \"build\", \"--prod\"]"
  assert_line --index 2 -- "safe=1"
}

@test "profile task parsing deduplicates order and tokenizes commands" {
  WORKDIR="$BATS_TEST_TMPDIR/tokenize"
  mkdir -p "$WORKDIR/.wgx"
  cat >"$WORKDIR/.wgx/profile.yml" <<'YAML'
wgx:
  apiVersion: v1
  tasks:
    BuildApp:
      cmd: echo first
    buildapp:
      cmd: echo second
    Format:
      cmd: go fmt ./...
      args:
        - ./internal/...
      safe: "no"
    Safe Task:
      cmd:
        linux:
          - /bin/echo
          - done
        default:
          - echo
          - default
      args:
        - extra
      safe: "yes"
YAML

  helper_script="$BATS_TEST_TMPDIR/check_tokenize.sh"
  cat >"$helper_script" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$1"
WORKDIR="$2"
source "$REPO_ROOT/lib/core.bash"
source "$REPO_ROOT/modules/profile.bash"
cd "$WORKDIR"
profile::load ".wgx/profile.yml"
printf 'order_count=%s\n' "${#WGX_TASK_ORDER[@]}"
printf 'order_values=%s\n' "${WGX_TASK_ORDER[*]}"
printf 'format_cmd=%s\n' "${WGX_TASK_CMDS[format]}"
printf 'format_safe=%s\n' "${WGX_TASK_SAFE[format]}"
printf 'safetask_cmd=%s\n' "${WGX_TASK_CMDS[safetask]}"
printf 'safetask_safe=%s\n' "${WGX_TASK_SAFE[safetask]}"
SH
  chmod +x "$helper_script"

  run env WGX_PROFILE_DEPRECATION=quiet "$helper_script" "$REPO_ROOT" "$WORKDIR"
  assert_success
  assert_line --index 0 -- "order_count=3"
  assert_line --index 1 -- "order_values=buildapp format safetask"
  assert_line --index 2 -- "format_cmd=STR:go fmt ./... ./internal/..."
  assert_line --index 3 -- "format_safe=0"
  assert_line --index 4 -- "safetask_cmd=ARRJSON:[\"/bin/echo\", \"done\", \"extra\"]"
  assert_line --index 5 -- "safetask_safe=1"
}

@test "profile task preserves raw strings and quotes appended args" {
  WORKDIR="$BATS_TEST_TMPDIR/raw"
  mkdir -p "$WORKDIR/.wgx"
  cat >"$WORKDIR/.wgx/profile.yml" <<'YAML'
wgx:
  apiVersion: v1
tasks:
  raw-str:
    cmd: echo 'a # b'
    args:
      - x y
  array-task:
    cmd:
      - bash
      - -lc
      - echo ok
    args:
      linux:
        - --flag
  scalar-cmd:
    cmd: 42
YAML

  helper_script="$BATS_TEST_TMPDIR/check_raw.sh"
  cat >"$helper_script" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$1"
WORKDIR="$2"
source "$REPO_ROOT/lib/core.bash"
source "$REPO_ROOT/modules/profile.bash"
cd "$WORKDIR"

<<TRUNCATED: max_file_lines=800>>
```

### 📄 merges/wgx_merge_2510262237__tests_test_helper_bats-assert.md

**Größe:** 6 KB | **md5:** `6c389dcd03ca086b6f260ee00e81e6dc`

```markdown
### 📄 tests/test_helper/bats-assert/load

**Größe:** 6 KB | **md5:** `9a162e5c3a089c82a2172ceb65fe5ea8`

```plaintext
#!/usr/bin/env bash

bats_assert_loaded=1

# ---- core helpers ----
_assert_fail() {
  local message=$1
  printf 'Assertion failed: %s\n' "$message" >&2
  return 1
}

_assert_match() {
  local mode=$1
  local haystack=$2
  local needle=$3
  case "$mode" in
    exact)
      [[ $haystack == "$needle" ]]
      ;;
    partial)
      [[ $haystack == *"$needle"* ]]
      ;;
    regexp)
      [[ $haystack =~ $needle ]]
      ;;
    *)
      return 1
      ;;
  esac
}

# ---- value equality ----
assert_equal() {
  if (($# != 2)); then
    _assert_fail "assert_equal requires exactly 2 arguments: expected, actual"
  fi

  local expected="$1"
  local actual="$2"

  if [[ "$actual" != "$expected" ]]; then
    if [[ "$expected" == *$'\n'* || "$actual" == *$'\n'* ]]; then
      local _exp _act _diff msg
      _exp="$(mktemp)"
      _act="$(mktemp)"
      trap 'rm -f "$_exp" "$_act"; trap - RETURN' RETURN
      printf '%s' "$expected" >"$_exp"
      printf '%s' "$actual"   >"$_act"
      if command -v diff >/dev/null 2>&1; then
        _diff="$(diff -u --label expected --label actual "$_exp" "$_act" 2>/dev/null || true)"
        msg=$'assert_equal failed (multiline)\n'"${_diff}"
      else
        msg=$'assert_equal failed (multiline; no diff available)\n--- expected ---\n'"$expected"$'\n--- actual ---\n'"$actual"
      fi
      _assert_fail "$msg"
      return 1
    fi
    _assert_fail "Expected '${expected}', got '${actual}'"
  fi
}

assert_not_equal() {
  if (($# != 2)); then
    _assert_fail "assert_not_equal requires exactly 2 arguments: not_expected, actual"
  fi

  local not_expected="$1"
  local actual="$2"

  if [[ "$actual" == "$not_expected" ]]; then
    _assert_fail "Expected values to differ, but both were: '${actual}'"
  fi
}

# ---- command status ----
assert_success() {
  local actual=${status-}
  if [[ ${actual:-1} -ne 0 ]]; then
    _assert_fail "Expected success (status 0) but got ${actual:-<unset>}"
  fi
}

assert_failure() {
  local expected=${1-}
  local actual=${status-}
  if [[ -z ${expected} ]]; then
    if [[ ${actual:-0} -eq 0 ]]; then
      _assert_fail "Expected failure (non-zero status) but command succeeded"
    fi
  else
    if [[ ${actual:-0} -ne $expected ]]; then
      _assert_fail "Expected exit status $expected but got ${actual:-0}"
    fi
  fi
}

assert_output() {
  local mode=exact
  while (($#)); do
    case "$1" in
      --partial)
        mode=partial
        shift
        ;;
      --regexp)
        mode=regexp
        shift
        ;;
      --)
        shift
        break
        ;;
      *)
        break
        ;;
    esac
  done

  local expected="$*"
  local actual=${output-}

  if ! _assert_match "$mode" "$actual" "$expected"; then
    _assert_fail "Expected output (${mode}) to match '$expected' but was: $actual"
  fi
}

assert_error() {
  local mode=exact
  while (($#)); do
    case "$1" in
      --partial)
        mode=partial
        shift
        ;;
      --regexp)
        mode=regexp
        shift
        ;;
      --)
        shift
        break
        ;;
      *)
        break
        ;;
    esac
  done

  local expected="$*"

  local actual=""
  if [[ -n ${stderr+x} ]]; then
    actual="$stderr"
  elif [[ -n ${error+x} ]]; then
    actual="$error"
  fi

  if ! _assert_match "$mode" "$actual" "$expected"; then
    _assert_fail "Expected error (${mode}) to match '$expected' but was: $actual"
  fi
}

assert_line() {
  local index=""
  local mode=exact
  while (($#)); do
    case "$1" in
      --index)
        if [[ -z $2 ]]; then
          _assert_fail "Missing value for --index argument"
        fi
        if ! [[ $2 =~ ^[0-9]+$ ]]; then
          _assert_fail "Invalid value for --index: '$2' (must be a non-negative integer)"
        fi
        index=$2
        shift 2
        ;;
      --partial)
        mode=partial
        shift
        ;;
      --regexp)
        mode=regexp
        shift
        ;;
      --)
        shift
        break
        ;;
      *)
        break
        ;;
    esac
  done

  if [[ -z $index ]]; then
    _assert_fail "assert_line requires --index for this helper"
  fi

  local expected="$*"

  if [[ $index -ge ${#lines[@]} ]]; then
    _assert_fail "Expected line at index $index but command produced ${#lines[@]} lines"
  fi

  local line="${lines[$index]}"
  if ! _assert_match "$mode" "$line" "$expected"; then
    _assert_fail "Expected line[$index] (${mode}) to match '$expected' but was: $line"
  fi
}

# ---- JSON helpers ----
_json_normalize() {
  # Reads JSON from stdin and prints a stable, minified, key-sorted representation.
  # Prefers jq -S .; falls back to python3. Returns non-zero if neither exists or input invalid.
  if command -v jq >/dev/null 2>&1; then
    jq -S -c .
    return $?
  fi
  if command -v python3 >/dev/null 2>&1; then
    python3 - <<'PY'
import json, sys
try:
    data = json.load(sys.stdin)
except Exception as e:
    sys.stderr.write("json-parse-error: %s\n" % (e,))
    sys.exit(1)
sys.stdout.write(json.dumps(data, sort_keys=True, separators=(",", ":")))
PY
    return $?
  fi
  printf 'json-normalize: missing jq and python3\n' >&2
  return 127
}

assert_json_equal() {
  if (($# != 2)); then
    _assert_fail "assert_json_equal requires exactly 2 arguments: expected_json, actual_json"
  fi

  local expected_raw="$1"
  local actual_raw="$2"

  local _exp _act _norm_exp _norm_act
  _exp="$(mktemp)"
  _act="$(mktemp)"
  trap 'rm -f "$_exp" "$_act"; trap - RETURN' RETURN
  printf '%s' "$expected_raw" >"$_exp"
  printf '%s' "$actual_raw"   >"$_act"

  if ! _norm_exp="$(_json_normalize <"$_exp")"; then
    _assert_fail "assert_json_equal: expected JSON is invalid or normalization failed"
    return 1
  fi
  if ! _norm_act="$(_json_normalize <"$_act")"; then
    _assert_fail "assert_json_equal: actual JSON is invalid or normalization failed"
    return 1
  fi

  assert_equal "$_norm_exp" "$_norm_act"
}

assert_json_not_equal() {
  if (($# != 2)); then
    _assert_fail "assert_json_not_equal requires exactly 2 arguments: json_a, json_b"
  fi

  local a_norm b_norm
  if ! a_norm="$(_json_normalize <<<"$1")"; then
    _assert_fail "assert_json_not_equal: json_a is invalid or normalization failed"
    return 1
  fi
  if ! b_norm="$(_json_normalize <<<"$2")"; then
    _assert_fail "assert_json_not_equal: json_b is invalid or normalization failed"
    return 1
  fi

  assert_not_equal "$a_norm" "$b_norm"
}
```
```

### 📄 merges/wgx_merge_2510262237__tests_test_helper_bats-support.md

**Größe:** 171 B | **md5:** `9c6347ee230fbd0c9bfa27d8e8d58f76`

```markdown
### 📄 tests/test_helper/bats-support/load

**Größe:** 42 B | **md5:** `1bc0d71afdadbccefd26176866f8a45f`

```plaintext
#!/usr/bin/env bash
bats_support_loaded=1
```
```


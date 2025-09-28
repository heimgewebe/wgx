#!/usr/bin/env bash

set -euo pipefail

sudo apt-get update -y
# Shell tooling
sudo apt-get install -y shellcheck shfmt bats
# QoL
sudo apt-get install -y jq moreutils

# Node-based CLIs optional local (not necessarily global)
if command -v npm >/dev/null 2>&1; then
  npm install -g markdownlint-cli2 || true
fi

echo "Dev tools ready: shellcheck $(shellcheck --version | head -1), shfmt $(shfmt -version), bats $(bats --version | head -1)"

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

shellcheck_version="not installed"
shfmt_version="not installed"
bats_version="not installed"
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck_version="$(shellcheck --version | head -1)"
fi
if command -v shfmt >/dev/null 2>&1; then
  shfmt_version="$(shfmt -version)"
fi
if command -v bats >/dev/null 2>&1; then
  bats_version="$(bats --version | head -1)"
fi
echo "Dev tools ready: shellcheck ${shellcheck_version}, shfmt ${shfmt_version}, bats ${bats_version}"

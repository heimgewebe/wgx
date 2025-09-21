#!/usr/bin/env bash
set -euxo pipefail

apt-get update
apt-get install -y git curl jq ripgrep fzf tmux

if command -v npm >/dev/null 2>&1; then
  npm install -g cspell
fi

curl -fsSL https://github.com/errata-ai/vale/releases/latest/download/vale_Linux_64-bit.tar.gz \
  | tar -xz -C /usr/local/bin

echo "✅ wgx devcontainer setup complete."
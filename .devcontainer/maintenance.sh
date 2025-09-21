#!/usr/bin/env bash
set -euxo pipefail

echo "🔧 Running maintenance..."

# Update & Sicherheit
apt-get update -qq
apt-get upgrade -y

# Clean-Up
apt-get autoremove -y
apt-get clean
rm -rf /var/lib/apt/lists/*

# Tools checken
for tool in git vale cspell jq; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "⚠️ $tool fehlt!"
  else
    echo "✅ $tool vorhanden: $($tool --version 2>/dev/null || true)"
  fi
done

echo "✨ Maintenance done."
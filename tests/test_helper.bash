#!/usr/bin/env bash

# test_helper.bash

# Gemeinsamer Test-Setup-Code für alle Bats-Tests
# Wird über `load test_helper` in den Test-Skripten geladen

# Fügt das 'cli'-Verzeichnis zum PATH hinzu, damit die 'wgx'-Befehle in den Tests
# direkt aufgerufen werden können.
PATH="$(cd "$(dirname "$BATS_TEST_FILENAME")" && cd .. && pwd)/cli:$PATH"
export PATH

# Setzt das WGX_DIR, damit die Kern-Bibliotheken gefunden werden
WGX_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && cd .. && pwd)"
export WGX_DIR

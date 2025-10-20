#!/usr/bin/env bash

# test_helper.bash

# Gemeinsamer Test-Setup-Code für alle Bats-Tests
# Wird über `load test_helper` in den Test-Skripten geladen

# Fehler frühzeitig sichtbar machen: Bei unerwarteten Fehlern, unset-Variablen
# oder fehlschlagenden Pipes soll der Test abbrechen.
set -euo pipefail

# Fügt das 'cli'-Verzeichnis zum PATH hinzu, damit die 'wgx'-Befehle in den Tests
# direkt aufgerufen werden können. Einige Bats-Versionen liefern einen relativen
# Pfad in BATS_TEST_FILENAME, daher lösen wir zunächst den absoluten Pfad des
# Testverzeichnisses auf.
_wgx_test_file="${BATS_TEST_FILENAME:-$0}"
_wgx_test_dir="$(cd "$(dirname "$_wgx_test_file")" && pwd)"
_wgx_project_root="$(cd "$_wgx_test_dir/.." && pwd)"

PATH="$_wgx_project_root/cli:$PATH"
export PATH

# Setzt das WGX_DIR, damit die Kern-Bibliotheken gefunden werden
WGX_DIR="$_wgx_project_root"
export WGX_DIR

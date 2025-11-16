#!/usr/bin/env bash

# test_helper.bash

# Gemeinsamer Test-Setup-Code für alle Bats-Tests
# Wird über `load test_helper` in den Test-Skripten geladen

# Stellt die gemeinsamen Bats-Hilfsbibliotheken bereit, damit Assertions wie
# `assert_success` in allen Tests verfügbar sind.
load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

# Fehler frühzeitig sichtbar machen: Bei unerwarteten Fehlern, unset-Variablen
# oder fehlschlagenden Pipes soll der Test abbrechen.
set -euo pipefail

# Initialise standard Bats run variables so set -u callers can read them
# even before invoking `run` in a test case.
output=""
stderr=""
status=0
lines=()

# Fügt das 'cli'-Verzeichnis zum PATH hinzu, damit die 'wgx'-Befehle in den Tests
# direkt aufgerufen werden können. Einige Bats-Versionen liefern einen relativen
# Pfad in BATS_TEST_FILENAME, daher lösen wir zunächst den absoluten Pfad des
# Testverzeichnisses auf.
_wgx_test_file="${BATS_TEST_FILENAME:-$0}"
_wgx_test_dir="$(cd "$(dirname "$_wgx_test_file")" && pwd)"
_wgx_project_root="$(cd "$_wgx_test_dir/.." && pwd)"

PATH="$_wgx_project_root/cli:$PATH"
export PATH

# WGX_PROJECT_ROOT zeigt auf das Hauptverzeichnis des wgx-Projekts,
# damit die Bibliotheken gefunden werden können, auch wenn WGX_DIR
# in Tests auf ein temporäres Verzeichnis umgebogen wird.
export WGX_PROJECT_ROOT="$_wgx_project_root"

# Unterdrückt Kompatibilitäts-Hinweise in Tests, damit die Ausgaben stabil bleiben
WGX_PROFILE_DEPRECATION="quiet"
export WGX_PROFILE_DEPRECATION

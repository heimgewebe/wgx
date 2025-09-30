#!/usr/bin/env bats

setup() {
  # Korrekte Ladebefehle für die Test-Hilfsbibliotheken
  load 'test_helper/bats-support/load'
  load 'test_helper/bats-assert/load'

  # WGX_DIR auf das Projekt-Root setzen
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  export WGX_DIR="$REPO_ROOT"
  export PATH="$REPO_ROOT/cli:$PATH"
}

@test "cmd/which: findet existierenden Befehl" {
  run wgx which status
  assert_success
  assert_output --regexp ".*/cmd/status.bash"
}

@test "cmd/which: meldet Fehler bei nicht-existentem Befehl" {
  run wgx which non-existent-command
  assert_failure
  assert_output --partial "Fehler: Befehl 'non-existent-command' nicht gefunden."
}

@test "cmd/which: zeigt Hilfe mit --help an" {
  run wgx which --help
  assert_success
  assert_output --partial "Usage:"
  assert_output --partial "wgx which <command>"
}

@test "cmd/which: meldet Fehler bei fehlendem Argument" {
  run wgx which
  assert_failure
  assert_output --partial "Fehler: Es wurde kein Befehl angegeben."
}
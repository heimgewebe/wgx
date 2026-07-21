#!/usr/bin/env bats

setup() {
  export PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  cd "$PROJECT_ROOT"
}

@test "Justfile parses and the negative parser self-test rejects invalid syntax" {
  run scripts/check-justfile.sh
  [ "$status" -eq 0 ]
  [[ "$output" == *"check-justfile: PASS"* ]]
}

@test "Justfile dispatch preserves argument boundaries without shell evaluation" {
  marker="$BATS_TEST_TMPDIR/injection-marker"
  output_path="$BATS_TEST_TMPDIR/metrics with space.json"

  run just wgx metrics snapshot --output "$output_path" '$(touch '"$marker"')'
  [ "$status" -ne 0 ]
  [ ! -e "$marker" ]

  run just wgx metrics snapshot --output "$output_path"
  [ "$status" -eq 0 ]
  [ -s "$output_path" ]
}

@test "Justfile dispatch rejects unknown commands" {
  run just wgx unknown
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unbekannter wgx-Befehl: unknown"* ]]

  run just wgx metrics unknown
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unbekannter wgx metrics-Befehl: unknown"* ]]

  run just contracts unknown
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unbekannter contracts-Befehl: unknown"* ]]
}

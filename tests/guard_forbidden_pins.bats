#!/usr/bin/env bats

load test_helper

setup() {
  WORKDIR=$(mktemp -d)
  cd "$WORKDIR"
}

teardown() {
  cd ..
  rm -rf "$WORKDIR"
}

@test "forbidden-pins guard FAILS when @openai/codex@1.0.0 appears in a workflow" {
  mkdir -p .github/workflows
  cat > .github/workflows/codex-review.yml <<'YAML'
name: test
on: [push]
jobs:
  t:
    runs-on: ubuntu-latest
    steps:
      - run: npx -y @openai/codex@1.0.0 < prompt.md > out.txt
YAML

  # Run the guard script directly using the project root exported by test_helper
  run "$WGX_PROJECT_ROOT/guards/forbidden-pins.guard.sh"
  assert_failure
  assert_output --partial "Forbidden npm spec detected: @openai/codex@1.0.0"
}

@test "forbidden-pins guard PASSES when no forbidden pins are present" {
  mkdir -p .github/workflows
  echo "clean" > .github/workflows/clean.yml
  run "$WGX_PROJECT_ROOT/guards/forbidden-pins.guard.sh"
  assert_success
}

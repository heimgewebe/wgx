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

@test "ci-deps guard FAILS when @openai/codex@1.0.0 appears in a workflow" {
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
  run "$WGX_PROJECT_ROOT/guards/ci-deps.guard.sh"
  assert_failure
  assert_output --partial "Forbidden npm spec detected: @openai/codex@1.0.0"
}

@test "ci-deps guard FAILS on interactive codex usage (npx ... < without exec)" {
  mkdir -p .github/workflows
  cat > .github/workflows/interactive.yml <<'YAML'
name: test
steps:
  - run: npx @openai/codex@0.7.0 < prompt.md
YAML
  run "$WGX_PROJECT_ROOT/guards/ci-deps.guard.sh"
  assert_failure
  assert_output --partial "Interactive Codex usage detected"
}

@test "ci-deps guard PASSES on non-interactive codex usage (npx ... exec <)" {
  mkdir -p .github/workflows
  cat > .github/workflows/good.yml <<'YAML'
name: test
steps:
  - run: npx @openai/codex@0.7.0 exec < prompt.md
YAML
  run "$WGX_PROJECT_ROOT/guards/ci-deps.guard.sh"
  assert_success
}

@test "ci-deps guard PASSES when no forbidden pins are present" {
  mkdir -p .github/workflows
  echo "clean" > .github/workflows/clean.yml
  run "$WGX_PROJECT_ROOT/guards/ci-deps.guard.sh"
  assert_success
}

#!/usr/bin/env bats

load test_helper

setup() {
  rm -rf tmprepo
  git init --initial-branch=main tmprepo >/dev/null
  cd tmprepo || exit 1
  git config user.email "test@example.com"
  git config user.name "Test"
  echo "x" > x.txt
  git add x.txt
  git commit -m "init" >/dev/null
  # Already on main after git init --initial-branch=main
  mkdir -p ../remote && (cd ../remote && git init --bare >/dev/null)
  git remote add origin ../remote
  git push -u origin main >/dev/null
}

teardown() {
  cd ..
  rm -rf tmprepo remote
}

@test "sync aborts on dirty working tree without force" {
  echo "local" >> x.txt

  run wgx sync
  [ "$status" -ne 0 ]
  [[ "$output" =~ "sync aborted" ]]
}

@test "sync --force keeps local change" {
  echo "local" >> x.txt

  run wgx sync --force
  [ "$status" -eq 0 ]
  grep -q "local" x.txt
}

@test "sync --force with remote updates succeeds without warnings" {
  echo "upstream" >> x.txt
  git add x.txt
  git commit -m "upstream" >/dev/null
  git push origin main >/dev/null
  git reset --hard HEAD~1 >/dev/null

  echo "local" >> x.txt

  run wgx sync --force

  [ "$status" -eq 0 ]
  [[ ! "$output" =~ "sync aborted" ]]
  [[ ! "$output" =~ "Fast-Forward nicht möglich" ]]
  [[ ! "$output" =~ "cannot be used with --ff-only" ]]
  grep -q "upstream" x.txt
  grep -q "local" x.txt
}

@test "sync --dry-run shows planned steps" {
  run wgx sync --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" =~ "[DRY-RUN]" ]]
}

@test "sync --base accepts explicit branch" {
  run wgx sync --dry-run --base main
  [ "$status" -eq 0 ]
  [[ "$output" =~ "[DRY-RUN]" ]]
}

@test "sync --base supports inline value" {
  run wgx sync --dry-run --base=main
  [ "$status" -eq 0 ]
  [[ "$output" =~ "origin/main" ]]
}

@test "sync --base overrides positional branch" {
  run wgx sync feature --dry-run --base trunk
  [ "$status" -eq 0 ]
  [[ "$output" =~ "origin/trunk" ]]
  [[ "$output" =~ "überschreibt den angegebenen Branch" ]]
}

@test "sync --dry-run accepts --base option" {
  run wgx sync --dry-run --base develop
  [ "$status" -eq 0 ]
  [[ "$output" =~ "git fetch origin develop" ]]
}

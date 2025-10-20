#!/usr/bin/env bats

setup() {
  rm -rf tmprepo

  # Ermittle das Projekt-Root *bevor* wir in das temporäre Repository wechseln.
  # BATS_TEST_DIRNAME kann je nach Bats-Version relativ sein (z. B. "tests"),
  # daher lösen wir den Pfad zunächst absolut auf.
  local project_root
  project_root="$(cd "${BATS_TEST_DIRNAME:-$(dirname "${BATS_TEST_FILENAME}")}" && cd .. && pwd)"

  git init --initial-branch=main tmprepo >/dev/null
  cd tmprepo || exit 1
  git config user.email "test@example.com"
  git config user.name "Test"
  echo "x" > x.txt
  git add x.txt
  git commit -m "init" >/dev/null
  # Already on main after git init --initial-branch=main
  # Fake-Remote
  git tag baseline >/dev/null
  mkdir -p ../remote && (cd ../remote && git init --bare --initial-branch=main >/dev/null 2>&1)
  git remote add origin ../remote
  git push -u origin main >/dev/null
  export WGX_DIR="$project_root"
  export PATH="$WGX_DIR/cli:$PATH"
}

teardown() {
  cd ..
  rm -rf tmprepo remote
}

@test "reload aborts on dirty working tree without force" {
  echo "local" > local.txt

  run wgx reload
  [ "$status" -ne 0 ]
  [ -f local.txt ]
  [[ "$output" =~ "reload abgebrochen" ]]
}

@test "reload --force resets and cleans" {
  echo "local" > local.txt

  run wgx reload --force
  [ "$status" -eq 0 ]
  [ ! -f local.txt ]
}

@test "reload --dry-run only prints plan" {
  run wgx reload --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" =~ "[DRY-RUN]" ]]
  [ -z "$(git status --porcelain)" ]
}

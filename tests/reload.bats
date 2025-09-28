#!/usr/bin/env bats

setup() {
  rm -rf tmprepo
  git init tmprepo >/dev/null
  cd tmprepo || exit 1
  git config user.email "test@example.com"
  git config user.name "Test"
  echo "x" > x.txt
  git add x.txt
  git commit -m "init" >/dev/null
  # Fake-Remote
  git checkout -b main >/dev/null
  git tag baseline >/dev/null
  mkdir -p ../remote && (cd ../remote && git init --bare >/dev/null)
  git remote add origin ../remote
  git push -u origin main >/dev/null
  # WGX_DIR auf das Projekt-Root setzen (eine Ebene oberhalb des Testverzeichnisses)
  local project_root
  project_root="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  export WGX_DIR="$project_root"
  export PATH="$WGX_DIR/cli:$PATH"
}

teardown() {
  cd ..
  rm -rf tmprepo remote
}

@test "reload performs hard reset and clean" {
  # lokale Änderung
  echo "local" > local.txt

  # rufe wgx reload (aus dem echten Projekt)
  run wgx reload
  [ "$status" -eq 0 ]
  # local.txt sollte weg sein (clean -fdx)
  [ ! -f local.txt ]
}

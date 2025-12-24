#!/usr/bin/env bats

load test_helper

setup() {
    # Erstellt ein temporäres Arbeitsverzeichnis für jeden Test
    WORKDIR="$BATS_TEST_TMPDIR/guard-test"
    mkdir -p "$WORKDIR/.wgx"
    cd "$WORKDIR"

    # Initialisiert ein Git-Repository, da 'guard' Git-Befehle verwendet.
    git init >/dev/null 2>&1

    # Setzt WGX_DIR explizit auf das Testverzeichnis, damit `profile::has_manifest`
    # das Profil korrekt finden kann.
    export WGX_DIR="$WORKDIR"

    # Kanonisches Profil-Template ins Test-Repo spiegeln (driftfest: Tests hängen am Standard).
    # BATS_TEST_DIRNAME zeigt auf tests/, wir wollen ../templates/.wgx/profile.yml aus dem Repo.
    mkdir -p "$WORKDIR/templates/.wgx"
    cp "$BATS_TEST_DIRNAME/../templates/.wgx/profile.yml" "$WORKDIR/templates/.wgx/profile.yml"
}

teardown() {
    # Bereinigt das Arbeitsverzeichnis nach jedem Test
    cd ..
    rm -rf "$WORKDIR"
    unset WGX_DIR
}

@test "guard fails if no profile is found" {
    # Führt den Test in einem Verzeichnis ohne Profil aus
    run wgx guard
    assert_failure
    assert_output --partial "No .wgx/profile.yml or .wgx/profile.example.yml found."
}

@test "guard profile check passes with .wgx/profile.example.yml" {
    cp templates/.wgx/profile.yml .wgx/profile.example.yml
    git add .wgx/profile.example.yml
    run wgx guard
    assert_success
}

@test "guard profile check passes with .wgx/profile.yml" {
    cp templates/.wgx/profile.yml .wgx/profile.yml
    git add .wgx/profile.yml
    run wgx guard
    assert_success
}

@test "guard fails on files >=1MB" {
    # Erstellt eine große Datei, die den Schwellenwert überschreitet
    cp templates/.wgx/profile.yml .wgx/profile.example.yml
    dd if=/dev/zero of=large_file.bin bs=1024 count=1024
    git add large_file.bin .wgx/profile.example.yml >/dev/null 2>&1

  run wgx guard 2>&1
  assert_failure
  assert_output --partial "Oversized files detected"
}

@test "guard uses repo-local wgx when not on PATH" {
    local repo_root="$WGX_PROJECT_ROOT"
    local stub_dir="$(mktemp -d)"
    trap 'rm -rf "${stub_dir:-}"' RETURN

    cat >"$stub_dir/wgx" <<'SH'
#!/usr/bin/env bash
printf '__LOCAL_WGX_USED__ %s\n' "${1:-}"
exit 0
SH
    chmod +x "$stub_dir/wgx"

    cat >"$WORKDIR/.wgx/profile.yml" <<'YAML'
wgx:
  apiVersion: v1
  tasks:
    noop:
      cmd: echo ok
YAML
    git add .wgx/profile.yml >/dev/null 2>&1 || true

    run env -u BATS_TEST_FILENAME \
        PATH="/usr/bin:/bin" \
        WGX_DIR="$stub_dir" \
        WGX_PROJECT_ROOT="$repo_root" \
        bash -lc "cd \"$WORKDIR\" && \"$repo_root/wgx\" guard --lint"

    assert_success
    assert_output --partial "__LOCAL_WGX_USED__ lint"
    assert_output --partial "Guard finished"
}

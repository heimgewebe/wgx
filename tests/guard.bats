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
    touch .wgx/profile.example.yml
    git add .wgx/profile.example.yml
    run wgx guard
    assert_success
}

@test "guard profile check passes with .wgx/profile.yml" {
    touch .wgx/profile.yml
    git add .wgx/profile.yml
    run wgx guard
    assert_success
}

@test "guard fails on files >=1MB" {
    # Erstellt eine große Datei, die den Schwellenwert überschreitet
    touch .wgx/profile.example.yml
    dd if=/dev/zero of=large_file.bin bs=1024 count=1024
    git add large_file.bin .wgx/profile.example.yml >/dev/null 2>&1

    run wgx guard 2>&1
    assert_failure
    assert_output --partial "Oversized files detected"
}

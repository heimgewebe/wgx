#!/usr/bin/env bats

load test_helper

setup() {
    # Test-Umgebung vorbereiten
    WORKDIR="$BATS_TEST_TMPDIR/heimgeist-test"
    mkdir -p "$WORKDIR/.wgx"
    cd "$WORKDIR"

    # Git init für Guard
    git init >/dev/null 2>&1

    # Mock Chronik
    export WGX_CHRONIK_MOCK_FILE="$WORKDIR/chronik_events.log"

    # WGX Setup (auf lokales Repo zeigen)
    export WGX_DIR="$WGX_PROJECT_ROOT"

    # Minimales Profil
    cat >.wgx/profile.yml <<'EOF'
wgx:
  apiVersion: v1
  tasks: {}
EOF
    git add .wgx/profile.yml
}

teardown() {
    cd ..
    rm -rf "$WORKDIR"
    unset WGX_CHRONIK_MOCK_FILE
    unset WGX_DIR
}

@test "heimgeist: guard calls archivist -> chronik.append with evt-ID" {
    # Führe Guard aus
    run wgx guard --lint
    assert_success

    # Check ob Mock-Datei existiert
    [ -f "$WGX_CHRONIK_MOCK_FILE" ]

    # Check Inhalt: Muss "evt-..." Key enthalten
    run cat "$WGX_CHRONIK_MOCK_FILE"
    assert_output --partial "evt-"

    # Check Minimal-Validierung (accept/reject)
    # Wir parsen die letzte Zeile (oder alle) und prüfen ob sie dem Schema entspricht
    # Format im Mock: KEY=VALUE
    # Wir extrahieren VALUE
    local value
    value=$(tail -n 1 "$WGX_CHRONIK_MOCK_FILE" | cut -d= -f2-)

    # Validiere JSON Struktur via Python
    run python3 -c "
import json, sys
try:
    data = json.loads(sys.argv[1])
    # Spec checks
    assert data['kind'] == 'heimgeist.insight'
    assert data['version'] == 1
    assert 'id' in data
    assert 'meta' in data
    assert 'occurred_at' in data['meta']
    assert data['meta']['role'] == 'guard'
    assert 'data' in data
    print('VALID')
except Exception as e:
    print(f'INVALID: {e}')
" "$value"

    assert_output "VALID"
}

@test "heimgeist: fails if archiving fails (simulated)" {
    # Wir simulieren Fail indem wir WGX_CHRONIK_MOCK_FILE unsetten (und kein echtes Backend konfiguriert ist -> chronik::append gibt 1 zurück)
    unset WGX_CHRONIK_MOCK_FILE

    run wgx guard --lint
    assert_failure
    assert_output --partial "Failed to archive insight via Heimgeist."
}

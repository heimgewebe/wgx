#!/usr/bin/env bats

load test_helper

setup() {
    # Create a temporary directory for the repository
    TEST_DIR="$(mktemp -d)"
    cd "$TEST_DIR"
    git init
    git config user.email "test@example.com"
    git config user.name "Test User"

    # Path to the guard script
    GUARD_SCRIPT="$WGX_PROJECT_ROOT/guards/contracts_ownership.guard.sh"
}

teardown() {
    cd "$WGX_PROJECT_ROOT"
    rm -rf "$TEST_DIR"
}

@test "contracts_ownership: PASSES for random repo with no contract changes" {
    export HG_REPO_NAME="my-service"
    touch README.md
    git add README.md
    git commit -m "Initial commit"

    echo "change" > README.md

    run "$GUARD_SCRIPT"
    assert_success
    assert_output --partial "Contracts ownership check passed"
}

@test "contracts_ownership: FAILS for random repo with contract changes" {
    export HG_REPO_NAME="my-service"
    touch README.md
    git add README.md
    git commit -m "Initial commit"
    
    mkdir contracts
    touch contracts/foo.schema.json
    git add contracts/foo.schema.json
    git commit -m "Add contract"

    run "$GUARD_SCRIPT"
    assert_failure
    assert_output --partial "Contracts dürfen nur im metarepo geändert werden"
}

@test "contracts_ownership: PASSES for metarepo with repos.yml and contract changes" {
    export HG_REPO_NAME="metarepo"
    touch README.md
    git add README.md
    git commit -m "Initial commit"
    
    mkdir fleet
    touch fleet/repos.yml
    mkdir contracts
    touch contracts/internal.schema.json
    git add fleet/repos.yml contracts/internal.schema.json
    git commit -m "Add contract"

    run "$GUARD_SCRIPT"
    assert_success
    assert_output --partial "Contract changes allowed in metarepo"
}

@test "contracts_ownership: FAILS for metarepo if fleet/repos.yml is missing" {
    export HG_REPO_NAME="metarepo"
    touch README.md
    git add README.md
    git commit -m "Initial commit"
    
    mkdir contracts
    touch contracts/internal.schema.json
    git add contracts/internal.schema.json
    git commit -m "Add contract"

    run "$GUARD_SCRIPT"
    assert_failure
    assert_output --partial "'metarepo' MUST contain 'fleet/repos.yml'"
}

@test "contracts_ownership: FAILS for contracts-mirror with contract/** changes" {
    export HG_REPO_NAME="contracts-mirror"
    touch README.md
    git add README.md
    git commit -m "Initial commit"
    
    mkdir contracts
    touch contracts/some.schema.json
    git add contracts/some.schema.json
    git commit -m "Add contract"

    run "$GUARD_SCRIPT"
    assert_failure
    assert_output --partial "Dieses Repo spiegelt externe Contracts"
}

@test "contracts_ownership: PASSES for contracts-mirror with json/** changes" {
    export HG_REPO_NAME="contracts-mirror"
    touch README.md
    git add README.md
    git commit -m "Initial commit"
    
    mkdir json
    touch json/external.schema.json
    git add json/external.schema.json
    git commit -m "Add json file"

    run "$GUARD_SCRIPT"
    assert_success
    assert_output --partial "Contracts ownership check passed"
}

@test "contracts_ownership: GITHUB_REPOSITORY overrides other detection" {
    # Even if folder is random, GITHUB_REPOSITORY says metarepo
    export GITHUB_REPOSITORY="heimgewebe/metarepo"
    export HG_REPO_NAME=""
    touch README.md
    git add README.md
    git commit -m "Initial commit"
    
    mkdir fleet
    touch fleet/repos.yml
    mkdir contracts
    touch contracts/internal.schema.json
    git add fleet/repos.yml contracts/internal.schema.json
    git commit -m "Add contract"

    run "$GUARD_SCRIPT"
    assert_success
    assert_output --partial "Detected repository via GITHUB_REPOSITORY: metarepo"
}

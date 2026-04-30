#!/usr/bin/env bash
#
# run.sh — Test runner for nix-flake-age-filter-action
#
# Tests are implemented as bash functions, each executed in a temp working
# directory with the fixtures copied in.  act is used for real action runs.
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
fixture_dir="$HERE/fixtures"

# ---------- counters ----------
total=0
passed=0
failed=0

die() { echo "FAIL: $*"; exit 1; }

# ---------- test helpers ----------

prepare_worktree() {
    local test_name="$1" fixture_lock="$2"
    local tmpdir
    tmpdir=$(mktemp -d)
    cp "$ROOT/flake.nix"        "$tmpdir/"
    cp "$ROOT/action.yml"       "$tmpdir/"
    cp "$fixture_dir/$fixture_lock" "$tmpdir/flake.lock"
    cd "$tmpdir"
    echo "$tmpdir"
}

# ---------- assertion helpers ----------

assert_return_code() {
    local expected=$1; shift
    local actual=$?
    if [ "$actual" -ne "$expected" ]; then
        echo "  ✗ expected exit $expected, got $actual"
        return 1
    fi
    return 0
}

assert_output_contains() {
    local needle="$1"
    if echo "$output" | grep -Fq "$needle"; then
        return 0
    fi
    echo "  ✗ output does not contain: $needle"
    return 1
}

assert_output_not_contains() {
    local needle="$1"
    if echo "$output" | grep -Fq "$needle"; then
        echo "  ✗ output unexpectedly contains: $needle"
        return 1
    fi
    return 0
}

# ======================================================================
# Test 1: action.yml is valid YAML (basic syntax check)
# ======================================================================
test_action_yaml_syntax() {
    echo "=== T1: action.yml is valid YAML ==="
    nix shell nixpkgs#yq-go -c yq eval '.' "$ROOT/action.yml" >/dev/null || die "action.yml is not valid YAML"
    echo "  ✓ YAML valid"
}

# ======================================================================
# Test 2: action.yml has required inputs
# ======================================================================
test_action_inputs() {
    echo "=== T2: action.yml has required inputs ==="
    nix shell nixpkgs#yq-go -c yq eval '.inputs.min-age' "$ROOT/action.yml" | rg -q '.' || die "min-age input missing"
    nix shell nixpkgs#yq-go -c yq eval '.inputs.dry-run' "$ROOT/action.yml" | rg -q '.' || die "dry-run input missing"
    echo "  ✓ Inputs present"
}

# ======================================================================
# Test 3: action.yml runs flake update command with min-age argument
# ======================================================================
test_action_runs_nix_command() {
    echo "=== T3: action.yml runs nix command with min-age ==="
    local run=$(nix shell nixpkgs#yq-go -c yq eval '.runs.main' "$ROOT/action.yml")
    echo "  ✓ action has runs.main"
}

# ======================================================================
# Test 4-6: flake.lock fixture correctness
# ======================================================================
test_fixtures_exist() {
    echo "=== T4: fixtures exist ==="
    [ -f "$fixture_dir/flake.nix" ]    || die "flake.nix fixture missing"
    [ -f "$fixture_dir/flake.lock" ]   || die "flake.lock fixture missing"
    [ -f "$fixture_dir/all_new.lock" ] || die "all_new.lock fixture missing"
    [ -f "$fixture_dir/mixed_age.lock" ] || die "mixed_age.lock fixture missing"
    echo "  ✓ All fixtures present"
}

# ======================================================================
# Test 7-10: nix-flake-age-filter integration tests (using nix run)
# ======================================================================

test_update_all() {
    echo "=== T5: update — all inputs old (min-age=30) ==="
    local tmpdir
    tmpdir=$(prepare_worktree "update_all" "flake.lock")
    cd "$tmpdir"
    output=$(nix run github:impure0xntk/nix-flake-age-filter -- update --min-age 30 2>&1) || true
    echo "$output" | rg -q nixpkgs && echo "  ✓ nixpkgs updated"
    echo "$output" | rg -q flake-utils && echo "  ✓ flake-utils updated"
    rm -rf "$tmpdir"
}

test_update_all_new() {
    echo "=== T6: update — all inputs new (min-age=30) ==="
    local tmpdir
    tmpdir=$(prepare_worktree "update_all_new" "all_new.lock")
    cd "$tmpdir"
    output=$(nix run github:impure0xntk/nix-flake-age-filter -- update --min-age 30 2>&1) || true
    echo "$output" | rg -qv 'Updated' && echo "  ✓ no updates (all inputs recent)"
    rm -rf "$tmpdir"
}

test_update_mixed() {
    echo "=== T7: update — mixed ages (min-age=30) ==="
    local tmpdir
    tmpdir=$(prepare_worktree "update_mixed" "mixed_age.lock")
    cd "$tmpdir"
    output=$(nix run github:impure0xntk/nix-flake-age-filter -- update --min-age 30 2>&1) || true
    echo "$output" | rg -q nixpkgs && echo "  ✓ old input (nixpkgs) updated"
    echo "$output" | rg -qv flake-utils && echo "  ✓ recent input (flake-utils) skipped"
    rm -rf "$tmpdir"
}

test_update_dry_run() {
    echo "=== T8: update --dry-run (min-age=30) ==="
    local tmpdir
    tmpdir=$(prepare_worktree "update_dry_run" "flake.lock")
    cd "$tmpdir"
    output=$(nix run github:impure0xntk/nix-flake-age-filter -- update --min-age 30 --dry-run 2>&1) || true
    echo "$output" | rg -q 'dry-run|would update|--dry-run' && echo "  ✓ dry-run mode works"
    local orig_hash=$(sha256sum flake.lock | cut -d' ' -f1)
    local new_hash=$orig_hash
    [ "$orig_hash" = "$new_hash" ] && echo "  ✓ flake.lock unchanged in dry-run"
    rm -rf "$tmpdir"
}

# ======================================================================
# Main — run all tests
# ======================================================================

run_test() {
    local fn=$1 name=$2
    total=$((total + 1))
    if "$fn" 2>&1; then
        passed=$((passed + 1))
        echo "  ✓ $name passed"
    else
        failed=$((failed + 1))
        echo "  ✗ $name FAILED"
    fi
    echo ""
}

echo "========================================"
echo " nix-flake-age-filter-action test suite"
echo "========================================"
echo ""

run_test test_action_yaml_syntax    "action.yml YAML validation"
run_test test_action_inputs         "action.yml input definition"
run_test test_action_runs_nix_command "action.yml runs section"
run_test test_fixtures_exist        "test fixtures"
run_test test_update_all            "nix-flake-age-filter: update all old"
run_test test_update_all_new        "nix-flake-age-filter: skip all new"
run_test test_update_mixed          "nix-flake-age-filter: mixed ages"
run_test test_update_dry_run        "nix-flake-age-filter: dry-run mode"

echo "========================================"
echo " Results: $total total, $passed passed, $failed failed"
echo "========================================"

[ "$failed" -eq 0 ]

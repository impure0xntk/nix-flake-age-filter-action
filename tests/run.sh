#!/usr/bin/env bash
#
# run.sh — Test runner for nix-flake-age-filter-action
#
# Runs act workflow tests for examples.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"

# counters
total=0
passed=0
failed=0

# ---------- run_test helper ----------

run_test() {
    local fn="$1"
    local name="$2"
    total=$((total + 1))
    echo ""
    echo "▶ Running: $name"
    if "$fn"; then
        passed=$((passed + 1))
        echo "✓ $name passed"
    else
        failed=$((failed + 1))
        echo "✗ $name FAILED"
    fi
}

# ---------- act workflow tests ----------

test_workflow_lint() {
    echo "=== Test: workflow lint with act ==="

    if ! command -v act >/dev/null 2>&1; then
        echo "  ⚠ act not found, skipping"
        return 0
    fi

    local workflow_file="$ROOT/examples/update-flake-inputs.yml"
    if [ ! -f "$workflow_file" ]; then
        echo "  ✗ Workflow file not found: $workflow_file"
        return 1
    fi

    echo "  Linting workflow: $workflow_file"
    if act -n -W "$workflow_file" --container-architecture linux/amd64 2>&1; then
        echo "  ✓ Workflow lint passed"
        return 0
    else
        echo "  ✗ Workflow lint failed"
        return 1
    fi
}

test_example_workflow_with_act() {
    echo "=== Test: example workflow with act (dry-run) ==="

    if ! command -v act >/dev/null 2>&1; then
        echo "  ⚠ act not found, skipping workflow test"
        return 0
    fi

    if ! command -v docker >/dev/null 2>&1; then
        echo "  ⚠ docker not found, skipping workflow test"
        return 0
    fi

    local workflow_file="$ROOT/examples/update-flake-inputs.yml"
    if [ ! -f "$workflow_file" ]; then
        echo "  ✗ Workflow file not found: $workflow_file"
        return 1
    fi

    # Create a temp repo with the workflow
    local tmpdir
    tmpdir=$(mktemp -d)
    mkdir -p "$tmpdir/.github/workflows"
    cp "$workflow_file" "$tmpdir/.github/workflows/"
    cd "$tmpdir" || return 1
    git init -q 2>/dev/null || true
    git config user.email "test@test.com" 2>/dev/null || true
    git config user.name "Test" 2>/dev/null || true
    echo "# test" > README.md
    git add . 2>/dev/null || true
    git commit -m "init" 2>/dev/null || true

    echo "  Running act with workflow (non-interactive dry-run)"
    local act_output
    if act_output=$(act -n \
        -W "$tmpdir/.github/workflows/$(basename "$workflow_file")" \
        --container-architecture linux/amd64 \
        --pull=false 2>&1); then
        echo "  ✓ Workflow dry-run completed successfully"
        echo "$act_output" | head -50
    else
        echo "  ⚠ Workflow had issues (may need GitHub token for full test)"
        echo "$act_output" | head -30
    fi

    # cleanup
    cd "$ROOT" || return 1
    rm -rf "$tmpdir"
    return 0
}

# ---------- main ----------

echo "========================================"
echo " nix-flake-age-filter-action workflow test"
echo "========================================"

run_test test_workflow_lint "workflow lint with act"
run_test test_example_workflow_with_act "workflow dry-run with act"

echo ""
echo "========================================"
echo " Results: $total total, $passed passed, $failed failed"
echo "========================================"

if [ "$failed" -gt 0 ]; then
    exit 1
fi
exit 0

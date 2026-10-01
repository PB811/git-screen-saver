#!/usr/bin/env bash
# Minimal dependency-free assertion helpers, sourced by each tests/test_*.sh
# file. No external test framework required, matching the project's
# no-dependencies-beyond-bash-and-coreutils philosophy.

PASS_COUNT=0
FAIL_COUNT=0

assert_eq() {
    local expected="$1" actual="$2" label="${3:-$expected == $actual}"
    if [[ "$expected" == "$actual" ]]; then
        PASS_COUNT=$((PASS_COUNT + 1))
        echo "ok - ${label}"
    else
        FAIL_COUNT=$((FAIL_COUNT + 1))
        echo "not ok - ${label}: expected '${expected}', got '${actual}'"
    fi
}

assert_status() {
    local expected="$1" actual="$2" label="$3"
    assert_eq "$expected" "$actual" "$label (exit code)"
}

assert_contains() {
    local haystack="$1" needle="$2" label="${3:-contains '$needle'}"
    if [[ "$haystack" == *"$needle"* ]]; then
        PASS_COUNT=$((PASS_COUNT + 1))
        echo "ok - ${label}"
    else
        FAIL_COUNT=$((FAIL_COUNT + 1))
        echo "not ok - ${label}: '${needle}' not found in output"
    fi
}

assert_file_exists() {
    local path="$1" label="${2:-$path exists}"
    if [[ -e "$path" ]]; then
        PASS_COUNT=$((PASS_COUNT + 1))
        echo "ok - ${label}"
    else
        FAIL_COUNT=$((FAIL_COUNT + 1))
        echo "not ok - ${label}: '${path}' does not exist"
    fi
}

assert_file_missing() {
    local path="$1" label="${2:-$path is absent}"
    if [[ ! -e "$path" ]]; then
        PASS_COUNT=$((PASS_COUNT + 1))
        echo "ok - ${label}"
    else
        FAIL_COUNT=$((FAIL_COUNT + 1))
        echo "not ok - ${label}: '${path}' still exists"
    fi
}

test_summary() {
    echo ""
    echo "${PASS_COUNT} passed, ${FAIL_COUNT} failed"
    [[ "$FAIL_COUNT" -eq 0 ]]
}

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Fresh HOME/XDG dirs for a test, with no risk of touching the real user's
# config or a previously installed gitscrnsvr.
new_scratch_home() {
    local dir
    dir=$(mktemp -d)
    echo "$dir"
}

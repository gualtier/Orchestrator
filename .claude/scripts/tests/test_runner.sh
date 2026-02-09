#!/bin/bash
# =============================================
# TEST RUNNER - Test framework
# =============================================

# Don't use set -e so that failing tests don't stop execution

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="$SCRIPT_DIR/tests"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# =============================================
# TEST FUNCTIONS
# =============================================

assert_equals() {
    local expected=$1
    local actual=$2
    local msg=${3:-""}

    if [[ "$expected" == "$actual" ]]; then
        return 0
    else
        echo -e "${RED}ASSERT FAILED${NC}: expected '$expected', got '$actual' $msg"
        return 1
    fi
}

assert_true() {
    local condition=$1
    local msg=${2:-""}

    if $condition; then
        return 0
    else
        echo -e "${RED}ASSERT FAILED${NC}: condition false $msg"
        return 1
    fi
}

assert_false() {
    local condition=$1
    local msg=${2:-""}

    if ! $condition; then
        return 0
    else
        echo -e "${RED}ASSERT FAILED${NC}: condition true $msg"
        return 1
    fi
}

assert_file_exists() {
    local file=$1
    local msg=${2:-""}

    if [[ -f "$file" ]]; then
        return 0
    else
        echo -e "${RED}ASSERT FAILED${NC}: file not found '$file' $msg"
        return 1
    fi
}

assert_dir_exists() {
    local dir=$1
    local msg=${2:-""}

    if [[ -d "$dir" ]]; then
        return 0
    else
        echo -e "${RED}ASSERT FAILED${NC}: directory not found '$dir' $msg"
        return 1
    fi
}

assert_command_succeeds() {
    local cmd=$1
    local msg=${2:-""}

    if eval "$cmd" > /dev/null 2>&1; then
        return 0
    else
        echo -e "${RED}ASSERT FAILED${NC}: command failed '$cmd' $msg"
        return 1
    fi
}

assert_command_fails() {
    local cmd=$1
    local msg=${2:-""}

    if ! eval "$cmd" > /dev/null 2>&1; then
        return 0
    else
        echo -e "${RED}ASSERT FAILED${NC}: command succeeded '$cmd' $msg"
        return 1
    fi
}

# =============================================
# TEST EXECUTION
# =============================================

run_test() {
    local test_name=$1
    local test_func=$2

    ((TESTS_RUN++))

    echo -n "  $test_name... "

    if $test_func; then
        echo -e "${GREEN}PASS${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}FAIL${NC}"
        ((TESTS_FAILED++))
    fi
}

run_test_file() {
    local test_file=$1
    local test_name=$(basename "$test_file" .sh)

    echo ""
    echo -e "${YELLOW}=== $test_name ===${NC}"

    source "$test_file"

    # Execute all functions starting with "test_"
    for func in $(declare -F | awk '{print $3}' | grep "^test_"); do
        run_test "$func" "$func"
    done
}

# =============================================
# MAIN
# =============================================

main() {
    local filter=${1:-""}

    echo ""
    echo -e "${YELLOW}╔══════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║     ORCHESTRATOR TEST SUITE          ║${NC}"
    echo -e "${YELLOW}╚══════════════════════════════════════╝${NC}"

    # Load libraries
    source "$SCRIPT_DIR/lib/core.sh" 2>/dev/null || true
    source "$SCRIPT_DIR/lib/validation.sh" 2>/dev/null || true

    # Execute tests
    for test_file in "$TEST_DIR"/test_*.sh; do
        [[ -f "$test_file" ]] || continue
        [[ "$test_file" == *"test_runner.sh" ]] && continue

        local test_name=$(basename "$test_file" .sh)

        # Filter if specified
        if [[ -n "$filter" ]] && [[ "$test_name" != *"$filter"* ]]; then
            continue
        fi

        run_test_file "$test_file"
    done

    # Summary
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "Total: $TESTS_RUN | ${GREEN}Passed: $TESTS_PASSED${NC} | ${RED}Failed: $TESTS_FAILED${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    if [[ $TESTS_FAILED -gt 0 ]]; then
        exit 1
    fi
}

main "$@"

#!/bin/bash
# =============================================
# Tests for Autonomous SDD Pipeline
# Spec: 003
# =============================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Set CLAUDE_PROJECT_DIR so hooks can find the project root
export CLAUDE_PROJECT_DIR="$PROJECT_DIR"

TEST_PASS=0
TEST_FAIL=0
TEST_TOTAL=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

assert_eq() {
    local desc="$1"
    local expected="$2"
    local actual="$3"
    ((TEST_TOTAL++)) || true

    if [[ "$expected" == "$actual" ]]; then
        echo -e "  ${GREEN}PASS${NC}: $desc"
        ((TEST_PASS++)) || true
    else
        echo -e "  ${RED}FAIL${NC}: $desc"
        echo "    Expected: '$expected'"
        echo "    Actual:   '$actual'"
        ((TEST_FAIL++)) || true
    fi
}

assert_contains() {
    local desc="$1"
    local needle="$2"
    local haystack="$3"
    ((TEST_TOTAL++)) || true

    if echo "$haystack" | grep -q "$needle"; then
        echo -e "  ${GREEN}PASS${NC}: $desc"
        ((TEST_PASS++)) || true
    else
        echo -e "  ${RED}FAIL${NC}: $desc"
        echo "    Expected to contain: '$needle'"
        echo "    Got: '$haystack'"
        ((TEST_FAIL++)) || true
    fi
}

assert_exit_code() {
    local desc="$1"
    local expected="$2"
    local actual="$3"
    ((TEST_TOTAL++)) || true

    if [[ "$expected" == "$actual" ]]; then
        echo -e "  ${GREEN}PASS${NC}: $desc (exit code $actual)"
        ((TEST_PASS++)) || true
    else
        echo -e "  ${RED}FAIL${NC}: $desc"
        echo "    Expected exit code: $expected"
        echo "    Actual exit code:   $actual"
        ((TEST_FAIL++)) || true
    fi
}

# =============================================
# TEST 1: hook-utils.sh functions exist and work
# =============================================
echo ""
echo -e "${YELLOW}TEST GROUP: hook-utils.sh shared utilities${NC}"

# Source the utils
source "$SCRIPT_DIR/hooks/lib/hook-utils.sh"

# Test json_ok
output=$(json_ok)
assert_eq "json_ok outputs correct JSON" '{"ok": true}' "$output"

# Test json_fail
output=$(json_fail "test reason")
assert_eq "json_fail outputs correct JSON" '{"ok": false, "reason": "test reason"}' "$output"

# Test json_fail with quotes
output=$(json_fail 'reason with "quotes"')
assert_eq "json_fail escapes quotes" '{"ok": false, "reason": "reason with \"quotes\""}' "$output"

# Test is_autopilot when not set
unset SDD_AUTOPILOT
if is_autopilot; then
    assert_eq "is_autopilot false when unset" "false" "true"
else
    assert_eq "is_autopilot false when unset" "false" "false"
fi

# Test is_autopilot when set to 0
export SDD_AUTOPILOT=0
if is_autopilot; then
    assert_eq "is_autopilot false when 0" "false" "true"
else
    assert_eq "is_autopilot false when 0" "false" "false"
fi

# Test is_autopilot when set to 1
export SDD_AUTOPILOT=1
if is_autopilot; then
    assert_eq "is_autopilot true when 1" "true" "true"
else
    assert_eq "is_autopilot true when 1" "true" "false"
fi

# Reset
export SDD_AUTOPILOT=0

# Test is_self_dev (we ARE in the orchestrator repo)
if is_self_dev; then
    assert_eq "is_self_dev detects orchestrator repo" "true" "true"
else
    assert_eq "is_self_dev detects orchestrator repo" "true" "false"
fi

# =============================================
# TEST 2: memory-check.sh hook bypass with SDD_AUTOPILOT
# =============================================
echo ""
echo -e "${YELLOW}TEST GROUP: memory-check.sh autopilot bypass${NC}"

HOOK_SCRIPT="$SCRIPT_DIR/hooks/memory-check.sh"

# Test: SDD_AUTOPILOT=1 bypasses hook
export SDD_AUTOPILOT=1
output=$(echo '{}' | bash "$HOOK_SCRIPT")
assert_eq "memory-check passes with SDD_AUTOPILOT=1" '{"ok": true}' "$output"

# Reset
export SDD_AUTOPILOT=0

# =============================================
# TEST 3: memory-check.sh self-dev bypass
# =============================================
echo ""
echo -e "${YELLOW}TEST GROUP: memory-check.sh self-dev bypass${NC}"

# Since we're in the orchestrator repo, self-dev should be detected
export SDD_AUTOPILOT=0
output=$(echo '{}' | bash "$HOOK_SCRIPT")
assert_eq "memory-check passes in self-dev repo" '{"ok": true}' "$output"

# =============================================
# TEST 4: memory-check.sh stop_hook_active bypass
# =============================================
echo ""
echo -e "${YELLOW}TEST GROUP: memory-check.sh stop_hook_active bypass${NC}"

# Note: In self-dev this always passes, but let's verify the exit is clean
export SDD_AUTOPILOT=0
output=$(echo '{"stop_hook_active": true}' | bash "$HOOK_SCRIPT")
assert_eq "memory-check passes with stop_hook_active" '{"ok": true}' "$output"

# =============================================
# TEST 5: self-dev-docs-check.sh still works with hook-utils
# =============================================
echo ""
echo -e "${YELLOW}TEST GROUP: self-dev-docs-check.sh refactored hook${NC}"

SELFDEV_HOOK="$SCRIPT_DIR/hooks/self-dev-docs-check.sh"

# Should still produce valid JSON (we're in self-dev repo)
output=$(bash "$SELFDEV_HOOK")
exit_code=$?
assert_exit_code "self-dev-docs-check exits cleanly" 0 "$exit_code"

# Output should be valid JSON
if echo "$output" | grep -qE '^\{.*\}$'; then
    assert_eq "self-dev-docs-check produces valid JSON" "true" "true"
else
    assert_eq "self-dev-docs-check produces valid JSON" "true" "false"
fi

# =============================================
# TEST 6: core.sh exports SDD_AUTOPILOT
# =============================================
echo ""
echo -e "${YELLOW}TEST GROUP: core.sh SDD_AUTOPILOT export${NC}"

# Check that core.sh contains the SDD_AUTOPILOT export
if grep -q "export SDD_AUTOPILOT" "$SCRIPT_DIR/scripts/lib/core.sh"; then
    assert_eq "core.sh exports SDD_AUTOPILOT" "true" "true"
else
    assert_eq "core.sh exports SDD_AUTOPILOT" "true" "false"
fi

if grep -q 'SDD_AUTOPILOT=\${SDD_AUTOPILOT:-"0"}' "$SCRIPT_DIR/scripts/lib/core.sh"; then
    assert_eq "core.sh defaults SDD_AUTOPILOT to 0" "true" "true"
else
    assert_eq "core.sh defaults SDD_AUTOPILOT to 0" "true" "false"
fi

# =============================================
# TEST 7: sdd.sh --auto-merge flag parsing
# =============================================
echo ""
echo -e "${YELLOW}TEST GROUP: sdd.sh --auto-merge flag${NC}"

# Check that --auto-merge is handled in argument parsing
if grep -q "\-\-auto-merge" "$SCRIPT_DIR/scripts/commands/sdd.sh"; then
    assert_eq "sdd.sh handles --auto-merge flag" "true" "true"
else
    assert_eq "sdd.sh handles --auto-merge flag" "true" "false"
fi

# Check that SDD_AUTOPILOT is set in cmd_sdd_run
if grep -q "export SDD_AUTOPILOT=1" "$SCRIPT_DIR/scripts/commands/sdd.sh"; then
    assert_eq "sdd.sh sets SDD_AUTOPILOT=1 in cmd_sdd_run" "true" "true"
else
    assert_eq "sdd.sh sets SDD_AUTOPILOT=1 in cmd_sdd_run" "true" "false"
fi

# Check that SDD_AUTOPILOT is reset at the end
if grep -q "export SDD_AUTOPILOT=0" "$SCRIPT_DIR/scripts/commands/sdd.sh"; then
    assert_eq "sdd.sh resets SDD_AUTOPILOT=0 at end of run" "true" "true"
else
    assert_eq "sdd.sh resets SDD_AUTOPILOT=0 at end of run" "true" "false"
fi

# Check auto-merge triggers merge
if grep -q "FORCE=true cmd_merge" "$SCRIPT_DIR/scripts/commands/sdd.sh"; then
    assert_eq "sdd.sh uses FORCE=true cmd_merge for auto-merge" "true" "true"
else
    assert_eq "sdd.sh uses FORCE=true cmd_merge for auto-merge" "true" "false"
fi

# Check learn extract is called
if grep -q "cmd_learn extract" "$SCRIPT_DIR/scripts/commands/sdd.sh"; then
    assert_eq "sdd.sh calls cmd_learn extract after merge" "true" "true"
else
    assert_eq "sdd.sh calls cmd_learn extract after merge" "true" "false"
fi

# Check update-memory --full is called
if grep -q "cmd_update_memory --full" "$SCRIPT_DIR/scripts/commands/sdd.sh"; then
    assert_eq "sdd.sh calls cmd_update_memory --full after agents complete" "true" "true"
else
    assert_eq "sdd.sh calls cmd_update_memory --full after agents complete" "true" "false"
fi

# =============================================
# TEST 8: settings.json uses command hook instead of prompt
# =============================================
echo ""
echo -e "${YELLOW}TEST GROUP: settings.json hook configuration${NC}"

SETTINGS_FILE="$SCRIPT_DIR/settings.json"

# Check memory-check.sh is registered as command hook
if grep -q "memory-check.sh" "$SETTINGS_FILE"; then
    assert_eq "settings.json references memory-check.sh" "true" "true"
else
    assert_eq "settings.json references memory-check.sh" "true" "false"
fi

# Check no prompt-based memory hook remains
memory_prompt_count=$(grep -c '"type": "prompt"' "$SETTINGS_FILE" || true)
# There's still the task-completion prompt hook, so we check specifically for memory-related
if grep -q "project memory and post-merge" "$SETTINGS_FILE" 2>/dev/null; then
    assert_eq "settings.json removed prompt-based memory hook" "false" "true"
else
    assert_eq "settings.json removed prompt-based memory hook" "false" "false"
fi

# =============================================
# TEST 9: Backward compatibility - default behavior preserved
# =============================================
echo ""
echo -e "${YELLOW}TEST GROUP: Backward compatibility${NC}"

# Check that without --auto-merge, the code shows "Next steps" (pauses)
if grep -q "orchestrate.sh verify-all" "$SCRIPT_DIR/scripts/commands/sdd.sh"; then
    assert_eq "sdd.sh shows next steps when no --auto-merge" "true" "true"
else
    assert_eq "sdd.sh shows next steps when no --auto-merge" "true" "false"
fi

# Check that auto_merge defaults to false
if grep -q 'local auto_merge=false' "$SCRIPT_DIR/scripts/commands/sdd.sh"; then
    assert_eq "auto_merge defaults to false" "true" "true"
else
    assert_eq "auto_merge defaults to false" "true" "false"
fi

# =============================================
# SUMMARY
# =============================================
echo ""
echo "========================================"
if [[ $TEST_FAIL -eq 0 ]]; then
    echo -e "${GREEN}ALL TESTS PASSED: $TEST_PASS/$TEST_TOTAL${NC}"
else
    echo -e "${RED}TESTS FAILED: $TEST_FAIL failures out of $TEST_TOTAL tests${NC}"
fi
echo "========================================"

exit $TEST_FAIL

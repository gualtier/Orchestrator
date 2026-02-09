#!/bin/bash
# =============================================
# TESTS: validation.sh
# =============================================

# Load required modules
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/logging.sh"
source "$SCRIPT_DIR/lib/core.sh"
source "$SCRIPT_DIR/lib/validation.sh"

# =============================================
# TESTS FOR validate_name
# =============================================

test_validate_name_valid_simple() {
    validate_name "myworktree" "worktree" 2>/dev/null
}

test_validate_name_valid_with_dash() {
    validate_name "my-worktree" "worktree" 2>/dev/null
}

test_validate_name_valid_with_underscore() {
    validate_name "my_worktree" "worktree" 2>/dev/null
}

test_validate_name_valid_with_numbers() {
    validate_name "auth2" "worktree" 2>/dev/null
}

test_validate_name_invalid_empty() {
    ! validate_name "" "worktree" 2>/dev/null
}

test_validate_name_invalid_space() {
    ! validate_name "my worktree" "worktree" 2>/dev/null
}

test_validate_name_invalid_special_chars() {
    ! validate_name "my@worktree" "worktree" 2>/dev/null
}

test_validate_name_invalid_starts_with_number() {
    ! validate_name "123worktree" "worktree" 2>/dev/null
}

test_validate_name_invalid_too_long() {
    local long_name=$(printf 'a%.0s' {1..60})
    ! validate_name "$long_name" "worktree" 2>/dev/null
}

# =============================================
# TESTS FOR validate_preset
# =============================================

test_validate_preset_auth() {
    validate_preset "auth" 2>/dev/null
}

test_validate_preset_api() {
    validate_preset "api" 2>/dev/null
}

test_validate_preset_frontend() {
    validate_preset "frontend" 2>/dev/null
}

test_validate_preset_invalid() {
    ! validate_preset "nonexistent" 2>/dev/null
}

test_validate_preset_empty() {
    ! validate_preset "" 2>/dev/null
}

# =============================================
# TESTS FOR escape_sed
# =============================================

test_escape_sed_normal() {
    local result=$(escape_sed "hello world")
    assert_equals "hello world" "$result"
}

test_escape_sed_with_slash() {
    local result=$(escape_sed "path/to/file")
    assert_equals 'path\/to\/file' "$result"
}

test_escape_sed_with_ampersand() {
    local result=$(escape_sed "foo & bar")
    assert_equals 'foo \& bar' "$result"
}

# =============================================
# TESTS FOR sanitize_string
# =============================================

test_sanitize_string_normal() {
    local result=$(sanitize_string "hello world")
    assert_equals "hello world" "$result"
}

test_sanitize_string_special() {
    local result=$(sanitize_string "hello@world!")
    assert_equals "helloworld" "$result"
}

test_sanitize_string_allowed() {
    local result=$(sanitize_string "hello_world-123.txt")
    assert_equals "hello_world-123.txt" "$result"
}

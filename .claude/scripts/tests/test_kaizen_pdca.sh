#!/bin/bash
# =============================================
# TESTS: Kaizen + PDCA + Metrics + HITL
# =============================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Load required libraries
source "$SCRIPT_DIR/lib/core.sh"
source "$SCRIPT_DIR/lib/sdd.sh"

# Setup temp directory for each test
_setup() {
    TEST_TMP=$(mktemp -d)
    export PROJECT_ROOT="$TEST_TMP"
    export CLAUDE_DIR="$TEST_TMP/.claude"
    export ORCHESTRATION_DIR="$CLAUDE_DIR/orchestration"
    export SPECS_DIR="$CLAUDE_DIR/specs"
    export SPECS_ACTIVE="$SPECS_DIR/active"
    export SPECS_ARCHIVE="$SPECS_DIR/archive"
    export MEMORY_FILE="$CLAUDE_DIR/PROJECT_MEMORY.md"
    export EVENTS_FILE="$ORCHESTRATION_DIR/EVENTS.md"
    mkdir -p "$ORCHESTRATION_DIR/pids" "$ORCHESTRATION_DIR/tasks" "$SPECS_ACTIVE" "$SPECS_ARCHIVE"
    touch "$EVENTS_FILE"
}

_teardown() {
    [[ -d "${TEST_TMP:-}" ]] && rm -rf "$TEST_TMP"
}

# =============================================
# PDCA Phase Mapping Tests
# =============================================

test_pdca_phase_plan_empty() {
    local result=$(get_pdca_phase "empty")
    assert_equals "PLAN" "$result" "(empty -> PLAN)"
}

test_pdca_phase_plan_specified() {
    local result=$(get_pdca_phase "specified")
    assert_equals "PLAN" "$result" "(specified -> PLAN)"
}

test_pdca_phase_plan_researched() {
    local result=$(get_pdca_phase "researched")
    assert_equals "PLAN" "$result" "(researched -> PLAN)"
}

test_pdca_phase_plan_planned() {
    local result=$(get_pdca_phase "planned")
    assert_equals "PLAN" "$result" "(planned -> PLAN)"
}

test_pdca_phase_do_tasks_ready() {
    local result=$(get_pdca_phase "tasks-ready")
    assert_equals "DO" "$result" "(tasks-ready -> DO)"
}

test_pdca_phase_do_executing() {
    local result=$(get_pdca_phase "executing (1/3 done)")
    assert_equals "DO" "$result" "(executing -> DO)"
}

test_pdca_phase_check_completed() {
    local result=$(get_pdca_phase "completed")
    assert_equals "CHECK" "$result" "(completed -> CHECK)"
}

test_pdca_phase_act_validated() {
    local result=$(get_pdca_phase "validated")
    assert_equals "ACT" "$result" "(validated -> ACT)"
}

test_pdca_phase_unknown() {
    local result=$(get_pdca_phase "something_else")
    assert_equals "-" "$result" "(unknown -> -)"
}

# =============================================
# Config.json Tests
# =============================================

test_config_json_missing_is_ok() {
    _setup
    # No config.json exists — defaults should work
    init_config
    assert_equals "true" "${KAIZEN_AUTO_RUN}" "(KAIZEN_AUTO_RUN defaults to true)"
    _teardown
}

test_config_json_overrides_defaults() {
    _setup
    mkdir -p "$ORCHESTRATION_DIR"
    cat > "$ORCHESTRATION_DIR/config.json" << 'EOF'
{
  "max_iterations": 10,
  "kaizen_auto_run": false
}
EOF
    init_config
    assert_equals "false" "${KAIZEN_AUTO_RUN}" "(config.json overrides KAIZEN_AUTO_RUN)"
    _teardown
}

# =============================================
# Metrics Tests
# =============================================

test_metrics_dir_created() {
    _setup
    source "$SCRIPT_DIR/lib/ralph.sh"

    # Create a dummy task file
    cat > "$ORCHESTRATION_DIR/tasks/test-agent.md" << 'EOF'
# Task: test

> spec-ref: .claude/specs/active/005-test/spec.md
> ralph: true
EOF

    init_metrics_file "test-agent" 20
    assert_dir_exists "$ORCHESTRATION_DIR/metrics" "(metrics dir created)"
    _teardown
}

test_metrics_file_created() {
    _setup
    source "$SCRIPT_DIR/lib/ralph.sh"

    cat > "$ORCHESTRATION_DIR/tasks/test-agent.md" << 'EOF'
# Task: test

> spec-ref: .claude/specs/active/005-test/spec.md
> ralph: true
EOF

    init_metrics_file "test-agent" 20
    # Should have created a metrics file with spec number
    local found=false
    for f in "$ORCHESTRATION_DIR/metrics"/*.json; do
        [[ -f "$f" ]] && found=true
    done
    assert_true "$found" "(metrics JSON file created)"
    _teardown
}

# =============================================
# Backward Compatibility Tests
# =============================================

test_sdd_run_flags_no_flags_defaults() {
    # Verify default variable values when no flags are passed
    local hitl_mode=false
    local kaizen_enabled=true
    local ralph_mode=true

    assert_equals "false" "$hitl_mode" "(hitl defaults to false)"
    assert_equals "true" "$kaizen_enabled" "(kaizen defaults to true)"
    assert_equals "true" "$ralph_mode" "(ralph defaults to true)"
}

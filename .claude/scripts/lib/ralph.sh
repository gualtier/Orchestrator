#!/bin/bash
# =============================================
# RALPH - Iterative Self-Correcting Loop Engine
# Inspired by ghuntley.com/ralph
# =============================================

# Defaults
RALPH_DEFAULT_MAX_ITERATIONS=20
RALPH_DEFAULT_STALL_THRESHOLD=3
RALPH_DEFAULT_COMPLETION_SIGNAL="RALPH_COMPLETE"
RALPH_LOG_TAIL_LINES=100
RALPH_GATE_OUTPUT_LINES=50
RALPH_PID_POLL_INTERVAL=5

# =============================================
# CONFIGURATION PARSING
# =============================================

# Parse ralph-related frontmatter from a task file
# Reads > key: value lines at the top of the task file
# Sets: RALPH_ENABLED, RALPH_MAX_ITERATIONS, RALPH_STALL_THRESHOLD,
#        RALPH_GATES (newline-separated), RALPH_COMPLETION_SIGNAL
parse_ralph_config() {
    local task_file=$1
    local global_ralph=${2:-false}

    # Defaults
    RALPH_ENABLED="$global_ralph"
    RALPH_MAX_ITERATIONS=$RALPH_DEFAULT_MAX_ITERATIONS
    RALPH_STALL_THRESHOLD=$RALPH_DEFAULT_STALL_THRESHOLD
    RALPH_GATES=""
    RALPH_COMPLETION_SIGNAL=$RALPH_DEFAULT_COMPLETION_SIGNAL

    if [[ ! -f "$task_file" ]]; then
        return 0
    fi

    # Parse frontmatter lines (> key: value)
    # Task files have: # Title, blank line, then > key: value lines
    # We scan ALL lines that start with > anywhere in the file header
    local found_frontmatter=false
    while IFS= read -r line; do
        # Skip blank lines and title lines before/between frontmatter
        if [[ -z "$line" ]] || [[ "$line" =~ ^'#' ]]; then
            # If we already found frontmatter and hit a non-frontmatter line, stop
            if [[ "$found_frontmatter" == "true" ]] && [[ -n "$line" ]] && [[ ! "$line" =~ ^'>' ]]; then
                break
            fi
            continue
        fi

        # Only process > key: value lines
        if [[ ! "$line" =~ ^'>' ]]; then
            break
        fi

        found_frontmatter=true

        # Extract key-value pairs
        local kv="${line#> }"
        local key="${kv%%:*}"
        local value="${kv#*: }"
        # Handle keys with empty values (e.g., "> gates:")
        if [[ "$key" == "$kv" ]] || [[ "$value" == "$kv" ]]; then
            value=""
        fi
        value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        case "$key" in
            ralph)
                if [[ "$value" == "true" ]]; then
                    RALPH_ENABLED=true
                elif [[ "$value" == "false" ]]; then
                    RALPH_ENABLED=false
                fi
                ;;
            max-iterations)
                if [[ "$value" =~ ^[0-9]+$ ]]; then
                    RALPH_MAX_ITERATIONS=$value
                fi
                ;;
            stall-threshold)
                if [[ "$value" =~ ^[0-9]+$ ]]; then
                    RALPH_STALL_THRESHOLD=$value
                fi
                ;;
            completion-signal)
                if [[ -n "$value" ]]; then
                    RALPH_COMPLETION_SIGNAL="$value"
                fi
                ;;
            gates)
                # Parse comma-separated or JSON-like list: ["cmd1", "cmd2"] or cmd1, cmd2
                if [[ -n "$value" ]]; then
                    value=$(echo "$value" | sed 's/^\[//;s/\]$//;s/"//g')
                    RALPH_GATES=$(echo "$value" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -v '^$')
                fi
                ;;
        esac
    done < "$task_file"
}

# Save parsed ralph config to a state file for monitoring
save_ralph_config() {
    local name=$1
    local config_file="$ORCHESTRATION_DIR/pids/$name.ralph_config"

    ensure_dir "$ORCHESTRATION_DIR/pids"
    cat > "$config_file" << EOF
max_iterations=$RALPH_MAX_ITERATIONS
stall_threshold=$RALPH_STALL_THRESHOLD
completion_signal=$RALPH_COMPLETION_SIGNAL
gates=$(echo "$RALPH_GATES" | tr '\n' ',' | sed 's/,$//')
EOF
}

# =============================================
# COMPLETION SIGNAL DETECTION
# =============================================

# Check if the agent's log contains the completion signal
# Returns 0 if signal found, 1 otherwise
check_completion_signal() {
    local name=$1
    local signal=${2:-$RALPH_DEFAULT_COMPLETION_SIGNAL}
    local logfile=$(get_log_file "$name")

    if [[ ! -f "$logfile" ]]; then
        return 1
    fi

    # Search last N lines of log for the signal
    if tail -n "$RALPH_LOG_TAIL_LINES" "$logfile" 2>/dev/null | grep -qF "$signal"; then
        return 0
    fi

    return 1
}

# Check if agent created DONE.md (alternative completion signal)
check_done_md() {
    local worktree_path=$1

    if [[ -f "$worktree_path/DONE.md" ]]; then
        return 0
    fi
    return 1
}

# =============================================
# TDD — AUTO-DETECT TEST RUNNER
# =============================================

# Detect the test runner in a worktree directory
# Returns the test command via stdout, empty if none found
detect_test_runner() {
    local worktree_path=$1

    # Node.js — package.json with "test" script
    if [[ -f "$worktree_path/package.json" ]]; then
        if grep -q '"test"' "$worktree_path/package.json" 2>/dev/null; then
            # Check for common runners
            if [[ -f "$worktree_path/node_modules/.bin/vitest" ]]; then
                echo "npx vitest run"
            elif [[ -f "$worktree_path/node_modules/.bin/jest" ]]; then
                echo "npx jest"
            else
                echo "npm test"
            fi
            return
        fi
    fi

    # Python — pytest / unittest
    if [[ -f "$worktree_path/pytest.ini" ]] || [[ -f "$worktree_path/pyproject.toml" ]] || \
       [[ -f "$worktree_path/setup.cfg" ]]; then
        if grep -q "pytest" "$worktree_path/pyproject.toml" 2>/dev/null || \
           [[ -f "$worktree_path/pytest.ini" ]]; then
            echo "python -m pytest"
            return
        fi
    fi
    if [[ -d "$worktree_path/tests" ]] && ls "$worktree_path/tests"/test_*.py 1>/dev/null 2>&1; then
        echo "python -m pytest"
        return
    fi

    # Go
    if [[ -f "$worktree_path/go.mod" ]]; then
        echo "go test ./..."
        return
    fi

    # Rust
    if [[ -f "$worktree_path/Cargo.toml" ]]; then
        echo "cargo test"
        return
    fi

    # Makefile with test target
    if [[ -f "$worktree_path/Makefile" ]]; then
        if grep -q "^test:" "$worktree_path/Makefile" 2>/dev/null; then
            echo "make test"
            return
        fi
    fi

    # Bash tests in .claude/scripts/tests/
    if [[ -f "$worktree_path/.claude/scripts/tests/test_runner.sh" ]]; then
        echo "bash .claude/scripts/tests/test_runner.sh"
        return
    fi

    # Nothing found
    echo ""
}

# =============================================
# BACKPRESSURE GATES
# =============================================

# Run all configured gate commands in the worktree directory
# Returns 0 if all gates pass, 1 if any fail
# Sets RALPH_GATE_RESULTS with results for feedback
run_gates() {
    local name=$1
    local worktree_path=$2
    local gates=$3  # newline-separated gate commands
    local gates_file="$ORCHESTRATION_DIR/pids/$name.gates"

    # TDD integration: auto-detect test runner as default gate when none configured
    if [[ -z "$gates" ]]; then
        local detected_runner
        detected_runner=$(detect_test_runner "$worktree_path")
        if [[ -n "$detected_runner" ]]; then
            gates="$detected_runner"
            log_info "  TDD auto-gate: $detected_runner"
        else
            # No gates and no test runner detected
            echo "NO_GATES" > "$gates_file"
            RALPH_GATE_RESULTS=""
            return 0
        fi
    fi

    local total=0
    local passed=0
    local failed_output=""
    local results=""

    while IFS= read -r gate_cmd; do
        [[ -z "$gate_cmd" ]] && continue
        ((total++)) || true

        log_info "  Gate [$total]: $gate_cmd"

        # Run gate command in worktree directory, capture output
        local gate_output gate_exit
        gate_output=$(cd "$worktree_path" && eval "$gate_cmd" 2>&1)
        gate_exit=$?

        if [[ $gate_exit -eq 0 ]]; then
            ((passed++)) || true
            results+="PASS:$gate_cmd\n"
            log_success "  Gate [$total]: PASS"
        else
            results+="FAIL:$gate_cmd\n"
            # Capture last N lines of output for feedback
            local truncated_output
            truncated_output=$(echo "$gate_output" | tail -n "$RALPH_GATE_OUTPUT_LINES")
            failed_output+="
--- GATE FAILED: $gate_cmd ---
$truncated_output
--- END GATE ---
"
            log_error "  Gate [$total]: FAIL"
        fi
    done <<< "$gates"

    # Write gate results file (REQ-17)
    echo -e "$results" > "$gates_file"
    echo "passed=$passed" >> "$gates_file"
    echo "total=$total" >> "$gates_file"

    # Save gate feedback for next iteration
    RALPH_GATE_RESULTS="$failed_output"

    if [[ $passed -eq $total ]]; then
        log_success "  All gates passed ($passed/$total)"
        return 0
    else
        log_warn "  Gates: $passed/$total passed"
        return 1
    fi
}

# =============================================
# CONVERGENCE DETECTION
# =============================================

# Check if the agent is making progress by looking at git diff
# Returns 0 if converging (has changes), 1 if stalled (no changes)
check_convergence() {
    local worktree_path=$1
    local stall_file=$2  # file tracking consecutive stall count

    if [[ ! -d "$worktree_path" ]]; then
        return 1
    fi

    # Check for new commits since last convergence check
    # We track the last-seen commit hash to detect if new commits were made
    local last_hash_file="${stall_file}.last_hash"
    local current_hash
    current_hash=$(cd "$worktree_path" && git rev-parse HEAD 2>/dev/null || echo "")
    local last_hash=""
    if [[ -f "$last_hash_file" ]]; then
        last_hash=$(cat "$last_hash_file" 2>/dev/null || echo "")
    fi
    echo "$current_hash" > "$last_hash_file"

    # Also check uncommitted changes as secondary signal
    local diff_stat
    diff_stat=$(cd "$worktree_path" && git diff --stat HEAD 2>/dev/null || echo "")
    local staged_stat
    staged_stat=$(cd "$worktree_path" && git diff --cached --stat 2>/dev/null || echo "")

    if [[ "$current_hash" == "$last_hash" ]] && [[ -z "$diff_stat" ]] && [[ -z "$staged_stat" ]]; then
        # No changes — increment stall counter
        local stall_count=0
        if [[ -f "$stall_file" ]]; then
            stall_count=$(cat "$stall_file" 2>/dev/null || echo "0")
        fi
        ((stall_count++)) || true
        echo "$stall_count" > "$stall_file"
        return 1  # stalled
    else
        # Has changes — reset stall counter
        echo "0" > "$stall_file"
        return 0  # converging
    fi
}

# =============================================
# ITERATION CONTEXT
# =============================================

# Build iteration context to append to the prompt for iterations 2+
write_iteration_context() {
    local name=$1
    local worktree_path=$2
    local iteration=$3
    local max_iterations=$4
    local gate_feedback=$5
    local completion_signal=$6

    local context="

=== RALPH LOOP: ITERATION $iteration/$max_iterations ===

You are in a self-correcting loop (iteration $iteration of $max_iterations).
Your previous iteration's work is already committed to this worktree.

## What Changed Last Iteration
$(cd "$worktree_path" && git diff --stat HEAD~1 2>/dev/null || echo "No previous commits to diff against")

## Current Git Status
$(cd "$worktree_path" && git status --short 2>/dev/null || echo "Clean")
"

    # Add gate feedback if any gates failed
    if [[ -n "$gate_feedback" ]]; then
        context+="
## Gate Failures (MUST FIX)
The following quality gates failed. You MUST fix these issues before your work is accepted:
$gate_feedback
"
    fi

    context+="
## Instructions
1. Review the gate failures above (if any) and fix the issues
2. Review your previous work and improve it
3. Update PROGRESS.md with your current progress
4. When ALL requirements are met and ALL gates would pass, output: $completion_signal
5. If you cannot make further progress, explain why in BLOCKED.md

DO NOT output $completion_signal until you are confident all requirements are satisfied.
"

    echo "$context"
}

# =============================================
# RALPH LOOP (Main Engine)
# =============================================

# Run an agent in iterative ralph mode
# This wraps start_agent_process() in a while-loop
ralph_loop() {
    local name=$1
    local worktree_path=$2
    local base_prompt=$3
    local max_iterations=${4:-$RALPH_DEFAULT_MAX_ITERATIONS}
    local stall_threshold=${5:-$RALPH_DEFAULT_STALL_THRESHOLD}
    local gates=$6  # newline-separated gate commands
    local completion_signal=${7:-$RALPH_DEFAULT_COMPLETION_SIGNAL}

    local iteration=1
    local iteration_file="$ORCHESTRATION_DIR/pids/$name.iteration"
    local stall_file="$ORCHESTRATION_DIR/pids/$name.stall_count"
    local logfile=$(get_log_file "$name")
    local ralph_loop_pid_file="$ORCHESTRATION_DIR/pids/$name.ralph_pid"

    # Store the ralph loop PID for cancel-ralph
    echo $$ > "$ralph_loop_pid_file"

    # Initialize state files
    ensure_dir "$ORCHESTRATION_DIR/pids"
    echo "0" > "$iteration_file"
    echo "0" > "$stall_file"

    log_step "Ralph loop starting for $name (max: $max_iterations iterations)"
    echo "[$(timestamp)] RALPH_START: $name [max_iter=$max_iterations, stall=$stall_threshold]" >> "$EVENTS_FILE"

    local gate_feedback=""

    while [[ $iteration -le $max_iterations ]]; do
        # Update iteration tracking (REQ-16)
        echo "$iteration" > "$iteration_file"

        # Log iteration boundary in the agent's log file (NF-4)
        echo "" >> "$logfile" 2>/dev/null || true
        echo "=== RALPH ITERATION $iteration/$max_iterations ===" >> "$logfile" 2>/dev/null || true
        echo "" >> "$logfile" 2>/dev/null || true

        # Log event (REQ-19)
        echo "[$(timestamp)] RALPH_ITER_START: $name [iter=$iteration/$max_iterations]" >> "$EVENTS_FILE"

        log_info "Ralph iteration $iteration/$max_iterations for $name"

        # Build the prompt for this iteration
        local iter_prompt="$base_prompt"

        if [[ $iteration -gt 1 ]]; then
            # Append iteration context (REQ-4)
            local context
            context=$(write_iteration_context "$name" "$worktree_path" "$iteration" "$max_iterations" "$gate_feedback" "$completion_signal")
            iter_prompt+="$context"
        else
            # First iteration: add completion signal instruction (REQ-21)
            iter_prompt+="

## Ralph Loop Mode
You are running in ralph loop mode. When you have completed ALL requirements and are confident your work passes all quality checks, output the following signal on its own line:

$completion_signal

This signal tells the loop engine to run quality gates. If gates pass, you're done. If gates fail, you'll get another iteration with feedback.

You MUST also create DONE.md as the final step.
"
        fi

        # Start the agent process (reuse existing function unchanged)
        start_agent_process "$name" "$worktree_path" "$iter_prompt"

        # Wait for the process to exit (simple PID polling)
        local pidfile=$(get_pid_file "$name")
        while is_process_running "$name"; do
            sleep $RALPH_PID_POLL_INTERVAL
        done

        # Log iteration end
        echo "[$(timestamp)] RALPH_ITER_END: $name [iter=$iteration]" >> "$EVENTS_FILE"

        # Check for completion signals
        local signal_found=false
        local done_md_found=false

        if check_completion_signal "$name" "$completion_signal"; then
            signal_found=true
            log_info "Completion signal found for $name"
        fi

        if check_done_md "$worktree_path"; then
            done_md_found=true
            log_info "DONE.md found for $name"
        fi

        # Determine if we should run gates
        local should_run_gates=false
        if [[ "$signal_found" == "true" ]]; then
            should_run_gates=true
        fi
        # REQ-10: Gates also run when DONE.md exists (catches bypass)
        if [[ "$done_md_found" == "true" ]]; then
            should_run_gates=true
        fi

        if [[ "$should_run_gates" == "true" ]]; then
            log_info "Running backpressure gates for $name..."

            if run_gates "$name" "$worktree_path" "$gates"; then
                # All gates passed — agent is done
                echo "[$(timestamp)] RALPH_COMPLETE: $name [iter=$iteration, gates=PASS]" >> "$EVENTS_FILE"
                log_success "Ralph loop completed for $name after $iteration iteration(s)"

                # Clean up ralph-specific state files
                rm -f "$ralph_loop_pid_file" "$stall_file" "$iteration_file"
                rm -f "$ORCHESTRATION_DIR/pids/$name.ralph_config"
                rm -f "$ORCHESTRATION_DIR/pids/$name.stall_count.last_hash"
                return 0
            else
                # Gates failed — continue loop with feedback
                gate_feedback="$RALPH_GATE_RESULTS"
                echo "[$(timestamp)] RALPH_GATE_FAIL: $name [iter=$iteration]" >> "$EVENTS_FILE"
                log_warn "Gates failed for $name, continuing to iteration $((iteration + 1))..."

                # Remove DONE.md so the agent knows it needs to try again
                if [[ -f "$worktree_path/DONE.md" ]]; then
                    rm -f "$worktree_path/DONE.md"
                fi
            fi
        else
            # No completion signal and no DONE.md — check convergence (REQ-5)
            if ! check_convergence "$worktree_path" "$stall_file"; then
                local stall_count
                stall_count=$(cat "$stall_file" 2>/dev/null || echo "0")

                if [[ $stall_count -ge $stall_threshold ]]; then
                    # Stalled — create BLOCKED.md and stop
                    log_warn "Convergence stall detected for $name ($stall_count consecutive iterations with no changes)"
                    echo "[$(timestamp)] RALPH_STALL: $name [iter=$iteration, stall=$stall_count]" >> "$EVENTS_FILE"

                    cat > "$worktree_path/BLOCKED.md" << STALLEOF
# BLOCKED: $name (Convergence Stall)

Agent stalled after $iteration iterations with no meaningful file changes
for $stall_count consecutive iterations.

## Iteration History
- Total iterations: $iteration/$max_iterations
- Stall threshold: $stall_threshold
- Consecutive empty iterations: $stall_count

## Last Log Lines
$(tail -20 "$logfile" 2>/dev/null || echo "No log available")

## Timestamp
$(date '+%Y-%m-%d %H:%M:%S')
STALLEOF
                    log_info "Created BLOCKED.md for $name (stall)"

                    # Clean up
                    rm -f "$ralph_loop_pid_file" "$stall_file" "$iteration_file"
                    rm -f "$ORCHESTRATION_DIR/pids/$name.ralph_config"
                    rm -f "$ORCHESTRATION_DIR/pids/$name.stall_count.last_hash"
                    return 1
                fi
            fi

            # Reset gate feedback since no gates ran
            gate_feedback=""
        fi

        ((iteration++)) || true
    done

    # Max iterations reached (REQ-3)
    log_warn "Max iterations ($max_iterations) reached for $name"
    echo "[$(timestamp)] RALPH_MAX_ITER: $name [max=$max_iterations]" >> "$EVENTS_FILE"

    cat > "$worktree_path/BLOCKED.md" << MAXEOF
# BLOCKED: $name (Max Iterations Reached)

Agent did not complete within $max_iterations iterations.

## Iteration History
- Total iterations: $max_iterations
- Completion signal found: $(check_completion_signal "$name" "$completion_signal" && echo "yes" || echo "no")
- DONE.md exists: $(check_done_md "$worktree_path" && echo "yes" || echo "no")

## Last Gate Results
$(cat "$ORCHESTRATION_DIR/pids/$name.gates" 2>/dev/null || echo "No gate results")

## Last Log Lines
$(tail -20 "$logfile" 2>/dev/null || echo "No log available")

## Timestamp
$(date '+%Y-%m-%d %H:%M:%S')
MAXEOF
    log_info "Created BLOCKED.md for $name (max iterations)"

    # Clean up
    rm -f "$ralph_loop_pid_file" "$stall_file" "$iteration_file"
    rm -f "$ORCHESTRATION_DIR/pids/$name.ralph_config"
    rm -f "$ORCHESTRATION_DIR/pids/$name.stall_count.last_hash"
    return 1
}

# =============================================
# CANCEL RALPH
# =============================================

# Cancel a running ralph loop for a specific agent or all agents
cmd_cancel_ralph() {
    local name=${1:-""}

    if [[ -z "$name" ]]; then
        # Cancel all ralph loops
        log_step "Cancelling all ralph loops..."
        local cancelled=0

        for ralph_pid_file in "$ORCHESTRATION_DIR/pids"/*.ralph_pid; do
            [[ -f "$ralph_pid_file" ]] || continue
            local agent_name=$(basename "$ralph_pid_file" .ralph_pid)
            _cancel_single_ralph "$agent_name"
            ((cancelled++)) || true
        done

        if [[ $cancelled -eq 0 ]]; then
            log_info "No ralph loops are running"
        else
            log_success "Cancelled $cancelled ralph loop(s)"
        fi
    else
        # Cancel specific agent
        _cancel_single_ralph "$name"
    fi
}

_cancel_single_ralph() {
    local name=$1
    local ralph_pid_file="$ORCHESTRATION_DIR/pids/$name.ralph_pid"

    if [[ ! -f "$ralph_pid_file" ]]; then
        log_warn "No ralph loop found for $name"
        return 0
    fi

    local ralph_pid
    ralph_pid=$(cat "$ralph_pid_file" 2>/dev/null || echo "")

    # Stop the current agent process first
    if is_process_running "$name"; then
        log_info "Stopping current iteration for $name..."
        stop_agent_process "$name" false
    fi

    # Kill the ralph loop shell if it's still running
    if [[ -n "$ralph_pid" ]] && kill -0 "$ralph_pid" 2>/dev/null; then
        log_info "Stopping ralph loop for $name (PID: $ralph_pid)..."
        kill "$ralph_pid" 2>/dev/null || true
    fi

    # Clean up state files
    rm -f "$ralph_pid_file"
    rm -f "$ORCHESTRATION_DIR/pids/$name.stall_count"
    rm -f "$ORCHESTRATION_DIR/pids/$name.iteration"
    rm -f "$ORCHESTRATION_DIR/pids/$name.ralph_config"
    rm -f "$ORCHESTRATION_DIR/pids/$name.stall_count.last_hash"

    echo "[$(timestamp)] RALPH_CANCEL: $name" >> "$EVENTS_FILE"
    log_success "Ralph loop cancelled for $name"
}

# =============================================
# RALPH STATE QUERIES (for monitoring)
# =============================================

# Get current iteration for an agent
# Returns: iteration number or "" if not in ralph mode
get_ralph_iteration() {
    local name=$1
    local iter_file="$ORCHESTRATION_DIR/pids/$name.iteration"

    if [[ -f "$iter_file" ]]; then
        cat "$iter_file" 2>/dev/null || echo ""
    else
        echo ""
    fi
}

# Get max iterations for an agent from config
# Returns: max iterations number or "" if not in ralph mode
get_ralph_max_iterations() {
    local name=$1
    local config_file="$ORCHESTRATION_DIR/pids/$name.ralph_config"

    if [[ -f "$config_file" ]]; then
        grep "^max_iterations=" "$config_file" 2>/dev/null | cut -d= -f2
    else
        echo ""
    fi
}

# Get last gate results summary
# Returns: "passed/total" or "" if no results
get_ralph_gate_summary() {
    local name=$1
    local gates_file="$ORCHESTRATION_DIR/pids/$name.gates"

    if [[ ! -f "$gates_file" ]]; then
        echo ""
        return
    fi

    local content
    content=$(cat "$gates_file" 2>/dev/null || echo "")

    if [[ "$content" == "NO_GATES" ]]; then
        echo "no gates"
        return
    fi

    local passed
    passed=$(grep "^passed=" "$gates_file" 2>/dev/null | cut -d= -f2 || echo "0")
    local total
    total=$(grep "^total=" "$gates_file" 2>/dev/null | cut -d= -f2 || echo "0")

    if [[ -n "$passed" ]] && [[ -n "$total" ]]; then
        echo "$passed/$total"
    else
        echo ""
    fi
}

# Check if an agent is in ralph mode
is_ralph_agent() {
    local name=$1

    if [[ -f "$ORCHESTRATION_DIR/pids/$name.ralph_pid" ]] || \
       [[ -f "$ORCHESTRATION_DIR/pids/$name.iteration" ]]; then
        return 0
    fi
    return 1
}

# Get ralph convergence indicator
# Returns: "converging" | "stalled" | ""
get_ralph_convergence() {
    local name=$1
    local stall_file="$ORCHESTRATION_DIR/pids/$name.stall_count"

    if [[ ! -f "$stall_file" ]]; then
        echo ""
        return
    fi

    local stall_count
    stall_count=$(cat "$stall_file" 2>/dev/null || echo "0")

    if [[ $stall_count -gt 0 ]]; then
        echo "stalled($stall_count)"
    else
        echo "converging"
    fi
}

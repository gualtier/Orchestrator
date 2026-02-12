#!/bin/bash
# =============================================
# ERROR_DETECTION - Error monitoring for agents
# =============================================

# =============================================
# CONFIGURATION
# =============================================

# Error detection defaults (can be overridden in core.sh)
ERROR_POLL_INTERVAL=${ERROR_POLL_INTERVAL:-5}
ERROR_LOG_FILE="${ORCHESTRATION_DIR}/errors.log"
ERROR_CACHE_DIR="${ORCHESTRATION_DIR}/pids"

# Error patterns by severity (pipe-separated for grep -E)
CRITICAL_PATTERNS='panic:|FATAL|Segmentation fault|OOMKilled|ENOSPC|core dumped|killed|Cannot allocate memory'
WARNING_PATTERNS='FAIL |FAILED|Error:|error TS|TypeError|SyntaxError|ReferenceError|CONFLICT|Permission denied|EACCES|Cannot find module|AssertionError|Traceback|fatal:|error: failed to push|BLOCKED|Cannot proceed|Stuck'
INFO_PATTERNS='DeprecationWarning|deprecated|WARN |WARNING|notice:'

# =============================================
# FILE SIZE UTILITIES (Platform-agnostic)
# =============================================

# Get file size in bytes
get_file_size() {
    local file=$1
    if [[ ! -f "$file" ]]; then
        echo "0"
        return
    fi
    if [[ "$OSTYPE" == "darwin"* ]]; then
        stat -f "%z" "$file" 2>/dev/null || echo "0"
    else
        stat -c "%s" "$file" 2>/dev/null || echo "0"
    fi
}

# =============================================
# OFFSET TRACKING
# =============================================

# Get offset file path for an agent
get_offset_file() {
    local name=$1
    echo "${ERROR_CACHE_DIR}/${name}.offset"
}

# Get errors state file path for an agent
get_errors_file() {
    local name=$1
    echo "${ERROR_CACHE_DIR}/${name}.errors"
}

# Get stored offset for an agent's log
get_stored_offset() {
    local name=$1
    local offset_file=$(get_offset_file "$name")

    if [[ -f "$offset_file" ]]; then
        cat "$offset_file" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# Store offset for an agent's log
store_offset() {
    local name=$1
    local offset=$2
    local offset_file=$(get_offset_file "$name")

    ensure_dir "$(dirname "$offset_file")"
    echo "$offset" > "$offset_file"
}

# =============================================
# ERROR TRACKING INITIALIZATION
# =============================================

# Initialize error tracking for an agent
# Called when agent starts
init_error_tracking() {
    local name=$1
    local log_file=$(get_log_file "$name")
    local offset_file=$(get_offset_file "$name")
    local errors_file=$(get_errors_file "$name")

    ensure_dir "$ERROR_CACHE_DIR"

    # Initialize offset to current log size (only track new errors)
    if [[ -f "$log_file" ]]; then
        local current_size=$(get_file_size "$log_file")
        store_offset "$name" "$current_size"
    else
        store_offset "$name" "0"
    fi

    # Reset error state file
    echo "0|none|0" > "$errors_file"

    log_debug "Error tracking initialized for $name"
}

# Reset error tracking for an agent (clears offset and errors)
reset_error_tracking() {
    local name=$1
    local offset_file=$(get_offset_file "$name")
    local errors_file=$(get_errors_file "$name")

    rm -f "$offset_file" "$errors_file"
}

# =============================================
# ERROR SEVERITY CLASSIFICATION
# =============================================

# Classify a line's error severity
# Returns: CRITICAL, WARNING, INFO, or empty for no match
classify_error_severity() {
    local line="$1"

    # Check patterns in order of severity
    if echo "$line" | grep -qE "$CRITICAL_PATTERNS"; then
        echo "CRITICAL"
    elif echo "$line" | grep -qE "$WARNING_PATTERNS"; then
        echo "WARNING"
    elif echo "$line" | grep -qE "$INFO_PATTERNS"; then
        echo "INFO"
    fi
}

# =============================================
# ERROR CONTEXT EXTRACTION
# =============================================

# Extract file/line info from error message if available
extract_error_location() {
    local line="$1"

    # Common patterns: file.ts:123, file.py line 45, at file.js:99:15
    local location=""

    # TypeScript/JavaScript: file.ts:123 or file.js:123:45
    location=$(echo "$line" | grep -oE '[a-zA-Z0-9_/.-]+\.(ts|js|tsx|jsx):[0-9]+(:[0-9]+)?' | head -1)
    [[ -n "$location" ]] && { echo "$location"; return; }

    # Python: File "path/file.py", line 123
    location=$(echo "$line" | grep -oE 'File "[^"]+", line [0-9]+' | head -1)
    [[ -n "$location" ]] && { echo "$location"; return; }

    # Go: file.go:123
    location=$(echo "$line" | grep -oE '[a-zA-Z0-9_/.-]+\.go:[0-9]+' | head -1)
    [[ -n "$location" ]] && { echo "$location"; return; }

    # Rust: file.rs:123
    location=$(echo "$line" | grep -oE '[a-zA-Z0-9_/.-]+\.rs:[0-9]+' | head -1)
    [[ -n "$location" ]] && { echo "$location"; return; }

    echo ""
}

# =============================================
# CORRECTIVE ACTION SUGGESTIONS
# =============================================

# Get suggested action for an error based on severity and pattern
suggest_corrective_action() {
    local severity=$1
    local message="$2"

    # Check for specific patterns and suggest actions
    if echo "$message" | grep -qE 'FAIL |FAILED|AssertionError'; then
        echo "Review test output, consider restarting agent"
        return
    fi

    if echo "$message" | grep -qE 'error TS|SyntaxError|Cannot find module'; then
        echo "Check syntax in file, agent may self-correct"
        return
    fi

    if echo "$message" | grep -qE 'panic:|FATAL|Segmentation fault|core dumped|killed'; then
        echo "Restart agent with: orchestrate.sh restart <name>"
        return
    fi

    if echo "$message" | grep -qE 'CONFLICT|fatal:.*merge|error: failed to push'; then
        echo "Resolve conflict manually, then restart"
        return
    fi

    if echo "$message" | grep -qE 'BLOCKED|Cannot proceed|Stuck'; then
        echo "Agent may be stuck, consider restart"
        return
    fi

    if echo "$message" | grep -qE 'Permission denied|EACCES'; then
        echo "Check file permissions in worktree"
        return
    fi

    if echo "$message" | grep -qE 'OOMKilled|Cannot allocate memory|ENOSPC'; then
        echo "System resource issue - free memory/disk space"
        return
    fi

    # Default based on severity
    case "$severity" in
        CRITICAL)
            echo "Critical error - investigate and restart agent"
            ;;
        WARNING)
            echo "Warning detected - monitor for resolution"
            ;;
        INFO)
            echo "Informational notice - no action needed"
            ;;
        *)
            echo ""
            ;;
    esac
}

# =============================================
# ERROR DETECTION CORE
# =============================================

# Check agent log for new errors since last check
# Updates offset and errors state files
# Returns 0 if errors found, 1 if no errors
check_agent_errors() {
    local name=$1
    local log_file=$(get_log_file "$name")
    local offset_file=$(get_offset_file "$name")
    local errors_file=$(get_errors_file "$name")

    # Check if log exists
    if [[ ! -f "$log_file" ]]; then
        return 1
    fi

    local current_size=$(get_file_size "$log_file")
    local stored_offset=$(get_stored_offset "$name")

    # No new content
    if [[ $current_size -le $stored_offset ]]; then
        return 1
    fi

    # Read new content using tail with byte offset
    local new_content
    new_content=$(tail -c "+$((stored_offset + 1))" "$log_file" 2>/dev/null)

    # Update stored offset
    store_offset "$name" "$current_size"

    # No new content to analyze
    if [[ -z "$new_content" ]]; then
        return 1
    fi

    local errors_found=0
    local critical_count=0
    local warning_count=0
    local info_count=0
    local last_error=""
    local last_severity=""
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Process line by line, looking for errors
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue

        local severity=$(classify_error_severity "$line")

        if [[ -n "$severity" ]]; then
            errors_found=1
            last_error="$line"
            last_severity="$severity"

            case "$severity" in
                CRITICAL) ((critical_count++)) ;;
                WARNING) ((warning_count++)) ;;
                INFO) ((info_count++)) ;;
            esac

            # Extract location and truncate message
            local location=$(extract_error_location "$line")
            local truncated_msg=$(echo "$line" | cut -c1-200)

            # Append to global error log (pipe-delimited format)
            # Format: timestamp|severity|agent|message|location
            echo "${timestamp}|${severity}|${name}|${truncated_msg}|${location}" >> "$ERROR_LOG_FILE"
        fi
    done <<< "$new_content"

    # Update errors state file
    # Format: total_count|last_error|last_severity
    local total_errors=$((critical_count + warning_count + info_count))
    local prev_state=$(cat "$errors_file" 2>/dev/null || echo "0|none|0")
    local prev_total=$(echo "$prev_state" | cut -d'|' -f1)
    local cumulative_total=$((prev_total + total_errors))

    echo "${cumulative_total}|${last_error:0:100}|${critical_count}|${warning_count}|${info_count}" > "$errors_file"

    if [[ $errors_found -eq 1 ]]; then
        return 0
    fi
    return 1
}

# Check all agents for errors
# Returns 0 if any errors found
check_all_agents_errors() {
    local any_errors=1

    for task_file in "$ORCHESTRATION_DIR/tasks"/*.md; do
        [[ -f "$task_file" ]] || continue
        local name=$(basename "$task_file" .md)

        if check_agent_errors "$name"; then
            any_errors=0
        fi
    done

    return $any_errors
}

# =============================================
# ERROR STATE ACCESSORS
# =============================================

# Get error count for an agent
get_error_count() {
    local name=$1
    local errors_file=$(get_errors_file "$name")

    if [[ -f "$errors_file" ]]; then
        cat "$errors_file" 2>/dev/null | cut -d'|' -f1 || echo "0"
    else
        echo "0"
    fi
}

# Get last error for an agent
get_last_error() {
    local name=$1
    local errors_file=$(get_errors_file "$name")

    if [[ -f "$errors_file" ]]; then
        cat "$errors_file" 2>/dev/null | cut -d'|' -f2 || echo "none"
    else
        echo "none"
    fi
}

# Get error counts by severity for an agent
# Returns: critical|warning|info
get_error_counts_by_severity() {
    local name=$1
    local errors_file=$(get_errors_file "$name")

    if [[ -f "$errors_file" ]]; then
        local state=$(cat "$errors_file" 2>/dev/null || echo "0|none|0|0|0")
        local critical=$(echo "$state" | cut -d'|' -f3 || echo "0")
        local warning=$(echo "$state" | cut -d'|' -f4 || echo "0")
        local info=$(echo "$state" | cut -d'|' -f5 || echo "0")
        echo "${critical:-0}|${warning:-0}|${info:-0}"
    else
        echo "0|0|0"
    fi
}

# Get total errors across all agents
get_total_errors() {
    local total=0

    for task_file in "$ORCHESTRATION_DIR/tasks"/*.md; do
        [[ -f "$task_file" ]] || continue
        local name=$(basename "$task_file" .md)
        local count=$(get_error_count "$name")
        total=$((total + count))
    done

    echo "$total"
}

# =============================================
# ERROR NOTIFICATION
# =============================================

# Show inline error notification
show_error_notification() {
    local name=$1
    local severity=$2
    local message="$3"
    local action=$(suggest_corrective_action "$severity" "$message")

    echo ""
    case "$severity" in
        CRITICAL)
            log_error "[$name] CRITICAL: ${message:0:80}"
            ;;
        WARNING)
            log_warn "[$name] WARNING: ${message:0:80}"
            ;;
        INFO)
            log_info "[$name] INFO: ${message:0:80}"
            ;;
    esac

    if [[ -n "$action" ]]; then
        echo -e "  ${GRAY}→ $action${NC}"
    fi
}

# Check and show new errors for all agents
# Used during wait/watch modes
check_and_notify_errors() {
    for task_file in "$ORCHESTRATION_DIR/tasks"/*.md; do
        [[ -f "$task_file" ]] || continue
        local name=$(basename "$task_file" .md)
        local errors_file=$(get_errors_file "$name")

        # Get previous error count
        local prev_count=0
        if [[ -f "${errors_file}.prev" ]]; then
            prev_count=$(cat "${errors_file}.prev" 2>/dev/null || echo "0")
        fi

        # Check for new errors
        if check_agent_errors "$name"; then
            local current_count=$(get_error_count "$name")

            if [[ $current_count -gt $prev_count ]]; then
                local last_error=$(get_last_error "$name")
                local severity_counts=$(get_error_counts_by_severity "$name")
                local critical=$(echo "$severity_counts" | cut -d'|' -f1)

                # Determine display severity
                local display_severity="WARNING"
                [[ $critical -gt 0 ]] && display_severity="CRITICAL"

                show_error_notification "$name" "$display_severity" "$last_error"
            fi

            # Store current count for next comparison
            echo "$current_count" > "${errors_file}.prev"
        fi
    done
}

# =============================================
# ERROR LOG MANAGEMENT
# =============================================

# Get recent errors from the global error log
# Args: count (default 10), agent filter (optional)
get_recent_errors() {
    local count=${1:-10}
    local agent_filter=${2:-}

    if [[ ! -f "$ERROR_LOG_FILE" ]]; then
        return 1
    fi

    if [[ -n "$agent_filter" ]]; then
        grep "|${agent_filter}|" "$ERROR_LOG_FILE" | tail -n "$count"
    else
        tail -n "$count" "$ERROR_LOG_FILE"
    fi
}

# Clear the global error log
clear_error_log() {
    if [[ -f "$ERROR_LOG_FILE" ]]; then
        > "$ERROR_LOG_FILE"
        log_info "Error log cleared"
    fi
}

# Rotate error log if too large (>5MB)
rotate_error_log() {
    local max_size=${1:-5242880}  # 5MB default

    if [[ ! -f "$ERROR_LOG_FILE" ]]; then
        return
    fi

    local size=$(get_file_size "$ERROR_LOG_FILE")
    if [[ $size -gt $max_size ]]; then
        local backup="${ERROR_LOG_FILE}.1"
        mv "$ERROR_LOG_FILE" "$backup"
        touch "$ERROR_LOG_FILE"
        log_info "Error log rotated"
    fi
}

# =============================================
# DASHBOARD HELPERS
# =============================================

# Get summary of all errors by severity
# Returns: total|critical|warning|info
get_error_summary() {
    local total_critical=0
    local total_warning=0
    local total_info=0

    for task_file in "$ORCHESTRATION_DIR/tasks"/*.md; do
        [[ -f "$task_file" ]] || continue
        local name=$(basename "$task_file" .md)
        local counts=$(get_error_counts_by_severity "$name")
        local critical=$(echo "$counts" | cut -d'|' -f1)
        local warning=$(echo "$counts" | cut -d'|' -f2)
        local info=$(echo "$counts" | cut -d'|' -f3)

        total_critical=$((total_critical + ${critical:-0}))
        total_warning=$((total_warning + ${warning:-0}))
        total_info=$((total_info + ${info:-0}))
    done

    local total=$((total_critical + total_warning + total_info))
    echo "${total}|${total_critical}|${total_warning}|${total_info}"
}

# Get errors per agent as formatted lines
# Returns lines of: agent|count|critical|warning|info|last_error
get_errors_per_agent() {
    for task_file in "$ORCHESTRATION_DIR/tasks"/*.md; do
        [[ -f "$task_file" ]] || continue
        local name=$(basename "$task_file" .md)
        local count=$(get_error_count "$name")
        local counts=$(get_error_counts_by_severity "$name")
        local last=$(get_last_error "$name")

        echo "${name}|${count}|${counts}|${last:0:60}"
    done
}

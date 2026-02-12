#!/bin/bash
# =============================================
# MONITORING - Enhanced monitoring utilities
# =============================================

# Cache configuration
ACTIVITY_CACHE_DIR="/tmp/orch-monitor-cache"
ACTIVITY_CACHE_TTL=10

# =============================================
# VISUAL RENDERING
# =============================================

# Render ASCII progress bar
# Usage: render_progress_bar 75 40
# Output: [██████████████████████████████░░░░░░░░░░] 75%
render_progress_bar() {
    local percent=$1
    local width=${2:-40}

    # Ensure percent is between 0 and 100
    [[ $percent -lt 0 ]] && percent=0
    [[ $percent -gt 100 ]] && percent=100

    local filled=$((percent * width / 100))
    local empty=$((width - filled))

    printf "["
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' '░'
    printf "] %3d%%" "$percent"
}

# =============================================
# TIME FORMATTING
# =============================================

# Format seconds to human readable duration
# Usage: format_duration 3725
# Output: "1h 2m 5s"
format_duration() {
    local total_secs=$1

    if [[ $total_secs -lt 60 ]]; then
        echo "${total_secs}s"
    elif [[ $total_secs -lt 3600 ]]; then
        local mins=$((total_secs / 60))
        local secs=$((total_secs % 60))
        echo "${mins}m ${secs}s"
    else
        local hours=$((total_secs / 3600))
        local mins=$(((total_secs % 3600) / 60))
        echo "${hours}h ${mins}m"
    fi
}

# Get elapsed seconds since agent start
# Returns: seconds as integer
get_elapsed_seconds() {
    local name=$1
    local start_file="$ORCHESTRATION_DIR/pids/$name.started"

    if ! file_exists "$start_file"; then
        echo "0"
        return
    fi

    local start_ts=$(cat "$start_file" 2>/dev/null || echo "0")
    local now=$(date +%s)
    echo "$((now - start_ts))"
}

# =============================================
# ACTIVITY DETECTION
# =============================================

# Get git activity summary for an agent
# Returns: "commit_count files_changed last_commit_msg"
get_agent_activity() {
    local name=$1
    local worktree_path=$(get_worktree_path "$name")

    if ! dir_exists "$worktree_path"; then
        echo "0 0 none"
        return
    fi

    # Try to get git information
    local commit_count=0
    local files_count=0
    local last_msg="none"

    # Check if it's a git repository
    if [[ -e "$worktree_path/.git" ]]; then
        # Get default branch
        local default_branch=$(cd "$PROJECT_ROOT" && git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")

        # Count commits
        commit_count=$(cd "$worktree_path" && git rev-list --count HEAD ^"$default_branch" 2>/dev/null || echo "0")

        # Count changed files
        files_count=$(cd "$worktree_path" && git diff --name-only "$default_branch" 2>/dev/null | wc -l | tr -d ' ')

        # Get last commit message
        last_msg=$(cd "$worktree_path" && git log -1 --pretty=format:"%s" 2>/dev/null | cut -c1-50 || echo "none")
    fi

    echo "$commit_count $files_count $last_msg"
}

# Get last file modification time in worktree
# Returns: timestamp (unix epoch) or "0"
get_last_activity_time() {
    local name=$1
    local worktree_path=$(get_worktree_path "$name")

    if ! dir_exists "$worktree_path"; then
        echo "0"
        return
    fi

    # Platform-specific stat command
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        find "$worktree_path" -type f -not -path "*/\.git/*" -exec stat -f "%m" {} \; 2>/dev/null | sort -rn | head -1 || echo "0"
    else
        # Linux
        find "$worktree_path" -type f -not -path "*/\.git/*" -printf "%T@\n" 2>/dev/null | sort -rn | head -1 | cut -d. -f1 || echo "0"
    fi
}

# Determine agent activity state based on recent file changes
# Returns: "active" | "idle" | "stalled" | "inactive"
get_activity_indicator() {
    local name=$1

    if ! is_process_running "$name"; then
        echo "inactive"
        return
    fi

    local last_activity=$(get_last_activity_time "$name")
    local now=$(date +%s)
    local idle_time=$((now - last_activity))

    if [[ $idle_time -lt 300 ]]; then
        echo "active"    # < 5 minutes
    elif [[ $idle_time -lt 600 ]]; then
        echo "idle"      # 5-10 minutes
    else
        echo "stalled"   # > 10 minutes
    fi
}

# =============================================
# PROGRESS INTELLIGENCE
# =============================================

# Get current task item being worked on from PROGRESS.md
# Returns: "item text" or "no active item"
get_current_task_item() {
    local name=$1
    local worktree_path=$(get_worktree_path "$name")
    local progress_file="$worktree_path/PROGRESS.md"

    if ! file_exists "$progress_file"; then
        echo "no progress file"
        return
    fi

    # Find first unchecked item after last checked item
    local in_progress=$(awk '
        /- \[x\]/ { last_done = NR; next }
        /- \[ \]/ {
            if (NR == last_done + 1 || last_done == 0) {
                sub(/^.*\] /, "")
                print
                exit
            }
        }
    ' "$progress_file" | head -1)

    if [[ -n "$in_progress" ]]; then
        echo "$in_progress" | cut -c1-60
    else
        echo "no active item"
    fi
}

# =============================================
# VELOCITY & ESTIMATES
# =============================================

# Calculate items per hour velocity
# Returns: float as string (e.g., "2.5")
calculate_velocity() {
    local name=$1
    local elapsed=$(get_elapsed_seconds "$name")

    # Too early to estimate (less than 5 minutes)
    if [[ $elapsed -lt 300 ]]; then
        echo "0.0"
        return
    fi

    local worktree_path=$(get_worktree_path "$name")
    local progress_file="$worktree_path/PROGRESS.md"

    if ! file_exists "$progress_file"; then
        echo "0.0"
        return
    fi

    local done_items=$(grep -c "\- \[x\]" "$progress_file" 2>/dev/null || echo 0)

    # No items completed yet
    if [[ $done_items -eq 0 ]]; then
        echo "0.0"
        return
    fi

    # Calculate items per hour
    # Use shell arithmetic for compatibility (no bc required)
    local hours_x100=$((elapsed * 100 / 3600))  # hours * 100
    if [[ $hours_x100 -gt 0 ]]; then
        local velocity_x10=$((done_items * 1000 / hours_x100))  # velocity * 10
        echo "$((velocity_x10 / 10)).$((velocity_x10 % 10))"
    else
        echo "0.0"
    fi
}

# Estimate remaining time in seconds
# Returns: seconds or "unknown"
estimate_remaining_time() {
    local name=$1
    local progress=$(get_agent_progress "$name")

    # Already complete or not started
    if [[ $progress -eq 0 ]] || [[ $progress -eq 100 ]]; then
        echo "0"
        return
    fi

    local velocity=$(calculate_velocity "$name")

    # Velocity too low or zero
    if [[ "${velocity%.*}" -eq 0 ]] && [[ "${velocity#*.}" -eq 0 ]]; then
        echo "unknown"
        return
    fi

    local worktree_path=$(get_worktree_path "$name")
    local progress_file="$worktree_path/PROGRESS.md"

    local done_items=$(grep -c "\- \[x\]" "$progress_file" 2>/dev/null || echo 0)
    local total_items=$(grep -c "\- \[" "$progress_file" 2>/dev/null || echo 0)
    local remaining_items=$((total_items - done_items))

    if [[ $remaining_items -le 0 ]]; then
        echo "0"
        return
    fi

    # Calculate: remaining_items / (velocity / 3600) = seconds
    # velocity is items/hour, so velocity/3600 is items/second
    # remaining_items / (velocity/3600) = remaining_items * 3600 / velocity
    local velocity_x10="${velocity/./}"  # Remove decimal point (2.5 -> 25)
    local seconds_remaining=$((remaining_items * 36000 / velocity_x10))

    echo "$seconds_remaining"
}

# =============================================
# CACHE MANAGEMENT
# =============================================

# Get file modification time (platform-agnostic)
stat_mtime() {
    local file=$1
    if [[ "$OSTYPE" == "darwin"* ]]; then
        stat -f "%m" "$file" 2>/dev/null || echo "0"
    else
        stat -c "%Y" "$file" 2>/dev/null || echo "0"
    fi
}

# Get cached git activity to avoid repeated operations
# Cache expires after 10 seconds
get_cached_activity() {
    local name=$1
    local cache_file="$ACTIVITY_CACHE_DIR/$name"

    ensure_dir "$ACTIVITY_CACHE_DIR"

    if file_exists "$cache_file"; then
        local cache_age=$(($(date +%s) - $(stat_mtime "$cache_file")))
        if [[ $cache_age -lt $ACTIVITY_CACHE_TTL ]]; then
            cat "$cache_file"
            return 0
        fi
    fi

    # Update cache
    local activity=$(get_agent_activity "$name")
    echo "$activity" > "$cache_file"
    echo "$activity"
}

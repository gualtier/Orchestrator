#!/bin/bash
# =============================================
# COMMAND: status/wait - Monitoring
# =============================================

cmd_status() {
    local mode="standard"
    local watch_interval=0

    # Parse flags
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --json)
                cmd_status_json
                return
                ;;
            --enhanced|-e)
                mode="enhanced"
                shift
                ;;
            --watch|-w)
                mode="watch"
                watch_interval=${2:-5}
                [[ "$watch_interval" =~ ^[0-9]+$ ]] && shift
                shift
                ;;
            --compact|-c)
                mode="compact"
                shift
                ;;
            *)
                shift
                ;;
        esac
    done

    case "$mode" in
        enhanced)
            cmd_status_enhanced
            ;;
        watch)
            cmd_status_watch "$watch_interval"
            ;;
        compact)
            cmd_status_compact
            ;;
        *)
            cmd_status_standard
            ;;
    esac
}

# =============================================
# STANDARD STATUS (Original)
# =============================================

cmd_status_standard() {
    log_header "ORCHESTRATOR v3.4 - STATUS - $(date '+%H:%M:%S')"

    local total=0 done=0 blocked=0 running=0 waiting=0

    for task_file in "$ORCHESTRATION_DIR/tasks"/*.md; do
        [[ -f "$task_file" ]] || continue

        local name=$(basename "$task_file" .md)
        local worktree_path=$(get_worktree_path "$name")

        ((total++))

        echo ""
        echo -e "${YELLOW}┌─── $name ───${NC}"

        # Agents
        if file_exists "$worktree_path/.claude/AGENTS_USED"; then
            local agents_used=$(cat "$worktree_path/.claude/AGENTS_USED")
            echo -e "│ Agents: ${CYAN}$agents_used${NC}"
        fi

        # Process status
        local proc_status="⚪ Stopped"
        local elapsed=""

        if is_process_running "$name"; then
            local pid=$(get_process_pid "$name")
            local runtime=$(get_process_runtime "$name")
            proc_status="${GREEN}🟢 Running (PID: $pid)${NC}"
            elapsed=" [$runtime]"
        fi
        echo -e "│ Process: $proc_status$elapsed"

        # Task status
        local status=$(get_agent_status "$name")
        case "$status" in
            done)
                echo -e "│ Task: ${GREEN}✅ COMPLETED${NC}"
                ((done++))
                ;;
            done_no_report)
                echo -e "│ Task: ${YELLOW}⚠️  COMPLETED (no DONE.md)${NC}"
                ((done++))
                ;;
            done_dirty)
                echo -e "│ Task: ${YELLOW}⚠️  COMPLETED (uncommitted changes!)${NC}"
                ((done++))
                ;;
            blocked)
                echo -e "│ Task: ${RED}🚫 BLOCKED${NC}"
                ((blocked++))
                ;;
            stopped_dirty)
                echo -e "│ Task: ${RED}⚠️  STOPPED (uncommitted changes, no commits!)${NC}"
                ((blocked++))
                ;;
            stopped)
                echo -e "│ Task: ${RED}⏹️  STOPPED (no commits)${NC}"
                ((blocked++))
                ;;
            running)
                echo -e "│ Task: ${BLUE}🔄 IN PROGRESS${NC}"
                local progress=$(get_agent_progress "$name")
                echo -e "│   Progress: ${progress}%"
                ((running++))
                ;;
            *)
                echo -e "│ Task: ${YELLOW}⏳ WAITING${NC}"
                ((waiting++))
                ;;
        esac

        # Last commit
        if dir_exists "$worktree_path"; then
            local commit=$(cd "$worktree_path" && last_commit 2>/dev/null || echo "no commits")
            echo -e "│ Commit: ${GRAY}$commit${NC}"
        fi

        # Error count (v3.5)
        local error_count=$(get_error_count "$name" 2>/dev/null || echo "0")
        if [[ ${error_count:-0} -gt 0 ]]; then
            local sev_counts=$(get_error_counts_by_severity "$name" 2>/dev/null || echo "0|0|0")
            local err_critical=$(echo "$sev_counts" | cut -d'|' -f1)
            local err_warning=$(echo "$sev_counts" | cut -d'|' -f2)
            if [[ ${err_critical:-0} -gt 0 ]]; then
                echo -e "│ Errors: ${RED}$error_count (C:$err_critical W:$err_warning)${NC}"
            else
                echo -e "│ Errors: ${YELLOW}$error_count (W:$err_warning)${NC}"
            fi
        fi

        echo -e "${YELLOW}└──────────────────────────────────────${NC}"
    done

    if [[ $total -eq 0 ]]; then
        echo ""
        echo -e "${YELLOW}No tasks found${NC}"
        return 1
    fi

    echo ""
    log_separator
    echo -e "📊 Total: $total | ✅ $done | 🔄 $running | ⏳ $waiting | 🚫 $blocked"
    log_separator

    if [[ $done -eq $total ]] && [[ $total -gt 0 ]]; then
        echo ""
        echo -e "${GREEN}🎉 ALL AGENTS COMPLETED!${NC}"
        return 0
    fi

    return 1
}

# =============================================
# ENHANCED STATUS (Rich Dashboard)
# =============================================

cmd_status_enhanced() {
    log_header "ORCHESTRATOR v3.4 - ENHANCED STATUS - $(date '+%H:%M:%S')"

    local total=0 done=0 blocked=0 running=0 waiting=0

    for task_file in "$ORCHESTRATION_DIR/tasks"/*.md; do
        [[ -f "$task_file" ]] || continue

        local name=$(basename "$task_file" .md)
        local worktree_path=$(get_worktree_path "$name")
        ((total++))

        echo ""
        echo -e "${BOLD}${YELLOW}╔═══ $name ═══${NC}"

        # Agents
        if file_exists "$worktree_path/.claude/AGENTS_USED"; then
            local agents_used=$(cat "$worktree_path/.claude/AGENTS_USED")
            echo -e "${YELLOW}║${NC} ${CYAN}Agents:${NC} $agents_used"
        fi

        # Process status with activity indicator
        local proc_status="⚪ Stopped"
        local activity_icon=""

        if is_process_running "$name"; then
            local pid=$(get_process_pid "$name")
            local elapsed=$(format_duration $(get_elapsed_seconds "$name"))
            local activity=$(get_activity_indicator "$name")

            case "$activity" in
                active)   activity_icon="${GREEN}●${NC}" ;;
                idle)     activity_icon="${YELLOW}●${NC}" ;;
                stalled)  activity_icon="${RED}●${NC}" ;;
                *)        activity_icon="${GRAY}●${NC}" ;;
            esac

            proc_status="${GREEN}🟢 Running${NC} (PID: $pid) $activity_icon [$elapsed]"
        fi
        echo -e "${YELLOW}║${NC} ${BOLD}Process:${NC} $proc_status"

        # Task status with progress bar
        local status=$(get_agent_status "$name")
        local progress=$(get_agent_progress "$name")

        case "$status" in
            done)
                echo -e "${YELLOW}║${NC} ${BOLD}Status:${NC} ${GREEN}✅ COMPLETED${NC}"
                ((done++))
                ;;
            done_no_report)
                echo -e "${YELLOW}║${NC} ${BOLD}Status:${NC} ${YELLOW}⚠️  COMPLETED (no DONE.md)${NC}"
                ((done++))
                ;;
            done_dirty)
                echo -e "${YELLOW}║${NC} ${BOLD}Status:${NC} ${YELLOW}⚠️  COMPLETED (uncommitted changes!)${NC}"
                ((done++))
                ;;
            blocked)
                echo -e "${YELLOW}║${NC} ${BOLD}Status:${NC} ${RED}🚫 BLOCKED${NC}"
                ((blocked++))
                ;;
            stopped_dirty)
                echo -e "${YELLOW}║${NC} ${BOLD}Status:${NC} ${RED}⚠️  STOPPED (uncommitted changes, no commits!)${NC}"
                ((blocked++))
                ;;
            stopped)
                echo -e "${YELLOW}║${NC} ${BOLD}Status:${NC} ${RED}⏹️  STOPPED (no commits)${NC}"
                ((blocked++))
                ;;
            running)
                echo -e "${YELLOW}║${NC} ${BOLD}Status:${NC} ${BLUE}🔄 IN PROGRESS${NC}"

                # Progress bar
                local bar=$(render_progress_bar "$progress" 30)
                echo -e "${YELLOW}║${NC}   Progress: ${CYAN}$bar${NC}"

                # Current item
                local current_item=$(get_current_task_item "$name")
                if [[ "$current_item" != "no active item" ]] && [[ "$current_item" != "no progress file" ]]; then
                    echo -e "${YELLOW}║${NC}   Working on: ${GRAY}$current_item${NC}"
                fi

                # Velocity and ETA
                local velocity=$(calculate_velocity "$name")
                local velocity_int="${velocity%.*}"
                local velocity_dec="${velocity#*.}"

                if [[ $velocity_int -gt 0 ]] || [[ $velocity_dec -gt 0 ]]; then
                    echo -e "${YELLOW}║${NC}   Velocity: ${MAGENTA}${velocity} items/hour${NC}"

                    local eta_secs=$(estimate_remaining_time "$name")
                    if [[ "$eta_secs" != "unknown" ]] && [[ $eta_secs -gt 0 ]]; then
                        local eta=$(format_duration "$eta_secs")
                        echo -e "${YELLOW}║${NC}   ETA: ${MAGENTA}~${eta}${NC}"
                    fi
                fi

                ((running++))
                ;;
            *)
                echo -e "${YELLOW}║${NC} ${BOLD}Status:${NC} ${YELLOW}⏳ WAITING${NC}"
                ((waiting++))
                ;;
        esac

        # Git activity
        if dir_exists "$worktree_path"; then
            local activity=($(get_cached_activity "$name"))
            local commits=${activity[0]:-0}
            local files=${activity[1]:-0}
            local last_commit="${activity[@]:2}"

            if [[ $commits -gt 0 ]]; then
                echo -e "${YELLOW}║${NC} ${BOLD}Activity:${NC} ${GREEN}$commits commits${NC}, ${CYAN}$files files${NC}"
                if [[ "$last_commit" != "none" ]]; then
                    echo -e "${YELLOW}║${NC}   Last: ${GRAY}$last_commit${NC}"
                fi
            else
                echo -e "${YELLOW}║${NC} ${BOLD}Activity:${NC} ${GRAY}No commits yet${NC}"
            fi
        fi

        # Error status (v3.5)
        local error_count=$(get_error_count "$name" 2>/dev/null || echo "0")
        if [[ ${error_count:-0} -gt 0 ]]; then
            local sev_counts=$(get_error_counts_by_severity "$name" 2>/dev/null || echo "0|0|0")
            local err_critical=$(echo "$sev_counts" | cut -d'|' -f1)
            local err_warning=$(echo "$sev_counts" | cut -d'|' -f2)
            local err_info=$(echo "$sev_counts" | cut -d'|' -f3)
            if [[ ${err_critical:-0} -gt 0 ]]; then
                echo -e "${YELLOW}║${NC} ${BOLD}Errors:${NC} ${RED}$error_count total${NC} (${RED}C:$err_critical${NC} ${YELLOW}W:$err_warning${NC} ${BLUE}I:$err_info${NC})"
            else
                echo -e "${YELLOW}║${NC} ${BOLD}Errors:${NC} ${YELLOW}$error_count total${NC} (${YELLOW}W:$err_warning${NC} ${BLUE}I:$err_info${NC})"
            fi
        else
            echo -e "${YELLOW}║${NC} ${BOLD}Errors:${NC} ${GREEN}None${NC}"
        fi

        echo -e "${YELLOW}╚$(printf '═%.0s' {1..60})${NC}"
    done

    if [[ $total -eq 0 ]]; then
        echo ""
        echo -e "${YELLOW}No tasks found${NC}"
        return 1
    fi

    # Summary
    echo ""
    log_separator
    echo -e "📊 ${BOLD}Summary:${NC} $total total | ${GREEN}✅ $done${NC} | ${BLUE}🔄 $running${NC} | ${YELLOW}⏳ $waiting${NC} | ${RED}🚫 $blocked${NC}"
    log_separator

    if [[ $done -eq $total ]] && [[ $total -gt 0 ]]; then
        echo ""
        echo -e "${GREEN}🎉 ALL AGENTS COMPLETED!${NC}"
        return 0
    fi

    return 1
}

# =============================================
# COMPACT STATUS (One-line per agent)
# =============================================

cmd_status_compact() {
    echo -e "${CYAN}╔═══ ORCHESTRATOR STATUS - $(date '+%H:%M:%S') ═══${NC}"

    for task_file in "$ORCHESTRATION_DIR/tasks"/*.md; do
        [[ -f "$task_file" ]] || continue

        local name=$(basename "$task_file" .md)
        local status=$(get_agent_status "$name")
        local progress=$(get_agent_progress "$name")
        local proc_icon="⚪"
        local status_icon="⏳"

        is_process_running "$name" && proc_icon="🟢"

        case "$status" in
            done)            status_icon="✅" ;;
            done_no_report)  status_icon="⚠️" ;;
            done_dirty)      status_icon="⚠️" ;;
            blocked)         status_icon="🚫" ;;
            stopped_dirty)   status_icon="⏹️" ;;
            stopped)         status_icon="⏹️" ;;
            running)         status_icon="🔄" ;;
        esac

        local bar=$(render_progress_bar "$progress" 20)

        printf "${CYAN}║${NC} %-20s %s %s %s\n" "$name" "$proc_icon" "$status_icon" "$bar"
    done

    echo -e "${CYAN}╚$(printf '═%.0s' {1..70})${NC}"
}

# =============================================
# WATCH MODE (Continuous updates)
# =============================================

cmd_status_watch() {
    local interval=${1:-5}

    trap 'echo ""; log_info "Watch stopped"; exit 0' INT TERM

    log_info "Starting watch mode (interval: ${interval}s, Ctrl+C to exit)"
    sleep 1

    while true; do
        # Clear screen
        clear

        # Check for new errors and show notifications (REQ-7)
        check_and_notify_errors 2>/dev/null || true

        # Show enhanced status
        cmd_status_enhanced

        # Check if all done
        if [[ $? -eq 0 ]]; then
            echo ""
            log_success "All agents completed! Exiting watch mode."
            break
        fi

        # Wait
        sleep "$interval"
    done
}

# =============================================
# JSON STATUS (Unchanged)
# =============================================

cmd_status_json() {
    echo "{"
    echo "  \"timestamp\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\","
    echo "  \"worktrees\": ["

    local first=true
    for task_file in "$ORCHESTRATION_DIR/tasks"/*.md; do
        [[ -f "$task_file" ]] || continue

        local name=$(basename "$task_file" .md)
        local worktree_path=$(get_worktree_path "$name")
        local status=$(get_agent_status "$name")
        local progress=$(get_agent_progress "$name")
        local agents=""

        if file_exists "$worktree_path/.claude/AGENTS_USED"; then
            agents=$(cat "$worktree_path/.claude/AGENTS_USED" | tr ' ' ',')
        fi

        local process_running="false"
        is_process_running "$name" && process_running="true"

        $first || echo ","
        first=false

        echo "    {"
        echo "      \"name\": \"$name\","
        echo "      \"status\": \"$status\","
        echo "      \"progress\": $progress,"
        echo "      \"process_running\": $process_running,"
        echo "      \"agents\": \"$agents\""
        echo -n "    }"
    done

    echo ""
    echo "  ],"

    # Summary
    local total=0 done=0 running=0 blocked=0
    for task_file in "$ORCHESTRATION_DIR/tasks"/*.md; do
        [[ -f "$task_file" ]] || continue
        ((total++))
        local name=$(basename "$task_file" .md)
        local status=$(get_agent_status "$name")
        case "$status" in
            done|done_no_report|done_dirty) ((done++)) ;;
            running) ((running++)) ;;
            blocked|stopped|stopped_dirty) ((blocked++)) ;;
        esac
    done

    echo "  \"summary\": {"
    echo "    \"total\": $total,"
    echo "    \"done\": $done,"
    echo "    \"running\": $running,"
    echo "    \"blocked\": $blocked,"
    echo "    \"pending\": $((total - done - running - blocked))"
    echo "  }"
    echo "}"
}

# =============================================
# WAIT COMMAND (Enhanced)
# =============================================

cmd_wait() {
    local interval=${1:-10}
    local use_watch=${2:-true}

    log_info "Waiting for agents to complete..."

    if [[ "$use_watch" == "true" ]]; then
        # Use watch mode for better UX
        cmd_status_watch "$interval"
    else
        # Simple polling (backward compatible)
        log_info "Polling interval: ${interval}s (Ctrl+C to exit)"

        while true; do
            # Check for new errors and show notifications inline (REQ-7)
            check_and_notify_errors 2>/dev/null || true

            if cmd_status > /dev/null 2>&1; then
                log_success "All agents completed!"
                return 0
            fi

            echo ""
            log_info "Next check in ${interval}s..."
            sleep "$interval"
        done
    fi
}

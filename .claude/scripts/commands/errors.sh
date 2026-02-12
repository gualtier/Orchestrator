#!/bin/bash
# =============================================
# COMMAND: errors - Error monitoring dashboard
# =============================================

cmd_errors() {
    local mode="dashboard"
    local agent_filter=""
    local watch_interval=5

    # Parse flags
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --watch|-w)
                mode="watch"
                if [[ "${2:-}" =~ ^[0-9]+$ ]]; then
                    watch_interval=$2
                    shift
                fi
                shift
                ;;
            --clear)
                mode="clear"
                shift
                ;;
            --agent|-a)
                agent_filter="$2"
                shift 2
                ;;
            --recent|-r)
                mode="recent"
                shift
                ;;
            --help|-h)
                cmd_errors_help
                return 0
                ;;
            *)
                shift
                ;;
        esac
    done

    case "$mode" in
        dashboard)
            cmd_errors_dashboard "$agent_filter"
            ;;
        watch)
            cmd_errors_watch "$watch_interval" "$agent_filter"
            ;;
        clear)
            cmd_errors_clear
            ;;
        recent)
            cmd_errors_recent "$agent_filter"
            ;;
    esac
}

# =============================================
# HELP
# =============================================

cmd_errors_help() {
    echo "Usage: orchestrate.sh errors [OPTIONS]"
    echo ""
    echo "Display error monitoring dashboard for orchestrator agents."
    echo ""
    echo "Options:"
    echo "  --watch, -w [SEC]    Watch mode with auto-refresh (default: 5s)"
    echo "  --agent, -a NAME     Filter errors by agent name"
    echo "  --recent, -r         Show recent errors from log"
    echo "  --clear              Clear the error log"
    echo "  --help, -h           Show this help message"
    echo ""
    echo "Examples:"
    echo "  orchestrate.sh errors              # Show error dashboard"
    echo "  orchestrate.sh errors --watch      # Watch mode (5s refresh)"
    echo "  orchestrate.sh errors --watch 10   # Watch mode (10s refresh)"
    echo "  orchestrate.sh errors -a api       # Show errors for 'api' agent only"
    echo "  orchestrate.sh errors --recent     # Show recent errors from log"
}

# =============================================
# DASHBOARD VIEW
# =============================================

cmd_errors_dashboard() {
    local agent_filter=${1:-}

    # First, check all agents for new errors (ignore return code)
    check_all_agents_errors || true

    log_header "ERROR MONITOR - $(date '+%H:%M:%S')"

    # Summary section
    local summary=$(get_error_summary)
    local total=$(echo "$summary" | cut -d'|' -f1)
    local critical=$(echo "$summary" | cut -d'|' -f2)
    local warning=$(echo "$summary" | cut -d'|' -f3)
    local info=$(echo "$summary" | cut -d'|' -f4)

    echo -e "${BOLD}Summary${NC}"
    echo -e "  Total Errors: ${BOLD}$total${NC}"
    if [[ $critical -gt 0 ]]; then
        echo -e "  ${RED}CRITICAL: $critical${NC}"
    else
        echo -e "  ${GRAY}CRITICAL: 0${NC}"
    fi
    if [[ $warning -gt 0 ]]; then
        echo -e "  ${YELLOW}WARNING: $warning${NC}"
    else
        echo -e "  ${GRAY}WARNING: 0${NC}"
    fi
    if [[ $info -gt 0 ]]; then
        echo -e "  ${BLUE}INFO: $info${NC}"
    else
        echo -e "  ${GRAY}INFO: 0${NC}"
    fi

    echo ""
    log_separator

    # Per-agent breakdown
    echo ""
    echo -e "${BOLD}Errors by Agent${NC}"
    echo ""

    local has_errors=false
    local agent_data=$(get_errors_per_agent)

    if [[ -n "$agent_filter" ]]; then
        agent_data=$(echo "$agent_data" | grep "^${agent_filter}|")
    fi

    if [[ -z "$agent_data" ]]; then
        echo -e "  ${GRAY}No agents found${NC}"
    else
        # Format: agent|count|critical|warning|info|last_error
        while IFS='|' read -r name count agent_critical agent_warning agent_info last_error; do
            [[ -z "$name" ]] && continue

            # Determine status color
            local status_color="$GREEN"
            local status_icon="✓"
            if [[ ${agent_critical:-0} -gt 0 ]]; then
                status_color="$RED"
                status_icon="✗"
                has_errors=true
            elif [[ ${agent_warning:-0} -gt 0 ]]; then
                status_color="$YELLOW"
                status_icon="⚠"
                has_errors=true
            elif [[ ${count:-0} -gt 0 ]]; then
                status_color="$BLUE"
                status_icon="ℹ"
                has_errors=true
            fi

            printf "  ${status_color}%s${NC} %-20s " "$status_icon" "$name"

            if [[ ${count:-0} -eq 0 ]]; then
                echo -e "${GRAY}No errors${NC}"
            else
                echo -e "${BOLD}${count:-0}${NC} errors"
                echo -e "      ${RED}C:${agent_critical:-0}${NC} ${YELLOW}W:${agent_warning:-0}${NC} ${BLUE}I:${agent_info:-0}${NC}"

                if [[ "$last_error" != "none" ]] && [[ -n "$last_error" ]]; then
                    echo -e "      ${GRAY}Last: ${last_error:0:55}...${NC}"
                fi
            fi
        done <<< "$agent_data"
    fi

    echo ""
    log_separator

    # Recent errors section
    echo ""
    echo -e "${BOLD}Recent Errors (last 10)${NC}"
    echo ""

    local recent_errors=$(get_recent_errors 10 "$agent_filter")

    if [[ -z "$recent_errors" ]]; then
        echo -e "  ${GREEN}No errors in log${NC}"
    else
        while IFS='|' read -r timestamp severity agent message location; do
            [[ -z "$timestamp" ]] && continue

            local sev_color="$GRAY"
            case "$severity" in
                CRITICAL) sev_color="$RED" ;;
                WARNING) sev_color="$YELLOW" ;;
                INFO) sev_color="$BLUE" ;;
            esac

            printf "  ${GRAY}%s${NC} " "${timestamp:11:8}"
            printf "${sev_color}%-8s${NC} " "$severity"
            printf "${CYAN}%-12s${NC} " "$agent"
            echo -e "${message:0:45}"
        done <<< "$recent_errors"
    fi

    echo ""
    log_separator

    # Suggestions
    if [[ "$has_errors" == true ]]; then
        echo ""
        echo -e "${BOLD}Suggested Actions${NC}"
        echo ""

        # Format: agent|count|critical|warning|info|last_error
        while IFS='|' read -r name count agent_critical agent_warning agent_info last_error; do
            [[ -z "$name" ]] && continue
            [[ ${count:-0} -eq 0 ]] && continue

            if [[ ${agent_critical:-0} -gt 0 ]]; then
                local action=$(suggest_corrective_action "CRITICAL" "$last_error")
                echo -e "  ${RED}$name${NC}: $action"
            elif [[ "$last_error" != "none" ]] && [[ -n "$last_error" ]]; then
                local action=$(suggest_corrective_action "WARNING" "$last_error")
                echo -e "  ${YELLOW}$name${NC}: $action"
            fi
        done <<< "$agent_data"
    else
        echo ""
        echo -e "${GREEN}All agents healthy - no errors detected${NC}"
    fi

    echo ""
}

# =============================================
# WATCH MODE
# =============================================

cmd_errors_watch() {
    local interval=${1:-5}
    local agent_filter=${2:-}

    trap 'echo ""; log_info "Watch stopped"; exit 0' INT TERM

    log_info "Starting error watch mode (interval: ${interval}s, Ctrl+C to exit)"
    sleep 1

    while true; do
        clear
        cmd_errors_dashboard "$agent_filter"

        echo -e "${GRAY}Next refresh in ${interval}s... (Ctrl+C to exit)${NC}"
        sleep "$interval"
    done
}

# =============================================
# RECENT ERRORS VIEW
# =============================================

cmd_errors_recent() {
    local agent_filter=${1:-}

    log_header "RECENT ERRORS - $(date '+%H:%M:%S')"

    local recent_errors=$(get_recent_errors 50 "$agent_filter")

    if [[ -z "$recent_errors" ]]; then
        echo -e "${GREEN}No errors in log${NC}"
        return 0
    fi

    echo -e "${BOLD}Showing last 50 errors${NC}"
    [[ -n "$agent_filter" ]] && echo -e "Filtered by agent: ${CYAN}$agent_filter${NC}"
    echo ""

    printf "  ${BOLD}%-8s %-8s %-12s %-50s %s${NC}\n" "TIME" "SEVERITY" "AGENT" "MESSAGE" "LOCATION"
    log_separator

    while IFS='|' read -r timestamp severity agent message location; do
        [[ -z "$timestamp" ]] && continue

        local sev_color="$GRAY"
        case "$severity" in
            CRITICAL) sev_color="$RED" ;;
            WARNING) sev_color="$YELLOW" ;;
            INFO) sev_color="$BLUE" ;;
        esac

        printf "  ${GRAY}%s${NC} " "${timestamp:11:8}"
        printf "${sev_color}%-8s${NC} " "$severity"
        printf "${CYAN}%-12s${NC} " "$agent"
        printf "%-50s " "${message:0:50}"
        if [[ -n "$location" ]]; then
            printf "${GRAY}%s${NC}" "${location:0:30}"
        fi
        echo ""
    done <<< "$recent_errors"

    echo ""
}

# =============================================
# CLEAR ERRORS
# =============================================

cmd_errors_clear() {
    log_info "Clearing error log and resetting error tracking..."

    # Clear global error log
    clear_error_log

    # Reset error tracking for all agents
    for task_file in "$ORCHESTRATION_DIR/tasks"/*.md; do
        [[ -f "$task_file" ]] || continue
        local name=$(basename "$task_file" .md)

        local errors_file=$(get_errors_file "$name")
        local offset_file=$(get_offset_file "$name")

        # Reset error state but keep offset (don't re-report old errors)
        echo "0|none|0|0|0" > "$errors_file"
        rm -f "${errors_file}.prev"
    done

    log_success "Error tracking reset for all agents"
}

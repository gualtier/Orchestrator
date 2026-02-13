#!/bin/bash
# =============================================
# COMMAND: team - Agent Teams Management
# Alternative execution backend using Claude Code Agent Teams
# =============================================

cmd_team() {
    local subcmd=${1:-"help"}
    shift || true

    case "$subcmd" in
        start)  cmd_team_start "$@" ;;
        status) cmd_team_status "$@" ;;
        stop)   cmd_team_stop "$@" ;;
        help|--help) cmd_team_help ;;
        *)
            log_error "Unknown team subcommand: $subcmd"
            cmd_team_help
            return 1
            ;;
    esac
}

# =============================================
# TEAM START
# =============================================

cmd_team_start() {
    local spec_number=""
    local skip_monitor=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --no-monitor) skip_monitor=true; shift ;;
            *) spec_number="$1"; shift ;;
        esac
    done

    if [[ -z "$spec_number" ]]; then
        log_error "Usage: orchestrate.sh team start <spec-number> [--no-monitor]"
        echo ""
        echo "  Example: orchestrate.sh team start 002"
        return 1
    fi

    # Find spec directory
    local spec_dir
    spec_dir=$(spec_dir_for "$spec_number")
    if [[ $? -ne 0 ]] || [[ -z "$spec_dir" ]]; then
        log_error "Spec not found: $spec_number"
        log_info "Run 'orchestrate.sh sdd status' to see active specs"
        return 1
    fi

    # Validate prerequisites
    if [[ ! -f "$spec_dir/spec.md" ]]; then
        log_error "No spec.md found. Run 'sdd specify' first."
        return 1
    fi

    if [[ ! -f "$spec_dir/research.md" ]]; then
        log_error "No research.md found. Run 'sdd research $spec_number' first."
        return 1
    fi

    if [[ ! -f "$spec_dir/plan.md" ]]; then
        log_error "No plan.md found. Run 'sdd plan $spec_number' first."
        return 1
    fi

    # Check if teams are available
    if ! detect_teams_available; then
        log_warn "Agent Teams feature not available"
        log_info "Set CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 to enable"
        log_info ""
        log_info "Would you like to fall back to worktree mode? (y/n)"
        if confirm "Fall back to worktree mode?"; then
            log_info "Falling back to worktree mode..."
            cmd_sdd_run "$spec_number"
            return $?
        else
            return 1
        fi
    fi

    local spec_name=$(basename "$spec_dir")

    # Start background monitor if not skipped
    if [[ "$skip_monitor" == "false" ]]; then
        log_info "Starting team monitor in background..."
        start_team_monitor "$spec_name" 10
    fi

    # Start the team
    start_team_from_spec "$spec_dir"
    local exit_code=$?

    # Stop monitor when done
    if [[ "$skip_monitor" == "false" ]]; then
        stop_team_monitor
    fi

    return $exit_code
}

# =============================================
# TEAM STATUS
# =============================================

cmd_team_status() {
    local team_name=${1:-""}

    # If no team name, show all
    show_team_status "$team_name"
}

# =============================================
# TEAM STOP
# =============================================

cmd_team_stop() {
    local team_name=${1:-""}

    log_header "STOPPING AGENT TEAM"

    if [[ -z "$team_name" ]]; then
        log_warn "No team name specified - stopping monitor only"
    fi

    # Stop the monitoring dashboard
    stop_team_monitor

    log_info ""
    log_info "Note: Agent Teams sessions run interactively."
    log_info "To stop the team, use Ctrl+C in the Claude session or close the terminal."
    log_info ""
    log_info "If the session is still running, you can:"
    log_info "  1. Press Ctrl+C to gracefully stop"
    log_info "  2. Type 'stop' to instruct the team lead to stop"
}

# =============================================
# TEAM HELP
# =============================================

cmd_team_help() {
    echo ""
    echo -e "${BOLD}Agent Teams - Alternative Execution Backend${NC}"
    echo -e "${GRAY}Uses Claude Code Agent Teams (experimental) instead of Git Worktrees${NC}"
    echo ""
    echo -e "${BOLD}COMMANDS:${NC}"
    echo ""
    echo -e "  ${CYAN}team start <spec>${NC}     Start team from SDD spec"
    echo -e "  ${CYAN}team status [name]${NC}    Show team status dashboard"
    echo -e "  ${CYAN}team stop [name]${NC}      Stop team monitoring"
    echo ""
    echo -e "${BOLD}OPTIONS:${NC}"
    echo ""
    echo -e "  ${CYAN}--no-monitor${NC}          Don't start background monitoring"
    echo ""
    echo -e "${BOLD}REQUIREMENTS:${NC}"
    echo ""
    echo "  Set environment variable: CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1"
    echo ""
    echo -e "${BOLD}EXAMPLE:${NC}"
    echo ""
    echo "  # Start team from spec 002"
    echo "  export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1"
    echo "  orchestrate.sh team start 002"
    echo ""
    echo "  # Check team status"
    echo "  orchestrate.sh team status"
    echo ""
    echo -e "${BOLD}VS WORKTREES:${NC}"
    echo ""
    echo "  Agent Teams:"
    echo "    + Real-time inter-agent communication"
    echo "    + No worktree setup needed"
    echo "    + Native task coordination"
    echo "    - Uses more tokens (each teammate is a Claude instance)"
    echo "    - No filesystem isolation"
    echo ""
    echo "  Git Worktrees (default):"
    echo "    + Full filesystem isolation"
    echo "    + Token-efficient (separate sessions)"
    echo "    + Proven reliability"
    echo "    - No real-time communication"
    echo "    - Requires worktree setup"
    echo ""
}

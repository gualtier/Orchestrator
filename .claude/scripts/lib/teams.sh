#!/bin/bash
# =============================================
# TEAMS - Agent Teams Execution Backend
# Alternative to Git Worktrees using Claude Code Agent Teams (experimental)
# =============================================

# =============================================
# DETECTION
# =============================================

# Check if Agent Teams feature is available
detect_teams_available() {
    if [[ "${CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS:-}" == "1" ]]; then
        return 0
    fi
    return 1
}

# Get teams home directory
get_teams_home() {
    echo "${HOME}/.claude/teams"
}

# Get tasks home directory for Agent Teams
get_tasks_home() {
    echo "${HOME}/.claude/tasks"
}

# =============================================
# PROMPT BUILDING
# =============================================

# Build a single agent prompt from preset and agent files
# This is a shared function used by both worktree and teams backends
# Args: worktree_name preset_name
build_agent_prompt() {
    local name=$1
    local preset=$2
    local worktree_path=${3:-""}  # Optional, for worktree backend
    local agents_source=""

    # Get agents for preset
    local specialized_agents=$(get_preset_agents "$preset")

    # Determine agents source directory
    if [[ -n "$worktree_path" ]] && [[ -d "$worktree_path/.claude/agents" ]]; then
        agents_source="$worktree_path/.claude/agents"
    elif [[ -d "$AGENTS_DIR" ]]; then
        agents_source="$AGENTS_DIR"
    fi

    local prompt="You are an executor agent with expertise in: $specialized_agents

## Specialized Expertise
"

    # Add agent content
    for agent in $specialized_agents; do
        local agent_file="$agents_source/$agent.md"
        if [[ -f "$agent_file" ]]; then
            prompt+="
### $agent
$(cat "$agent_file")
"
        fi
    done

    echo "$prompt"
}

# Build teammate spawn prompt with branch instructions
# Args: teammate_name preset file_ownership_paths
build_teammate_prompt() {
    local name=$1
    local preset=$2
    local file_paths=${3:-""}

    local agent_prompt=$(build_agent_prompt "$name" "$preset")
    local branch_instructions=$(generate_branch_instructions "$name")

    local prompt="$agent_prompt

## Working Branch
$branch_instructions

## File Ownership
You are responsible for the following paths:
$file_paths

DO NOT modify files outside your ownership scope unless absolutely necessary and documented.

## Work Protocol
1. Create PROGRESS.md immediately when starting
2. Make frequent commits with clear messages: git commit -m 'feat($name): description'
3. When finished, create DONE.md with:
   - Summary of what was done
   - List of modified files
   - Testing instructions
4. Signal task completion by updating your task status
"

    echo "$prompt"
}

# Generate branch instructions for a teammate
generate_branch_instructions() {
    local name=$1

    cat << EOF
Work on branch: feature/${name}

Before starting:
1. Create your branch: git checkout -b feature/${name}
2. All your commits should be on this branch
3. Do NOT commit directly to main

Branch naming convention: feature/{teammate-name}
EOF
}

# Build the team lead prompt from SDD artifacts
# Args: spec_dir
build_team_lead_prompt() {
    local spec_dir=$1
    local spec_name=$(basename "$spec_dir")
    local spec_num=${spec_name%%-*}

    # Read SDD artifacts
    local spec_content=""
    local research_content=""
    local plan_content=""

    if [[ -f "$spec_dir/spec.md" ]]; then
        spec_content=$(cat "$spec_dir/spec.md")
    fi

    if [[ -f "$spec_dir/research.md" ]]; then
        research_content=$(cat "$spec_dir/research.md")
    fi

    if [[ -f "$spec_dir/plan.md" ]]; then
        plan_content=$(cat "$spec_dir/plan.md")
    fi

    # Parse worktree mapping for teammate assignments
    local mappings=$(parse_worktree_mapping "$spec_dir/plan.md")
    local teammate_instructions=""
    local teammate_count=0

    while IFS='|' read -r module wt_name preset; do
        [[ -z "$wt_name" ]] && continue
        ((teammate_count++))

        local teammate_prompt=$(build_teammate_prompt "$wt_name" "$preset" "See plan.md Architecture section")

        teammate_instructions+="
### Teammate: $wt_name
- **Module**: $module
- **Preset**: $preset
- **Spawn prompt**:
\`\`\`
$teammate_prompt
\`\`\`
"
    done <<< "$mappings"

    # Build the full team lead prompt
    cat << EOF
# You are the Team Lead for: $spec_name

You are orchestrating an Agent Team to implement this feature. You will delegate work to specialized teammates and coordinate their efforts.

## Your Responsibilities
1. **Spawn teammates** according to the assignments below
2. **Delegate tasks** using the delegate() tool in plan approval mode
3. **Monitor progress** and provide guidance when teammates need help
4. **Ensure quality** by reviewing completed work before marking tasks done
5. **Coordinate integration** between teammates working on related modules

## Operating Mode
- Use **delegate mode** for all teammate spawns (teammates work autonomously)
- Enable **plan approval** for all teammates (you review their implementation plans)
- Each teammate works on their own **feature/{name} branch**

## SDD Specification
$spec_content

## Research Findings
$research_content

## Implementation Plan
$plan_content

## Teammate Assignments ($teammate_count teammates)
$teammate_instructions

## Workflow
1. Create tasks for each module using the task list
2. Spawn each teammate with their specialized prompt above
3. Monitor teammate progress via task updates
4. When all tasks are complete, verify the implementation
5. Do NOT merge branches - the orchestrator will handle merging

## Important Rules
- Each teammate MUST create DONE.md when finished
- Each teammate works on feature/{name} branch
- Teammates should NOT modify files outside their scope
- You can provide guidance but let teammates work autonomously
- Signal completion only when ALL teammates have finished

BEGIN by creating the task list and spawning your first teammate.
EOF
}

# =============================================
# TEAM MONITORING
# =============================================

# Get team config if it exists
get_team_config() {
    local team_name=$1
    local teams_home=$(get_teams_home)
    local config_file="$teams_home/$team_name/config.json"

    if [[ -f "$config_file" ]]; then
        cat "$config_file"
    else
        echo "{}"
    fi
}

# Get team members from config
get_team_members() {
    local team_name=$1
    local config=$(get_team_config "$team_name")

    echo "$config" | grep -o '"name"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/"name"[[:space:]]*:[[:space:]]*"\([^"]*\)"/\1/' || echo ""
}

# Get team task status
get_team_task_status() {
    local team_name=$1
    local tasks_home=$(get_tasks_home)
    local task_dir="$tasks_home/$team_name"

    if [[ ! -d "$task_dir" ]]; then
        echo "no_tasks"
        return
    fi

    local pending=0
    local in_progress=0
    local completed=0

    shopt -s nullglob
    for task_file in "$task_dir"/*.json; do
        [[ -f "$task_file" ]] || continue
        local status=$(grep -o '"status"[[:space:]]*:[[:space:]]*"[^"]*"' "$task_file" | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
        case "$status" in
            pending) ((pending++)) || true ;;
            in_progress) ((in_progress++)) || true ;;
            completed) ((completed++)) || true ;;
        esac
    done
    shopt -u nullglob

    echo "$pending|$in_progress|$completed"
}

# Display team status dashboard
show_team_status() {
    local team_name=${1:-""}
    local teams_home=$(get_teams_home)

    log_header "AGENT TEAMS STATUS"

    if [[ -n "$team_name" ]]; then
        # Show specific team
        local config_file="$teams_home/$team_name/config.json"
        if [[ ! -f "$config_file" ]]; then
            log_warn "Team not found: $team_name"
            return 1
        fi

        _show_single_team_status "$team_name"
    else
        # Show all teams
        if [[ ! -d "$teams_home" ]]; then
            log_info "No teams found"
            return 0
        fi

        for team_dir in "$teams_home"/*/; do
            [[ -d "$team_dir" ]] || continue
            local name=$(basename "$team_dir")
            _show_single_team_status "$name"
            echo ""
        done
    fi
}

_show_single_team_status() {
    local team_name=$1
    local members=$(get_team_members "$team_name")
    local task_status=$(get_team_task_status "$team_name")

    echo "Team: $team_name"
    log_separator

    # Parse task status
    local pending=$(echo "$task_status" | cut -d'|' -f1)
    local in_progress=$(echo "$task_status" | cut -d'|' -f2)
    local completed=$(echo "$task_status" | cut -d'|' -f3)

    echo "Tasks: $completed completed, $in_progress in progress, $pending pending"
    echo ""

    if [[ -n "$members" ]]; then
        echo "Members:"
        echo "$members" | while read -r member; do
            [[ -z "$member" ]] && continue
            echo "  - $member"
        done
    else
        echo "Members: (none spawned yet)"
    fi
}

# =============================================
# TEAM EXECUTION
# =============================================

# Start a team from SDD spec
start_team_from_spec() {
    local spec_dir=$1
    local spec_name=$(basename "$spec_dir")

    # Check if teams are available
    if ! detect_teams_available; then
        log_warn "Agent Teams not available (CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS != 1)"
        log_info "Falling back to worktree mode..."
        return 1
    fi

    log_header "STARTING AGENT TEAM: $spec_name"

    # Generate team lead prompt
    local team_lead_prompt=$(build_team_lead_prompt "$spec_dir")

    # Save prompt to temp file for reference
    local prompt_file="$spec_dir/.team_lead_prompt.md"
    echo "$team_lead_prompt" > "$prompt_file"
    log_success "Team lead prompt saved to: $prompt_file"

    # Log event
    if [[ -f "$EVENTS_FILE" ]]; then
        echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] TEAM_START: ${spec_name}" >> "$EVENTS_FILE"
    fi

    echo ""
    log_info "Starting interactive Claude session with team lead prompt..."
    log_info "The team lead will orchestrate teammates to implement the spec."
    echo ""
    log_warn "NOTE: Agent Teams uses significantly more tokens than worktrees."
    log_warn "Each teammate is a separate Claude instance."
    echo ""

    # Start interactive Claude session
    # Agent Teams must be created conversationally, not via CLI flags
    cd "$PROJECT_ROOT" && claude --dangerously-skip-permissions --permission-mode plan -p "$team_lead_prompt"

    local exit_code=$?

    # Log completion
    if [[ -f "$EVENTS_FILE" ]]; then
        echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] TEAM_END: ${spec_name} (exit: $exit_code)" >> "$EVENTS_FILE"
    fi

    return $exit_code
}

# Start monitoring dashboard in background
start_team_monitor() {
    local team_name=$1
    local interval=${2:-10}
    local monitor_pid_file="$ORCHESTRATION_DIR/pids/team_monitor.pid"

    # Check if already running
    if [[ -f "$monitor_pid_file" ]]; then
        local pid=$(cat "$monitor_pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            log_warn "Team monitor already running (PID: $pid)"
            return 0
        fi
    fi

    ensure_dir "$ORCHESTRATION_DIR/pids"

    # Start background monitor
    (
        while true; do
            clear
            show_team_status "$team_name"
            sleep "$interval"
        done
    ) &

    local pid=$!
    echo "$pid" > "$monitor_pid_file"
    log_success "Team monitor started (PID: $pid)"
}

# Stop monitoring dashboard
stop_team_monitor() {
    local monitor_pid_file="$ORCHESTRATION_DIR/pids/team_monitor.pid"

    if [[ ! -f "$monitor_pid_file" ]]; then
        log_info "No team monitor running"
        return 0
    fi

    local pid=$(cat "$monitor_pid_file")
    if kill -0 "$pid" 2>/dev/null; then
        kill "$pid" 2>/dev/null
        log_success "Team monitor stopped"
    fi

    rm -f "$monitor_pid_file"
}

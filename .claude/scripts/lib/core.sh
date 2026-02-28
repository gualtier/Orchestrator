#!/bin/bash
# =============================================
# CORE - Configuration and basic utilities
# =============================================

# Scripts base directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

# Carregar logging primeiro
source "$LIB_DIR/logging.sh"

# =============================================
# CONFIGURATION
# =============================================

init_config() {
    PROJECT_ROOT=${PROJECT_ROOT:-$(pwd)}
    PROJECT_NAME=$(basename "$PROJECT_ROOT")
    CLAUDE_DIR="$PROJECT_ROOT/.claude"
    ORCHESTRATION_DIR="$CLAUDE_DIR/orchestration"
    AGENTS_DIR="$CLAUDE_DIR/agents"
    MEMORY_FILE="$CLAUDE_DIR/PROJECT_MEMORY.md"
    STATE_FILE="$ORCHESTRATION_DIR/.state.json"
    EVENTS_FILE="$ORCHESTRATION_DIR/EVENTS.md"
    AGENTS_SCRIPT="$CLAUDE_DIR/scripts/agents.sh"
    LEARNINGS_DIR="$CLAUDE_DIR/learnings"
    LEARNINGS_PENDING="$LEARNINGS_DIR/pending"
    LEARNINGS_ROLES="$LEARNINGS_DIR/roles"
    LEARNINGS_ARCHIVE="$LEARNINGS_DIR/archive"

    # SDD (Spec-Driven Development)
    SPECS_DIR="$CLAUDE_DIR/specs"
    SPECS_ACTIVE="$SPECS_DIR/active"
    SPECS_ARCHIVE="$SPECS_DIR/archive"
    SPECS_TEMPLATES="$SPECS_DIR/templates"
    CONSTITUTION_FILE="$SPECS_DIR/constitution.md"

    # Error Monitoring (v3.5)
    ERROR_POLL_INTERVAL=${ERROR_POLL_INTERVAL:-5}
    ERROR_LOG_FILE="${ORCHESTRATION_DIR}/errors.log"
    ERROR_CACHE_DIR="${ORCHESTRATION_DIR}/pids"

    # Agent Teams (v3.8)
    # Execution mode: worktree (default) or teams
    EXECUTION_MODE=${EXECUTION_MODE:-"worktree"}
    TEAMS_HOME="${HOME}/.claude/teams"
    TASKS_HOME="${HOME}/.claude/tasks"

    # SDD Autopilot (v3.9)
    # When set to 1, hooks pass through without blocking
    SDD_AUTOPILOT=${SDD_AUTOPILOT:-"0"}

    # Exportar para subshells
    export PROJECT_ROOT PROJECT_NAME CLAUDE_DIR ORCHESTRATION_DIR
    export AGENTS_DIR MEMORY_FILE STATE_FILE EVENTS_FILE AGENTS_SCRIPT
    export LEARNINGS_DIR LEARNINGS_PENDING LEARNINGS_ROLES LEARNINGS_ARCHIVE
    export SPECS_DIR SPECS_ACTIVE SPECS_ARCHIVE SPECS_TEMPLATES CONSTITUTION_FILE
    export ERROR_POLL_INTERVAL ERROR_LOG_FILE ERROR_CACHE_DIR
    export EXECUTION_MODE TEAMS_HOME TASKS_HOME
    export SDD_AUTOPILOT
}

# Initialize configuration automatically
init_config

# =============================================
# BASIC UTILITIES
# =============================================

ensure_dir() { mkdir -p "$1"; }
file_exists() { [[ -f "$1" ]]; }
dir_exists() { [[ -d "$1" ]]; }

# Get absolute worktree path for a given agent name
get_worktree_path() {
    local name=$1
    echo "$(dirname "$PROJECT_ROOT")/${PROJECT_NAME}-$name"
}

# =============================================
# INTERACTIVE CONFIRMATION
# =============================================

confirm() {
    local msg=${1:-"Continuar?"}
    local default=${2:-"n"}

    # Se --force, retorna true
    [[ "${FORCE:-}" == "true" ]] && return 0

    # If not interactive, use default
    if [[ ! -t 0 ]]; then
        [[ "$default" == "y" ]] && return 0 || return 1
    fi

    local prompt
    if [[ "$default" == "y" ]]; then
        prompt="$msg [S/n] "
    else
        prompt="$msg [s/N] "
    fi

    read -p "$prompt" -n 1 -r
    echo

    if [[ "$default" == "y" ]]; then
        [[ ! $REPLY =~ ^[Nn]$ ]]
    else
        [[ $REPLY =~ ^[Ss]$ ]]
    fi
}

# =============================================
# TRATAMENTO DE ERROS
# =============================================

# Variable to track necessary cleanup
CLEANUP_NEEDED=false
CLEANUP_WORKTREE=""

# Trap for cleanup in case of error/interruption
cleanup_on_exit() {
    local exit_code=$?

    if [[ "$CLEANUP_NEEDED" == "true" ]] && [[ -n "$CLEANUP_WORKTREE" ]]; then
        log_warn "Cleaning up worktree after error: $CLEANUP_WORKTREE"
        git worktree remove "$CLEANUP_WORKTREE" --force 2>/dev/null || true
    fi

    exit $exit_code
}

setup_traps() {
    trap cleanup_on_exit EXIT
    trap 'log_error "Interrupted by user"; exit 130' INT
    trap 'log_error "Terminated"; exit 143' TERM
}

# Execute command with error handling
run_or_fail() {
    local cmd="$1"
    local error_msg="${2:-Command failed: $cmd}"

    if ! eval "$cmd"; then
        log_error "$error_msg"
        return 1
    fi
}

# =============================================
# AGENT PRESETS
# =============================================

get_preset_agents() {
    local preset="$1"
    case "$preset" in
        auth)     echo "backend-developer security-auditor typescript-pro" ;;
        api)      echo "api-designer backend-developer test-automator" ;;
        frontend) echo "frontend-developer react-specialist ui-designer" ;;
        fullstack) echo "fullstack-developer typescript-pro test-automator" ;;
        mobile)   echo "mobile-developer flutter-expert ui-designer" ;;
        devops)   echo "devops-engineer kubernetes-specialist terraform-engineer" ;;
        data)     echo "data-engineer data-scientist postgres-pro" ;;
        ml)       echo "ml-engineer ai-engineer mlops-engineer" ;;
        security) echo "security-auditor penetration-tester security-engineer" ;;
        review)   echo "code-reviewer architect-reviewer security-auditor" ;;
        backend)  echo "backend-developer api-designer database-administrator" ;;
        database) echo "database-administrator postgres-pro sql-pro" ;;
        *)        echo "" ;;
    esac
}

list_presets() {
    echo "auth api frontend fullstack mobile devops data ml security review backend database"
}

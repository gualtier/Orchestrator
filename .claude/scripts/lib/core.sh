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

    # Exportar para subshells
    export PROJECT_ROOT PROJECT_NAME CLAUDE_DIR ORCHESTRATION_DIR
    export AGENTS_DIR MEMORY_FILE STATE_FILE EVENTS_FILE AGENTS_SCRIPT
}

# Initialize configuration automatically
init_config

# =============================================
# BASIC UTILITIES
# =============================================

ensure_dir() { mkdir -p "$1"; }
file_exists() { [[ -f "$1" ]]; }
dir_exists() { [[ -d "$1" ]]; }

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
        log_warn "Limpando worktree após erro: $CLEANUP_WORKTREE"
        git worktree remove "$CLEANUP_WORKTREE" --force 2>/dev/null || true
    fi

    exit $exit_code
}

setup_traps() {
    trap cleanup_on_exit EXIT
    trap 'log_error "Interrompido pelo usuário"; exit 130' INT
    trap 'log_error "Terminado"; exit 143' TERM
}

# Executar comando com tratamento de erro
run_or_fail() {
    local cmd="$1"
    local error_msg="${2:-Comando falhou: $cmd}"

    if ! eval "$cmd"; then
        log_error "$error_msg"
        return 1
    fi
}

# =============================================
# PRESETS DE AGENTES
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

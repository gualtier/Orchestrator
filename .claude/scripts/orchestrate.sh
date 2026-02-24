#!/bin/bash
# ===========================================
# ORQUESTRADOR DE AGENTES CLAUDE v3.9
#   Autonomous Pipeline + Agent Teams
# ===========================================

# Note: set -e deliberately omitted — ((counter++)) returns 1 when counter=0,
# which kills the script under set -e. Error handling uses explicit || return 1.
set -o pipefail

# =============================================
# LOAD MODULES
# =============================================

# Resolve symlinks to get the real script path
SCRIPT_PATH="${BASH_SOURCE[0]}"
while [ -L "$SCRIPT_PATH" ]; do
    SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
    SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
    [[ $SCRIPT_PATH != /* ]] && SCRIPT_PATH="$SCRIPT_DIR/$SCRIPT_PATH"
done
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"

# Bibliotecas
source "$SCRIPT_DIR/lib/core.sh"
source "$SCRIPT_DIR/lib/validation.sh"
source "$SCRIPT_DIR/lib/git.sh"
source "$SCRIPT_DIR/lib/process.sh"
source "$SCRIPT_DIR/lib/agents.sh"
source "$SCRIPT_DIR/lib/monitoring.sh"
source "$SCRIPT_DIR/lib/error_detection.sh"
source "$SCRIPT_DIR/lib/sdd.sh"
source "$SCRIPT_DIR/lib/teams.sh"

# Comandos
source "$SCRIPT_DIR/commands/init.sh"
source "$SCRIPT_DIR/commands/doctor.sh"
source "$SCRIPT_DIR/commands/setup.sh"
source "$SCRIPT_DIR/commands/start.sh"
source "$SCRIPT_DIR/commands/status.sh"
source "$SCRIPT_DIR/commands/verify.sh"
source "$SCRIPT_DIR/commands/merge.sh"
source "$SCRIPT_DIR/commands/update.sh"
source "$SCRIPT_DIR/commands/learn.sh"
source "$SCRIPT_DIR/commands/errors.sh"
source "$SCRIPT_DIR/commands/sdd.sh"
source "$SCRIPT_DIR/commands/team.sh"
source "$SCRIPT_DIR/commands/help.sh"

# =============================================
# TRAP CONFIGURATION
# =============================================

setup_traps

# =============================================
# MAIN
# =============================================

main() {
    local cmd=${1:-"help"}
    shift || true

    case "$cmd" in
        # Agentes
        agents) cmd_agents "$@" ;;

        # Initialization
        init) cmd_init ;;
        init-sample) cmd_init_sample ;;
        install-cli) cmd_install_cli "$@" ;;
        uninstall-cli) cmd_uninstall_cli "$@" ;;
        doctor)
            if [[ "${1:-}" == "--fix" ]]; then
                cmd_doctor_fix
            else
                cmd_doctor
            fi
            ;;

        # Execution
        setup) cmd_setup "$@" ;;
        start) cmd_start "$@" ;;
        stop) cmd_stop "$@" ;;
        restart) cmd_restart "$@" ;;

        # Monitoramento
        status) cmd_status "$@" ;;
        wait) cmd_wait "$@" ;;
        logs) cmd_logs "$@" ;;
        follow) cmd_follow "$@" ;;
        errors) cmd_errors "$@" ;;

        # Verification
        verify) cmd_verify "$@" ;;
        verify-all) cmd_verify_all ;;
        review) cmd_review "$@" ;;
        pre-merge) cmd_pre_merge ;;
        report) cmd_report ;;

        # Finalization
        merge) cmd_merge "$@" ;;
        cleanup) cmd_cleanup ;;

        # Memory
        show-memory) cmd_show_memory ;;
        update-memory) cmd_update_memory "$@" ;;

        # Learning
        learn|learning) cmd_learn "$@" ;;

        # SDD (Spec-Driven Development)
        sdd|spec|specify) cmd_sdd "$@" ;;

        # Agent Teams (v3.8)
        team|teams) cmd_team "$@" ;;

        # Update
        update) cmd_update ;;
        update-check) cmd_update_check ;;

        # Help
        help|--help|-h) cmd_help ;;

        # Desconhecido
        *)
            log_error "Comando desconhecido: $cmd"
            echo ""
            cmd_help
            exit 1
            ;;
    esac
}

main "$@"

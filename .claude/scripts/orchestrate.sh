#!/bin/bash
# ===========================================
# ORQUESTRADOR DE AGENTES CLAUDE v3.1
#   Modular Edition
# ===========================================

set -eo pipefail

# =============================================
# CARREGAR MÓDULOS
# =============================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Bibliotecas
source "$SCRIPT_DIR/lib/core.sh"
source "$SCRIPT_DIR/lib/validation.sh"
source "$SCRIPT_DIR/lib/git.sh"
source "$SCRIPT_DIR/lib/process.sh"
source "$SCRIPT_DIR/lib/agents.sh"

# Comandos
source "$SCRIPT_DIR/commands/init.sh"
source "$SCRIPT_DIR/commands/doctor.sh"
source "$SCRIPT_DIR/commands/setup.sh"
source "$SCRIPT_DIR/commands/start.sh"
source "$SCRIPT_DIR/commands/status.sh"
source "$SCRIPT_DIR/commands/verify.sh"
source "$SCRIPT_DIR/commands/merge.sh"
source "$SCRIPT_DIR/commands/update.sh"
source "$SCRIPT_DIR/commands/help.sh"

# =============================================
# CONFIGURAÇÃO DE TRAPS
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

        # Inicialização
        init) cmd_init ;;
        init-sample) cmd_init_sample ;;
        doctor)
            if [[ "${1:-}" == "--fix" ]]; then
                cmd_doctor_fix
            else
                cmd_doctor
            fi
            ;;

        # Execução
        setup) cmd_setup "$@" ;;
        start) cmd_start "$@" ;;
        stop) cmd_stop "$@" ;;
        restart) cmd_restart "$@" ;;

        # Monitoramento
        status) cmd_status "$@" ;;
        wait) cmd_wait "$@" ;;
        logs) cmd_logs "$@" ;;
        follow) cmd_follow "$@" ;;

        # Verificação
        verify) cmd_verify "$@" ;;
        verify-all) cmd_verify_all ;;
        review) cmd_review "$@" ;;
        pre-merge) cmd_pre_merge ;;
        report) cmd_report ;;

        # Finalização
        merge) cmd_merge "$@" ;;
        cleanup) cmd_cleanup ;;

        # Memória
        show-memory) cmd_show_memory ;;
        update-memory) cmd_update_memory "$@" ;;

        # Atualização
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

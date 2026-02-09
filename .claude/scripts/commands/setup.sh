#!/bin/bash
# =============================================
# COMMAND: setup - Create worktree with agents
# =============================================

cmd_setup() {
    local name=$1
    shift || true

    # Validate name
    if [[ -z "$name" ]]; then
        log_error "Uso: $0 setup <nome> [--preset <preset>] [--agents <a1,a2>] [--from <branch>]"
        return 1
    fi

    validate_name "$name" "worktree" || return 1

    local preset=""
    local agents_list=""
    local from_branch=$(current_branch)

    # Parse argumentos
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --preset)
                preset="$2"
                shift 2
                ;;
            --agents)
                agents_list="$2"
                shift 2
                ;;
            --from)
                from_branch="$2"
                shift 2
                ;;
            *)
                log_error "Argumento desconhecido: $1"
                return 1
                ;;
        esac
    done

    # Determinar agentes
    local agents_to_copy=""

    if [[ -n "$preset" ]]; then
        validate_preset "$preset" || return 1
        agents_to_copy=$(get_preset_agents "$preset")
        log_info "Usando preset '$preset': $agents_to_copy"
    elif [[ -n "$agents_list" ]]; then
        agents_to_copy="${agents_list//,/ }"
        validate_agents_list "$agents_to_copy" || return 1
        log_info "Usando agentes: $agents_to_copy"
    else
        log_warn "Nenhum agente especificado"
        log_info "Use --preset ou --agents"
    fi

    # Garantir agentes instalados
    if [[ -n "$agents_to_copy" ]]; then
        ensure_agents_installed "$agents_to_copy" || {
            log_error "Falha ao instalar agentes"
            return 1
        }
    fi

    # Create worktree
    create_git_worktree "$name" "$from_branch" || return 1

    local worktree_path="../${PROJECT_NAME}-$name"

    # Copiar agentes para worktree
    if [[ -n "$agents_to_copy" ]]; then
        copy_agents_to_worktree "$worktree_path" "$agents_to_copy"
        log_success "Agentes copiados para worktree"
    fi

    # Create basic structure
    ensure_dir "$worktree_path/.claude"

    log_success "Worktree '$name' criada com sucesso!"
    echo ""
    echo "Próximos passos:"
    echo "  1. Criar tarefa: $ORCHESTRATION_DIR/tasks/$name.md"
    echo "  2. Iniciar: $0 start $name"
}

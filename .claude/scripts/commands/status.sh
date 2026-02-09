#!/bin/bash
# =============================================
# COMMAND: status/wait - Monitoramento
# =============================================

cmd_status() {
    local format=${1:-"text"}

    if [[ "$format" == "--json" ]]; then
        cmd_status_json
        return
    fi

    log_header "ORQUESTRADOR v3.1 - STATUS - $(date '+%H:%M:%S')"

    local total=0 done=0 blocked=0 running=0 waiting=0

    for task_file in "$ORCHESTRATION_DIR/tasks"/*.md; do
        [[ -f "$task_file" ]] || continue

        local name=$(basename "$task_file" .md)
        local worktree_path="../${PROJECT_NAME}-$name"

        ((total++))

        echo ""
        echo -e "${YELLOW}┌─── $name ───${NC}"

        # Agentes especializados
        if file_exists "$worktree_path/.claude/AGENTS_USED"; then
            local agents_used=$(cat "$worktree_path/.claude/AGENTS_USED")
            echo -e "│ Agentes: ${CYAN}$agents_used${NC}"
        fi

        # Status do processo
        local proc_status="⚪ Parado"
        local elapsed=""

        if is_process_running "$name"; then
            local pid=$(get_process_pid "$name")
            local runtime=$(get_process_runtime "$name")
            proc_status="${GREEN}🟢 Rodando (PID: $pid)${NC}"
            elapsed=" [$runtime]"
        fi
        echo -e "│ Processo: $proc_status$elapsed"

        # Status da tarefa
        local status=$(get_agent_status "$name")
        case "$status" in
            done)
                echo -e "│ Tarefa: ${GREEN}✅ CONCLUÍDA${NC}"
                ((done++))
                ;;
            blocked)
                echo -e "│ Tarefa: ${RED}🚫 BLOQUEADA${NC}"
                ((blocked++))
                ;;
            running)
                echo -e "│ Tarefa: ${BLUE}🔄 EM PROGRESSO${NC}"
                local progress=$(get_agent_progress "$name")
                echo -e "│   Progresso: ${progress}%"
                ((running++))
                ;;
            *)
                echo -e "│ Tarefa: ${YELLOW}⏳ AGUARDANDO${NC}"
                ((waiting++))
                ;;
        esac

        # Last commit
        if dir_exists "$worktree_path"; then
            local commit=$(cd "$worktree_path" && last_commit)
            echo -e "│ Commit: ${GRAY}$commit${NC}"
        fi

        echo -e "${YELLOW}└──────────────────────────────────────${NC}"
    done

    if [[ $total -eq 0 ]]; then
        echo ""
        echo -e "${YELLOW}Nenhuma tarefa encontrada${NC}"
        return 1
    fi

    echo ""
    log_separator
    echo -e "📊 Total: $total | ✅ $done | 🔄 $running | ⏳ $waiting | 🚫 $blocked"
    log_separator

    if [[ $done -eq $total ]] && [[ $total -gt 0 ]]; then
        echo ""
        echo -e "${GREEN}🎉 TODOS OS AGENTES CONCLUÍRAM!${NC}"
        return 0
    fi

    return 1
}

cmd_status_json() {
    echo "{"
    echo "  \"timestamp\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\","
    echo "  \"worktrees\": ["

    local first=true
    for task_file in "$ORCHESTRATION_DIR/tasks"/*.md; do
        [[ -f "$task_file" ]] || continue

        local name=$(basename "$task_file" .md)
        local worktree_path="../${PROJECT_NAME}-$name"
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
            done) ((done++)) ;;
            running) ((running++)) ;;
            blocked) ((blocked++)) ;;
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

cmd_wait() {
    local interval=${1:-30}

    log_info "Aguardando agentes terminarem..."
    log_info "Intervalo de verificação: ${interval}s (Ctrl+C para sair)"

    while true; do
        if cmd_status > /dev/null 2>&1; then
            log_success "Todos os agentes concluíram!"
            return 0
        fi

        echo ""
        log_info "Próxima verificação em ${interval}s..."
        sleep "$interval"
    done
}

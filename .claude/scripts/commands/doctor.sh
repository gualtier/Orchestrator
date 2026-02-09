#!/bin/bash
# =============================================
# COMMAND: doctor - System diagnostics
# =============================================

cmd_doctor() {
    log_header "DIAGNÓSTICO DO ORQUESTRADOR"

    local errors=0
    local warnings=0

    # 1. Git
    echo -e "${YELLOW}[1/8] Verificando Git...${NC}"
    if command -v git &>/dev/null; then
        local git_version=$(git --version | awk '{print $3}')
        log_success "Git instalado: $git_version"
    else
        log_error "Git não encontrado"
        ((errors++))
    fi

    # 2. Claude CLI
    echo -e "${YELLOW}[2/8] Verificando Claude CLI...${NC}"
    if command -v claude &>/dev/null; then
        local claude_version=$(claude --version 2>/dev/null || echo "versão desconhecida")
        log_success "Claude CLI instalado: $claude_version"
    else
        log_error "Claude CLI não encontrado"
        log_info "Instale em: https://claude.ai/download"
        ((errors++))
    fi

    # 3. Git Repository
    echo -e "${YELLOW}[3/8] Verificando repositório...${NC}"
    if git rev-parse --is-inside-work-tree &>/dev/null; then
        log_success "Repositório Git válido"
        local branch=$(current_branch)
        log_info "Branch atual: $branch"
    else
        log_error "Não é um repositório Git"
        ((errors++))
    fi

    # 4. Directory structure
    echo -e "${YELLOW}[4/8] Verificando estrutura...${NC}"
    local dirs_ok=true
    for dir in "$CLAUDE_DIR" "$ORCHESTRATION_DIR" "$AGENTS_DIR"; do
        if dir_exists "$dir"; then
            log_success "Diretório existe: $(basename "$dir")"
        else
            log_warn "Diretório não existe: $(basename "$dir")"
            ((warnings++))
            dirs_ok=false
        fi
    done

    if [[ "$dirs_ok" == "false" ]]; then
        log_info "Execute: $0 init"
    fi

    # 5. Worktrees
    echo -e "${YELLOW}[5/8] Verificando worktrees...${NC}"
    local worktree_count=$(git worktree list 2>/dev/null | wc -l | tr -d ' ')
    log_info "Total de worktrees: $worktree_count"

    # Check for orphans
    local orphans=0
    while IFS= read -r line; do
        local path=$(echo "$line" | awk '{print $1}')
        if [[ ! -d "$path" ]] && [[ "$path" != "$PROJECT_ROOT" ]]; then
            log_warn "Worktree órfã: $path"
            ((orphans++))
        fi
    done < <(git worktree list 2>/dev/null)

    if [[ $orphans -gt 0 ]]; then
        log_warn "$orphans worktree(s) órfã(s) encontrada(s)"
        log_info "Execute: git worktree prune"
        ((warnings++))
    else
        log_success "Sem worktrees órfãs"
    fi

    # 6. Processos
    echo -e "${YELLOW}[6/8] Verificando processos...${NC}"
    local running=0
    local zombies=0

    for pidfile in "$ORCHESTRATION_DIR/pids"/*.pid; do
        [[ -f "$pidfile" ]] || continue
        local name=$(basename "$pidfile" .pid)
        local pid=$(cat "$pidfile")

        if kill -0 "$pid" 2>/dev/null; then
            log_info "Processo rodando: $name (PID: $pid)"
            ((running++))
        else
            log_warn "PID file órfão: $name (processo morto)"
            ((zombies++))
        fi
    done

    if [[ $zombies -gt 0 ]]; then
        log_warn "$zombies arquivo(s) PID órfão(s)"
        log_info "Execute: rm -f $ORCHESTRATION_DIR/pids/*.pid"
        ((warnings++))
    fi

    log_info "$running agente(s) rodando"

    # 7. Disk space
    echo -e "${YELLOW}[7/8] Verificando espaço em disco...${NC}"
    local disk_free=$(df -h . 2>/dev/null | tail -1 | awk '{print $4}')
    local disk_pct=$(df -h . 2>/dev/null | tail -1 | awk '{print $5}' | tr -d '%')

    if [[ $disk_pct -gt 90 ]]; then
        log_error "Disco quase cheio: $disk_pct% usado"
        ((errors++))
    elif [[ $disk_pct -gt 80 ]]; then
        log_warn "Disco com pouco espaço: $disk_pct% usado"
        ((warnings++))
    else
        log_success "Espaço em disco OK: $disk_free livre"
    fi

    # 8. Logs
    echo -e "${YELLOW}[8/8] Verificando logs...${NC}"
    local log_count=$(ls -1 "$ORCHESTRATION_DIR/logs"/*.log 2>/dev/null | wc -l | tr -d ' ')
    local log_size=$(du -sh "$ORCHESTRATION_DIR/logs" 2>/dev/null | awk '{print $1}')

    log_info "$log_count arquivo(s) de log ($log_size)"

    # Check large logs
    for logfile in "$ORCHESTRATION_DIR/logs"/*.log; do
        [[ -f "$logfile" ]] || continue
        local size=$(stat -f%z "$logfile" 2>/dev/null || stat -c%s "$logfile" 2>/dev/null || echo 0)
        if [[ $size -gt 10485760 ]]; then  # 10MB
            log_warn "Log grande: $(basename "$logfile") ($(numfmt --to=iec $size 2>/dev/null || echo "${size}B"))"
            ((warnings++))
        fi
    done

    # Resumo
    echo ""
    log_separator

    if [[ $errors -eq 0 ]] && [[ $warnings -eq 0 ]]; then
        echo -e "${GREEN}✅ SISTEMA SAUDÁVEL${NC}"
        echo "Nenhum problema encontrado."
        return 0
    elif [[ $errors -eq 0 ]]; then
        echo -e "${YELLOW}⚠️  SISTEMA COM AVISOS${NC}"
        echo "$warnings aviso(s) encontrado(s)"
        return 0
    else
        echo -e "${RED}❌ PROBLEMAS ENCONTRADOS${NC}"
        echo "$errors erro(s), $warnings aviso(s)"
        return 1
    fi
}

cmd_doctor_fix() {
    log_step "Corrigindo problemas automaticamente..."

    # Clean orphaned PIDs
    for pidfile in "$ORCHESTRATION_DIR/pids"/*.pid; do
        [[ -f "$pidfile" ]] || continue
        local pid=$(cat "$pidfile")
        if ! kill -0 "$pid" 2>/dev/null; then
            rm -f "$pidfile"
            rm -f "${pidfile%.pid}.started"
            log_info "Removido PID órfão: $(basename "$pidfile")"
        fi
    done

    # Clean orphaned worktrees
    git worktree prune 2>/dev/null
    log_info "Worktrees órfãs removidas"

    # Rotacionar logs grandes
    rotate_logs

    log_success "Correções aplicadas"
    log_info "Execute '$0 doctor' para verificar"
}

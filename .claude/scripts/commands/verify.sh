#!/bin/bash
# =============================================
# COMMAND: verify/review/pre-merge/report
# =============================================

cmd_verify() {
    local name=$1

    if [[ -z "$name" ]]; then
        log_error "Uso: $0 verify <worktree>"
        return 1
    fi

    local worktree_path="../${PROJECT_NAME}-$name"
    local errors=0
    local warnings=0

    log_header "VERIFICAÇÃO: $name"

    # 1. Check if worktree exists
    if ! dir_exists "$worktree_path"; then
        log_error "Worktree não encontrada: $worktree_path"
        return 1
    fi

    # 2. Check DONE.md
    echo -e "${YELLOW}[1/5] Verificando DONE.md...${NC}"
    if file_exists "$worktree_path/DONE.md"; then
        log_success "DONE.md existe"

        local done_errors=0
        validate_done_file "$worktree_path/DONE.md" || done_errors=$?

        if [[ $done_errors -gt 0 ]]; then
            log_warn "DONE.md incompleto ($done_errors seções faltando)"
            ((warnings++))
        fi
    else
        log_error "DONE.md não encontrado"
        ((errors++))
    fi

    # 3. Check pending files
    echo -e "${YELLOW}[2/5] Verificando arquivos pendentes...${NC}"
    local uncommitted=$(cd "$worktree_path" && git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    if [[ $uncommitted -gt 0 ]]; then
        log_warn "$uncommitted arquivo(s) não commitado(s)"
        ((warnings++))
        (cd "$worktree_path" && git status --short)
    else
        log_success "Todos os arquivos commitados"
    fi

    # 4. Check if there is BLOCKED.md
    echo -e "${YELLOW}[3/5] Verificando bloqueios...${NC}"
    if file_exists "$worktree_path/BLOCKED.md"; then
        log_error "Tarefa está BLOQUEADA"
        cat "$worktree_path/BLOCKED.md"
        ((errors++))
    else
        log_success "Sem bloqueios"
    fi

    # 5. Check tests
    echo -e "${YELLOW}[4/5] Verificando testes...${NC}"
    local has_tests=false

    if file_exists "$worktree_path/package.json"; then
        local test_script=$(grep -o '"test"' "$worktree_path/package.json" 2>/dev/null || echo "")
        if [[ -n "$test_script" ]]; then
            has_tests=true
            log_info "Encontrado: npm test"
        fi
    fi

    if file_exists "$worktree_path/Makefile"; then
        if grep -q "^test:" "$worktree_path/Makefile" 2>/dev/null; then
            has_tests=true
            log_info "Encontrado: make test"
        fi
    fi

    if ! $has_tests; then
        log_info "Nenhum script de teste detectado"
    fi

    # 6. Check commits
    echo -e "${YELLOW}[5/5] Verificando commits...${NC}"
    local commit_count=$(cd "$worktree_path" && count_commits_since main)
    log_info "$commit_count commit(s) desde main"

    # Resumo
    echo ""
    log_separator
    if [[ $errors -eq 0 ]] && [[ $warnings -eq 0 ]]; then
        echo -e "${GREEN}✅ VERIFICAÇÃO APROVADA${NC}"
        return 0
    elif [[ $errors -eq 0 ]]; then
        echo -e "${YELLOW}⚠️  VERIFICAÇÃO COM AVISOS: $warnings aviso(s)${NC}"
        return 0
    else
        echo -e "${RED}❌ VERIFICAÇÃO FALHOU: $errors erro(s), $warnings aviso(s)${NC}"
        return 1
    fi
}

cmd_verify_all() {
    local failed=0
    local passed=0

    for task_file in "$ORCHESTRATION_DIR/tasks"/*.md; do
        [[ -f "$task_file" ]] || continue
        local name=$(basename "$task_file" .md)

        if cmd_verify "$name"; then
            ((passed++))
        else
            ((failed++))
        fi
    done

    echo ""
    log_separator
    echo -e "📊 RESUMO: ✅ $passed aprovadas | ❌ $failed reprovadas"
    log_separator

    [[ $failed -eq 0 ]]
}

cmd_review() {
    local name=$1

    if [[ -z "$name" ]]; then
        log_error "Uso: $0 review <worktree>"
        return 1
    fi

    local worktree_path="../${PROJECT_NAME}-$name"
    local review_name="review-$name"

    if ! dir_exists "$worktree_path"; then
        log_error "Worktree não encontrada: $worktree_path"
        return 1
    fi

    if ! file_exists "$worktree_path/DONE.md"; then
        log_error "Worktree não está concluída (sem DONE.md)"
        return 1
    fi

    log_step "Criando review para: $name"

    # Get branch
    local source_branch=$(cd "$worktree_path" && current_branch)

    # Create worktree de review
    cmd_setup "$review_name" --preset review --from "$source_branch" || return 1

    # Create review task
    local review_task="$ORCHESTRATION_DIR/tasks/$review_name.md"

    cat > "$review_task" << EOF
# Review: $name

## Objetivo
Revisar o código desenvolvido na worktree \`$name\`.

## Branch
\`$source_branch\`

## Checklist

### Code Quality
- [ ] Código segue boas práticas
- [ ] Nomes claros
- [ ] Funções pequenas

### Security
- [ ] Sem vulnerabilidades
- [ ] Inputs validados
- [ ] Sem secrets hardcoded

### Arquitetura
- [ ] Segue padrões do projeto
- [ ] Boa separação de responsabilidades

### Testes
- [ ] Testes existem
- [ ] Testes fazem sentido

## Arquivos para Revisar
$(cd "$worktree_path" && files_changed_since main | sed 's/^/- /')

## Deliverable
Criar REVIEW.md com problemas e sugestões.
EOF

    log_success "Review criada: $review_name"
    log_info "Execute: $0 start $review_name"
}

cmd_pre_merge() {
    log_step "Executando verificações pré-merge..."

    local all_passed=true
    local worktrees=()

    # List worktrees (ignore reviews)
    for task_file in "$ORCHESTRATION_DIR/tasks"/*.md; do
        [[ -f "$task_file" ]] || continue
        local name=$(basename "$task_file" .md)
        [[ "$name" == review-* ]] && continue
        worktrees+=("$name")
    done

    if [[ ${#worktrees[@]} -eq 0 ]]; then
        log_error "Nenhuma worktree encontrada"
        return 1
    fi

    log_header "PRÉ-MERGE CHECK"

    # 1. Check all
    echo -e "${YELLOW}[1/3] Verificando worktrees...${NC}"
    for name in "${worktrees[@]}"; do
        if cmd_verify "$name" > /dev/null 2>&1; then
            log_success "$name: OK"
        else
            log_error "$name: FALHOU"
            all_passed=false
        fi
    done

    # 2. Check conflicts
    echo ""
    echo -e "${YELLOW}[2/3] Verificando conflitos potenciais...${NC}"

    local all_files=""
    for name in "${worktrees[@]}"; do
        local worktree_path="../${PROJECT_NAME}-$name"
        local files=$(cd "$worktree_path" && files_changed_since main 2>/dev/null)
        all_files="$all_files"$'\n'"$files"
    done

    local duplicates=$(echo "$all_files" | sort | uniq -d | grep -v '^$' || true)

    if [[ -n "$duplicates" ]]; then
        log_warn "Arquivos em múltiplas worktrees:"
        echo "$duplicates" | while read -r file; do
            [[ -n "$file" ]] && echo "  - $file"
        done
    else
        log_success "Sem arquivos conflitantes"
    fi

    # 3. Simular merge
    echo ""
    echo -e "${YELLOW}[3/3] Simulando merge...${NC}"

    for name in "${worktrees[@]}"; do
        local branch="feature/$name"
        if simulate_merge "$branch" main; then
            log_success "$branch: merge OK"
        else
            log_error "$branch: conflito detectado"
            all_passed=false
        fi
    done

    # Resumo
    echo ""
    log_separator
    if $all_passed; then
        echo -e "${GREEN}✅ PRÉ-MERGE APROVADO${NC}"
        return 0
    else
        echo -e "${RED}❌ PRÉ-MERGE FALHOU${NC}"
        return 1
    fi
}

cmd_report() {
    log_step "Gerando relatório..."

    local report_file="$ORCHESTRATION_DIR/REPORT_$(date '+%Y%m%d_%H%M%S').md"

    cat > "$report_file" << EOF
# Development Report

> **Gerado em**: $(date '+%Y-%m-%d %H:%M:%S')
> **Projeto**: $PROJECT_NAME

---

## Resumo

EOF

    local total=0 done=0 blocked=0

    for task_file in "$ORCHESTRATION_DIR/tasks"/*.md; do
        [[ -f "$task_file" ]] || continue
        ((total++))
        local name=$(basename "$task_file" .md)
        local worktree_path="../${PROJECT_NAME}-$name"

        file_exists "$worktree_path/DONE.md" && ((done++))
        file_exists "$worktree_path/BLOCKED.md" && ((blocked++))
    done

    cat >> "$report_file" << EOF
| Métrica | Valor |
|---------|-------|
| Total | $total |
| Concluídas | $done |
| Bloqueadas | $blocked |
| Em progresso | $((total - done - blocked)) |

---

## Detalhes

EOF

    for task_file in "$ORCHESTRATION_DIR/tasks"/*.md; do
        [[ -f "$task_file" ]] || continue
        local name=$(basename "$task_file" .md)
        local worktree_path="../${PROJECT_NAME}-$name"

        echo "### $name" >> "$report_file"
        echo "" >> "$report_file"

        # Agentes
        if file_exists "$worktree_path/.claude/AGENTS_USED"; then
            echo "**Agentes**: $(cat "$worktree_path/.claude/AGENTS_USED")" >> "$report_file"
            echo "" >> "$report_file"
        fi

        # Status
        local status=$(get_agent_status "$name")
        echo "**Status**: $status" >> "$report_file"
        echo "" >> "$report_file"

        # DONE.md
        if file_exists "$worktree_path/DONE.md"; then
            echo "<details><summary>DONE.md</summary>" >> "$report_file"
            echo "" >> "$report_file"
            cat "$worktree_path/DONE.md" >> "$report_file"
            echo "</details>" >> "$report_file"
        fi

        echo "" >> "$report_file"
        echo "---" >> "$report_file"
        echo "" >> "$report_file"
    done

    log_success "Relatório gerado: $report_file"
    cat "$report_file"
}

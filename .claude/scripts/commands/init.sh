#!/bin/bash
# =============================================
# COMMAND: init - Orchestrator initialization
# =============================================

cmd_init() {
    log_step "Inicializando orquestrador v3.3..."

    # Validate git repository
    validate_git_repo || return 1

    # Create directory structure
    ensure_dir "$ORCHESTRATION_DIR"/{tasks,status,logs,pids,archive,checkpoints,.recovery,.backups}
    ensure_dir "$AGENTS_DIR"
    ensure_dir "$CLAUDE_DIR/scripts"

    # Create base AGENT_CLAUDE.md
    create_agent_claude_base

    # Create or reset PROJECT_MEMORY.md
    _init_project_memory

    # Configurar .gitignore
    _init_gitignore

    # Create examples if they do not exist
    ensure_dir "$ORCHESTRATION_DIR/examples"
    create_example_tasks

    # Initialize files
    touch "$EVENTS_FILE"

    log_success "Estrutura criada!"

    # Show next steps
    echo ""
    echo -e "${CYAN}Próximos passos:${NC}"
    echo ""
    echo "  1. Instalar CLI global (opcional):"
    echo "     ${GREEN}$0 install-cli${NC}"
    echo ""
    echo "  2. Ver agentes disponíveis:"
    echo "     ${GREEN}$0 agents list${NC}"
    echo ""
    echo "  3. Criar worktrees com agentes:"
    echo "     ${GREEN}$0 setup auth --preset auth${NC}"
    echo ""
    echo "  4. Ou copiar um exemplo de tarefa:"
    echo "     ${GREEN}$0 init-sample${NC}"
    echo ""
    echo "  5. Verificar instalação:"
    echo "     ${GREEN}$0 doctor${NC}"
}

cmd_install_cli() {
    local cli_name=${1:-"orch"}
    local install_dir="/usr/local/bin"
    local script_path="$SCRIPT_DIR/orchestrate.sh"
    local link_path="$install_dir/$cli_name"

    log_header "INSTALAR CLI"

    # Check if script exists
    if [[ ! -f "$script_path" ]]; then
        log_error "Script não encontrado: $script_path"
        return 1
    fi

    # Check if already exists
    if [[ -L "$link_path" ]]; then
        local existing_target=$(readlink "$link_path")
        if [[ "$existing_target" == "$script_path" ]]; then
            log_success "CLI '$cli_name' já está instalado e aponta para o local correto"
            return 0
        else
            log_warn "CLI '$cli_name' já existe mas aponta para: $existing_target"
            if ! confirm "Deseja sobrescrever?"; then
                log_info "Operação cancelada"
                return 0
            fi
            sudo rm "$link_path"
        fi
    elif [[ -f "$link_path" ]]; then
        log_error "'$link_path' já existe e não é um symlink"
        log_info "Remova manualmente ou escolha outro nome"
        return 1
    fi

    # Ensure the script is executable
    chmod +x "$script_path"

    # Create symlink
    log_step "Criando symlink em $install_dir..."

    if sudo ln -sf "$script_path" "$link_path"; then
        log_success "CLI instalado com sucesso!"
        echo ""
        log_info "Agora você pode usar:"
        echo ""
        echo "  ${GREEN}$cli_name help${NC}"
        echo "  ${GREEN}$cli_name status${NC}"
        echo "  ${GREEN}$cli_name update-check${NC}"
        echo ""
    else
        log_error "Falha ao criar symlink"
        log_info "Verifique se você tem permissões sudo"
        return 1
    fi

    return 0
}

cmd_uninstall_cli() {
    local cli_name=${1:-"orch"}
    local link_path="/usr/local/bin/$cli_name"

    log_header "DESINSTALAR CLI"

    if [[ ! -L "$link_path" ]]; then
        if [[ -f "$link_path" ]]; then
            log_error "'$link_path' existe mas não é um symlink"
            return 1
        else
            log_warn "CLI '$cli_name' não está instalado"
            return 0
        fi
    fi

    if ! confirm "Remover CLI '$cli_name'?"; then
        log_info "Operação cancelada"
        return 0
    fi

    if sudo rm "$link_path"; then
        log_success "CLI '$cli_name' removido com sucesso"
    else
        log_error "Falha ao remover CLI"
        return 1
    fi

    return 0
}

cmd_init_sample() {
    log_step "Copiando exemplos de tarefas..."

    local examples_dir="$ORCHESTRATION_DIR/examples"
    local tasks_dir="$ORCHESTRATION_DIR/tasks"

    if [[ ! -d "$examples_dir" ]] || [[ -z "$(ls -A "$examples_dir" 2>/dev/null)" ]]; then
        create_example_tasks
    fi

    for example in "$examples_dir"/*.md; do
        [[ -f "$example" ]] || continue
        local name=$(basename "$example")
        if [[ ! -f "$tasks_dir/$name" ]]; then
            cp "$example" "$tasks_dir/$name"
            log_success "Copiado: $name"
        else
            log_warn "Já existe: $name (pulando)"
        fi
    done

    log_success "Exemplos copiados para $tasks_dir"
    log_info "Edite as tarefas conforme necessário"
}

# =============================================
# HELPERS
# =============================================

_init_gitignore() {
    local gitignore="$PROJECT_ROOT/.gitignore"
    local marker="# Orchestrator (auto-generated)"
    local entries=(
        ""
        "$marker"
        ".claude/orchestration/logs/"
        ".claude/orchestration/pids/"
        ".claude/orchestration/status/"
        ".claude/orchestration/archive/"
        ".claude/orchestration/checkpoints/"
        ".claude/orchestration/.recovery/"
        ".claude/orchestration/.backups/"
        ".claude/orchestration/EVENTS.md"
        ".claude/agents/"
        ".claude/PROJECT_MEMORY.md.orchestrator-backup"
    )

    # If marker already exists, do not add again
    if [[ -f "$gitignore" ]] && grep -q "$marker" "$gitignore" 2>/dev/null; then
        log_info ".gitignore já configurado (mantendo)"
        return 0
    fi

    log_step "Configurando .gitignore..."

    # Adicionar entradas ao .gitignore
    for entry in "${entries[@]}"; do
        echo "$entry" >> "$gitignore"
    done

    log_success ".gitignore atualizado"
}

_init_project_memory() {
    # If does not exist, create new
    if ! file_exists "$MEMORY_FILE"; then
        log_step "Criando PROJECT_MEMORY.md..."
        create_initial_memory
        return 0
    fi

    # Check if it is the orchestrator memory (repo template)
    if grep -q "Nome.*claude-orchestrator" "$MEMORY_FILE" 2>/dev/null; then
        log_warn "Detectado PROJECT_MEMORY.md do repositório do orquestrador"
        log_info "Criando memória limpa para seu projeto..."

        # Backup of original (for reference)
        cp "$MEMORY_FILE" "$MEMORY_FILE.orchestrator-backup"

        # Create clean memory
        create_initial_memory

        log_success "Nova memória criada!"
        log_info "Backup salvo em: PROJECT_MEMORY.md.orchestrator-backup"
        return 0
    fi

    # Memory already exists and is from another project
    log_info "PROJECT_MEMORY.md já existe (mantendo)"
}

# =============================================
# TEMPLATES
# =============================================

create_agent_claude_base() {
    cat > "$CLAUDE_DIR/AGENT_CLAUDE.md" << 'EOF'
# AGENTE EXECUTOR

**VOCÊ NÃO É UM ORQUESTRADOR**

## Identidade
Você é um AGENTE EXECUTOR com uma tarefa específica.
Você possui expertise especializada conforme os agentes carregados.

## Regras Absolutas
1. **NUNCA** crie worktrees ou outros agentes
2. **NUNCA** execute orchestrate.sh
3. **NUNCA** modifique PROJECT_MEMORY.md
4. **FOQUE** exclusivamente na sua tarefa

## Seu Fluxo
1. Criar PROGRESS.md inicial
2. Executar tarefa passo a passo
3. Atualizar PROGRESS.md frequentemente
4. Fazer commits descritivos
5. Criar DONE.md quando terminar

## Arquivos de Status

### PROGRESS.md
```markdown
# Progresso: [tarefa]
## Status: EM ANDAMENTO
## Completed
- [x] Item
## Pendente
- [ ] Item
## Last Update
[DATA]: [descrição]
```

### DONE.md (ao finalizar)
```markdown
# Completed: [task]
## Resumo
[O que foi feito]
## Arquivos
- path/file.ts - [mudança]
## Como Testar
[Instruções de teste]
```

### BLOCKED.md (if necessary)
```markdown
# Bloqueado: [tarefa]
## Problema
[Descrição]
## Preciso
[O que desbloqueia]
```

## Commits
```
feat(escopo): descrição
fix(escopo): descrição
refactor(escopo): descrição
test(escopo): descrição
```
EOF
}

create_initial_memory() {
    local current_date=$(date '+%Y-%m-%d %H:%M')
    local repo_url=$(git remote get-url origin 2>/dev/null || echo "[local]")

    cat > "$MEMORY_FILE" << EOF
# Project Memory

> **Última atualização**: $current_date
> **Versão**: 0.1

## Overview

### Projeto

- **Nome**: $PROJECT_NAME
- **Descrição**: [Descreva seu projeto aqui]
- **Início**: $(date '+%Y-%m-%d')
- **Repo**: $repo_url

### Stack

| Camada | Tecnologia |
|--------|------------|
| Linguagem | [DEFINIR] |
| Framework | [DEFINIR] |
| Database | [DEFINIR] |

## Arquitetura

[Descreva a arquitetura do seu projeto]

## Roadmap

### v0.1 - MVP

- [ ] Feature 1
- [ ] Feature 2

### v0.2 - Melhorias

- [ ] Feature 3
- [ ] Feature 4

## Architecture Decisions

### ADR-001: [Decision Title]

- **Decisão**: [O que foi decidido]
- **Motivo**: [Por que foi decidido]
- **Trade-off**: [Prós e contras]

## Problemas Resolvidos

| Problema | Versão | Solução |
|----------|--------|---------|
| - | - | - |

## Lessons Learned

1. [Adicione lições aprendidas durante o desenvolvimento]

## Next Session

### Em Progresso

- [ ] [Tarefas em andamento]

### Ideias Futuras

- [Ideias para implementar depois]

---
> Atualize com: \`orch update-memory\` ou \`.claude/scripts/orchestrate.sh update-memory\`
EOF
}

create_example_tasks() {
    local examples_dir="$ORCHESTRATION_DIR/examples"
    ensure_dir "$examples_dir"

    # Exemplo: Auth
    cat > "$examples_dir/auth.md" << 'EOF'
# Task: Authentication System

## Objetivo
Implementar sistema de autenticação com JWT.

## Requisitos
- [ ] Login com email/senha
- [ ] Registro de usuário
- [ ] Refresh token
- [ ] Logout

## Escopo

### FAZER
- [ ] Modelo de usuário
- [ ] Rotas de auth (/login, /register, /logout)
- [ ] Middleware de autenticação
- [ ] Testes

### DO NOT DO
- OAuth/Social login (próxima fase)
- 2FA (próxima fase)

## Arquivos
Criar:
- src/auth/
- src/auth/routes.ts
- src/auth/middleware.ts
- src/auth/models/user.ts

## Completion Criteria
- [ ] Testes passando
- [ ] Documentação da API
- [ ] DONE.md criado
EOF

    # Exemplo: API
    cat > "$examples_dir/api-crud.md" << 'EOF'
# Tarefa: API CRUD

## Objetivo
Criar API REST para gerenciamento de recursos.

## Requisitos
- [ ] Endpoints CRUD (Create, Read, Update, Delete)
- [ ] Validação de entrada
- [ ] Paginação
- [ ] Tratamento de erros

## Escopo

### FAZER
- [ ] Rotas REST
- [ ] Validadores
- [ ] Controllers
- [ ] Testes

### DO NOT DO
- Autenticação (outro worktree)
- Frontend

## Arquivos
Criar:
- src/api/
- src/api/routes.ts
- src/api/controllers/
- src/api/validators/

## Completion Criteria
- [ ] Endpoints funcionando
- [ ] Testes passando
- [ ] DONE.md criado
EOF

    # Exemplo: Frontend
    cat > "$examples_dir/frontend.md" << 'EOF'
# Tarefa: Interface Frontend

## Objetivo
Criar interface de usuário responsiva.

## Requisitos
- [ ] Layout responsivo
- [ ] Componentes reutilizáveis
- [ ] Integração com API
- [ ] Estados de loading/erro

## Escopo

### FAZER
- [ ] Estrutura de componentes
- [ ] Páginas principais
- [ ] Integração com API
- [ ] Estilos

### DO NOT DO
- Testes E2E (próxima fase)
- Animações complexas

## Arquivos
Criar:
- src/components/
- src/pages/
- src/hooks/
- src/styles/

## Completion Criteria
- [ ] UI funcionando
- [ ] Responsivo
- [ ] DONE.md criado
EOF
}

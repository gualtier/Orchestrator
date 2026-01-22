#!/bin/bash

# ===========================================
# 🤖 ORQUESTRADOR DE AGENTES CLAUDE v3.0
#    Com Agentes Especializados
# ===========================================

set -eo pipefail

# =============================================
# CONFIGURAÇÃO
# =============================================

PROJECT_ROOT=$(pwd)
PROJECT_NAME=$(basename "$PROJECT_ROOT")
CLAUDE_DIR="$PROJECT_ROOT/.claude"
ORCHESTRATION_DIR="$CLAUDE_DIR/orchestration"
AGENTS_DIR="$CLAUDE_DIR/agents"
MEMORY_FILE="$CLAUDE_DIR/PROJECT_MEMORY.md"
STATE_FILE="$ORCHESTRATION_DIR/.state.json"
EVENTS_FILE="$ORCHESTRATION_DIR/EVENTS.md"
AGENTS_SCRIPT="$CLAUDE_DIR/scripts/agents.sh"

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
GRAY='\033[0;90m'
NC='\033[0m'
BOLD='\033[1m'

# Logging
timestamp() { date '+%Y-%m-%d %H:%M:%S'; }
log_info() { echo -e "${BLUE}[$(timestamp)]${NC} $1"; }
log_success() { echo -e "${GREEN}[$(timestamp)] ✓${NC} $1"; }
log_warn() { echo -e "${YELLOW}[$(timestamp)] ⚠${NC} $1"; }
log_error() { echo -e "${RED}[$(timestamp)] ✗${NC} $1"; }
log_step() { echo -e "${MAGENTA}[$(timestamp)] ▶${NC} $1"; }

# =============================================
# PRESETS DE AGENTES (função para compatibilidade)
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

# =============================================
# UTILIDADES
# =============================================

ensure_dir() { mkdir -p "$1"; }
file_exists() { [[ -f "$1" ]]; }
dir_exists() { [[ -d "$1" ]]; }

is_git_clean() {
    git diff --quiet HEAD 2>/dev/null && git diff --cached --quiet HEAD 2>/dev/null
}

current_branch() {
    git branch --show-current 2>/dev/null || echo "main"
}

# =============================================
# INICIALIZAÇÃO
# =============================================

init_orchestration() {
    log_step "Inicializando orquestrador v3 com agentes especializados..."
    
    # Criar estrutura
    ensure_dir "$ORCHESTRATION_DIR"/{tasks,status,logs,pids,archive,checkpoints,.recovery}
    ensure_dir "$AGENTS_DIR"
    ensure_dir "$CLAUDE_DIR/scripts"
    
    # Criar AGENT_CLAUDE.md base
    create_agent_claude_base
    
    # Criar PROJECT_MEMORY.md
    if ! file_exists "$MEMORY_FILE"; then
        create_initial_memory
    fi
    
    # Inicializar arquivos
    touch "$EVENTS_FILE"
    
    log_success "Estrutura criada!"
    
    # Mostrar próximos passos
    echo ""
    echo -e "${CYAN}Próximos passos:${NC}"
    echo ""
    echo "  1. Instalar agentes especializados:"
    echo "     ${GREEN}.claude/scripts/agents.sh list${NC}              # Ver disponíveis"
    echo "     ${GREEN}.claude/scripts/agents.sh install-preset api${NC} # Instalar preset"
    echo ""
    echo "  2. Criar worktrees com agentes:"
    echo "     ${GREEN}$0 setup auth --preset auth${NC}"
    echo "     ${GREEN}$0 setup api --agents api-designer,backend-developer${NC}"
    echo ""
    echo "  3. Iniciar agentes:"
    echo "     ${GREEN}$0 start${NC}"
}

create_agent_claude_base() {
    cat > "$CLAUDE_DIR/AGENT_CLAUDE_BASE.md" << 'EOF'
# 🤖 AGENTE EXECUTOR

⛔ **VOCÊ NÃO É UM ORQUESTRADOR** ⛔

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
## Concluído
- [x] Item
## Pendente
- [ ] Item
## Última Atualização
[DATA]: [descrição]
```

### DONE.md (ao finalizar)
```markdown
# ✅ Concluído: [tarefa]
## Resumo
[O que foi feito]
## Arquivos
- path/file.ts - [mudança]
## Testes
[Como testar]
```

### BLOCKED.md (se necessário)
```markdown
# 🚫 Bloqueado: [tarefa]
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
    cat > "$MEMORY_FILE" << EOF
# 🧠 Project Memory v3

> **Última atualização**: $current_date
> **Versão do Orquestrador**: 3.0 (com agentes especializados)

## 📋 Visão Geral

### Projeto
- **Nome**: $PROJECT_NAME
- **Início**: $(date '+%Y-%m-%d')
- **Repo**: $(git remote get-url origin 2>/dev/null || echo "[local]")

### Stack
| Camada | Tecnologia |
|--------|------------|
| Linguagem | [DEFINIR] |
| Framework | [DEFINIR] |
| Database | [DEFINIR] |

## 🗺️ Roadmap

### ✅ Concluído
- [x] Inicialização do projeto

### 🔄 Em Progresso
_Nenhum_

### 📅 Planejado
_A definir_

## 🤖 Agentes Utilizados

| Orquestração | Data | Agentes |
|--------------|------|---------|
| #0 | $current_date | init |

## 📊 Orquestrações

| # | Data | Tipo | Worktrees | Agentes | Status |
|---|------|------|-----------|---------|--------|
| 0 | $current_date | Init | - | - | ✅ |

## 🎯 Próxima Sessão

### Prioridade
1. Definir stack e roadmap
2. Instalar agentes especializados

### Notas
_Projeto recém inicializado._

---
> 💡 Atualize com: \`.claude/scripts/orchestrate.sh update-memory\`
EOF
}

# =============================================
# WORKTREES COM AGENTES
# =============================================

# Função para baixar agente do repositório VoltAgent
download_agent() {
    local name=$1
    local agents_repo="https://raw.githubusercontent.com/VoltAgent/awesome-claude-code-subagents/main"
    
    # Obter path do agente
    local path=""
    case "$name" in
        # Core Development
        api-designer) path="categories/01-core-development/api-designer.md" ;;
        backend-developer) path="categories/01-core-development/backend-developer.md" ;;
        frontend-developer) path="categories/01-core-development/frontend-developer.md" ;;
        fullstack-developer) path="categories/01-core-development/fullstack-developer.md" ;;
        mobile-developer) path="categories/01-core-development/mobile-developer.md" ;;
        microservices-architect) path="categories/01-core-development/microservices-architect.md" ;;
        ui-designer) path="categories/01-core-development/ui-designer.md" ;;
        
        # Language Specialists
        typescript-pro) path="categories/02-language-specialists/typescript-pro.md" ;;
        javascript-pro) path="categories/02-language-specialists/javascript-pro.md" ;;
        python-pro) path="categories/02-language-specialists/python-pro.md" ;;
        golang-pro) path="categories/02-language-specialists/golang-pro.md" ;;
        rust-engineer) path="categories/02-language-specialists/rust-engineer.md" ;;
        java-architect) path="categories/02-language-specialists/java-architect.md" ;;
        react-specialist) path="categories/02-language-specialists/react-specialist.md" ;;
        vue-expert) path="categories/02-language-specialists/vue-expert.md" ;;
        nextjs-developer) path="categories/02-language-specialists/nextjs-developer.md" ;;
        django-developer) path="categories/02-language-specialists/django-developer.md" ;;
        flutter-expert) path="categories/02-language-specialists/flutter-expert.md" ;;
        sql-pro) path="categories/02-language-specialists/sql-pro.md" ;;
        
        # Infrastructure
        devops-engineer) path="categories/03-infrastructure/devops-engineer.md" ;;
        cloud-architect) path="categories/03-infrastructure/cloud-architect.md" ;;
        kubernetes-specialist) path="categories/03-infrastructure/kubernetes-specialist.md" ;;
        terraform-engineer) path="categories/03-infrastructure/terraform-engineer.md" ;;
        database-administrator) path="categories/03-infrastructure/database-administrator.md" ;;
        security-engineer) path="categories/03-infrastructure/security-engineer.md" ;;
        sre-engineer) path="categories/03-infrastructure/sre-engineer.md" ;;
        deployment-engineer) path="categories/03-infrastructure/deployment-engineer.md" ;;
        
        # Quality & Security
        code-reviewer) path="categories/04-quality-security/code-reviewer.md" ;;
        security-auditor) path="categories/04-quality-security/security-auditor.md" ;;
        qa-expert) path="categories/04-quality-security/qa-expert.md" ;;
        test-automator) path="categories/04-quality-security/test-automator.md" ;;
        performance-engineer) path="categories/04-quality-security/performance-engineer.md" ;;
        debugger) path="categories/04-quality-security/debugger.md" ;;
        penetration-tester) path="categories/04-quality-security/penetration-tester.md" ;;
        architect-reviewer) path="categories/04-quality-security/architect-reviewer.md" ;;
        
        # Data & AI
        data-engineer) path="categories/05-data-ai/data-engineer.md" ;;
        data-scientist) path="categories/05-data-ai/data-scientist.md" ;;
        ml-engineer) path="categories/05-data-ai/ml-engineer.md" ;;
        ai-engineer) path="categories/05-data-ai/ai-engineer.md" ;;
        llm-architect) path="categories/05-data-ai/llm-architect.md" ;;
        mlops-engineer) path="categories/05-data-ai/mlops-engineer.md" ;;
        prompt-engineer) path="categories/05-data-ai/prompt-engineer.md" ;;
        postgres-pro) path="categories/05-data-ai/postgres-pro.md" ;;
        
        # Developer Experience
        documentation-engineer) path="categories/06-developer-experience/documentation-engineer.md" ;;
        refactoring-specialist) path="categories/06-developer-experience/refactoring-specialist.md" ;;
        legacy-modernizer) path="categories/06-developer-experience/legacy-modernizer.md" ;;
        
        # Specialized
        blockchain-developer) path="categories/07-specialized-domains/blockchain-developer.md" ;;
        fintech-engineer) path="categories/07-specialized-domains/fintech-engineer.md" ;;
        payment-integration) path="categories/07-specialized-domains/payment-integration.md" ;;
        
        # Business
        product-manager) path="categories/08-business-product/product-manager.md" ;;
        technical-writer) path="categories/08-business-product/technical-writer.md" ;;
        business-analyst) path="categories/08-business-product/business-analyst.md" ;;
        
        *) path="" ;;
    esac
    
    if [[ -z "$path" ]]; then
        log_warn "Agente desconhecido: $name"
        return 1
    fi
    
    local url="$agents_repo/$path"
    local dest="$AGENTS_DIR/$name.md"
    
    ensure_dir "$AGENTS_DIR"
    
    if curl -sL "$url" -o "$dest" 2>/dev/null && [[ -s "$dest" ]]; then
        log_success "  ↓ Agente baixado: $name"
        return 0
    else
        log_warn "  ✗ Falha ao baixar: $name"
        rm -f "$dest"
        return 1
    fi
}

# Garantir que agentes estão instalados (baixa se não existir)
ensure_agents_installed() {
    local agents="$1"
    
    for agent in $agents; do
        local src="$AGENTS_DIR/$agent.md"
        if [[ ! -f "$src" ]]; then
            log_info "Agente não encontrado localmente, baixando: $agent"
            download_agent "$agent"
        fi
    done
}

create_worktree() {
    local name=$1
    shift
    
    local preset=""
    local agents_list=""
    
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
            *)
                shift
                ;;
        esac
    done
    
    local base_branch=$(current_branch)
    local branch="feature/$name"
    local worktree_path="../${PROJECT_NAME}-$name"
    
    # Determinar agentes a usar ANTES de criar worktree
    local agents_to_copy=""
    
    if [[ -n "$preset" ]]; then
        agents_to_copy=$(get_preset_agents "$preset")
        if [[ -z "$agents_to_copy" ]]; then
            log_warn "Preset não encontrado: $preset"
        else
            log_info "Preset '$preset': $agents_to_copy"
        fi
    fi
    
    if [[ -n "$agents_list" ]]; then
        agents_to_copy=$(echo "$agents_list" | tr ',' ' ')
        log_info "Agentes especificados: $agents_to_copy"
    fi
    
    # AUTOMÁTICO: Baixar agentes que não existem
    if [[ -n "$agents_to_copy" ]]; then
        log_step "Verificando/instalando agentes..."
        ensure_agents_installed "$agents_to_copy"
    fi
    
    log_step "Criando worktree: $name"
    
    # Criar branch e worktree
    git branch "$branch" "$base_branch" 2>/dev/null || true
    
    if dir_exists "$worktree_path"; then
        log_warn "Worktree já existe: $worktree_path"
    else
        git worktree add "$worktree_path" "$branch"
        
        # Copiar dependências
        [[ -d "node_modules" ]] && cp -r node_modules "$worktree_path/" 2>/dev/null || true
        [[ -f ".env" ]] && cp .env* "$worktree_path/" 2>/dev/null || true
        
        # Criar estrutura de agentes no worktree
        ensure_dir "$worktree_path/.claude/agents"
        
        # Copiar CLAUDE.md base para o worktree
        if [[ -f "$CLAUDE_DIR/AGENT_CLAUDE_BASE.md" ]]; then
            cp "$CLAUDE_DIR/AGENT_CLAUDE_BASE.md" "$worktree_path/CLAUDE.md"
        fi
        
        log_success "Worktree criado: $worktree_path"
    fi
    
    # Copiar agentes para worktree
    if [[ -n "$agents_to_copy" ]]; then
        log_step "Copiando agentes para worktree..."
        for agent in $agents_to_copy; do
            local src="$AGENTS_DIR/$agent.md"
            if [[ -f "$src" ]]; then
                cp "$src" "$worktree_path/.claude/agents/"
                log_success "  → $agent"
            else
                log_warn "  ✗ $agent (não disponível)"
            fi
        done
        
        # Salvar quais agentes foram usados
        echo "$agents_to_copy" > "$worktree_path/.claude/AGENTS_USED"
    fi
    
    echo ""
    log_success "Worktree '$name' pronto com agentes: $agents_to_copy"
}

# =============================================
# EXECUÇÃO DE AGENTES
# =============================================

start_agent() {
    local name=$1
    local task_file="$ORCHESTRATION_DIR/tasks/$name.md"
    local worktree_path="../${PROJECT_NAME}-$name"
    local logfile="$ORCHESTRATION_DIR/logs/$name.log"
    local pidfile="$ORCHESTRATION_DIR/pids/$name.pid"
    local start_time_file="$ORCHESTRATION_DIR/pids/$name.started"
    
    # Validações
    if ! file_exists "$task_file"; then
        log_error "Tarefa não encontrada: $task_file"
        return 1
    fi
    
    if ! dir_exists "$worktree_path"; then
        log_error "Worktree não encontrado: $worktree_path"
        return 1
    fi
    
    # Verificar se já rodando
    if file_exists "$pidfile"; then
        local old_pid=$(cat "$pidfile")
        if kill -0 "$old_pid" 2>/dev/null; then
            log_warn "Agente $name já rodando (PID: $old_pid)"
            return 0
        fi
    fi
    
    # Carregar tarefa
    local task=$(cat "$task_file")
    
    # Carregar contexto do projeto
    local project_context=""
    if file_exists "$MEMORY_FILE"; then
        project_context=$(head -100 "$MEMORY_FILE")
    fi
    
    # Listar agentes especializados disponíveis
    local specialized_agents=""
    if dir_exists "$worktree_path/.claude/agents"; then
        specialized_agents=$(ls "$worktree_path/.claude/agents"/*.md 2>/dev/null | xargs -I {} basename {} .md | tr '\n' ', ' || echo "nenhum")
    fi
    
    log_info "Iniciando agente: $name"
    log_info "  Agentes especializados: $specialized_agents"
    
    # Prompt completo
    local full_prompt="
⛔⛔⛔ VOCÊ É UM AGENTE EXECUTOR - NÃO ORQUESTRADOR ⛔⛔⛔

REGRAS:
- NÃO crie worktrees
- NÃO execute orchestrate.sh  
- NÃO crie outros agentes
- FOQUE apenas na tarefa abaixo

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🤖 AGENTES ESPECIALIZADOS DISPONÍVEIS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Você tem acesso aos seguintes agentes especializados em .claude/agents/:
$specialized_agents

Consulte esses arquivos para obter expertise especializada na sua tarefa.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋 SUA TAREFA
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

$task

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📂 CONTEXTO DO PROJETO
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

$project_context

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📝 INSTRUÇÕES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. LEIA os agentes especializados em .claude/agents/ para expertise
2. CRIE PROGRESS.md agora
3. EXECUTE a tarefa usando as melhores práticas dos agentes
4. ATUALIZE PROGRESS.md a cada passo
5. FAÇA COMMITS: git commit -m 'feat($name): desc'
6. CRIE DONE.md quando terminar

COMECE AGORA!"

    # Executar
    ensure_dir "$ORCHESTRATION_DIR/pids"
    nohup claude -p "$full_prompt" --workdir "$worktree_path" > "$logfile" 2>&1 &
    
    local pid=$!
    echo $pid > "$pidfile"
    echo $(date '+%s') > "$start_time_file"
    
    # Registrar evento
    echo "[$(timestamp)] STARTED: $name (PID: $pid) [agents: $specialized_agents]" >> "$EVENTS_FILE"
    
    log_success "Agente $name iniciado (PID: $pid)"
}

stop_agent() {
    local name=$1
    local pidfile="$ORCHESTRATION_DIR/pids/$name.pid"
    
    if file_exists "$pidfile"; then
        local pid=$(cat "$pidfile")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
            sleep 1
            kill -9 "$pid" 2>/dev/null || true
            log_success "Agente $name parado"
        fi
        rm -f "$pidfile" "$ORCHESTRATION_DIR/pids/$name.started"
    else
        log_warn "Agente $name não está rodando"
    fi
}

# =============================================
# MONITORAMENTO
# =============================================

check_status() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║           ORQUESTRADOR v3 - STATUS - $(date '+%H:%M:%S')                       ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    
    local total=0 done=0 blocked=0 running=0 waiting=0
    
    for task_file in "$ORCHESTRATION_DIR/tasks"/*.md; do
        [[ -f "$task_file" ]] || continue
        
        local name=$(basename "$task_file" .md)
        local worktree_path="../${PROJECT_NAME}-$name"
        local pidfile="$ORCHESTRATION_DIR/pids/$name.pid"
        local start_time_file="$ORCHESTRATION_DIR/pids/$name.started"
        
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
        
        if file_exists "$pidfile"; then
            local pid=$(cat "$pidfile")
            if kill -0 "$pid" 2>/dev/null; then
                proc_status="${GREEN}🟢 Rodando (PID: $pid)${NC}"
                
                if file_exists "$start_time_file"; then
                    local start_ts=$(cat "$start_time_file")
                    local now_ts=$(date '+%s')
                    local diff=$((now_ts - start_ts))
                    local mins=$((diff / 60))
                    local secs=$((diff % 60))
                    elapsed=" [${mins}m ${secs}s]"
                fi
            fi
        fi
        echo -e "│ Processo: $proc_status$elapsed"
        
        # Status da tarefa
        if file_exists "$worktree_path/DONE.md"; then
            echo -e "│ Tarefa: ${GREEN}✅ CONCLUÍDA${NC}"
            ((done++))
        elif file_exists "$worktree_path/BLOCKED.md"; then
            echo -e "│ Tarefa: ${RED}🚫 BLOQUEADA${NC}"
            ((blocked++))
        elif file_exists "$worktree_path/PROGRESS.md"; then
            echo -e "│ Tarefa: ${BLUE}🔄 EM PROGRESSO${NC}"
            ((running++))
            
            # Progresso
            local done_items=$(grep -c "\- \[x\]" "$worktree_path/PROGRESS.md" 2>/dev/null || echo 0)
            local total_items=$(grep -c "\- \[" "$worktree_path/PROGRESS.md" 2>/dev/null || echo 0)
            if [[ $total_items -gt 0 ]]; then
                local pct=$((done_items * 100 / total_items))
                echo -e "│   Progresso: ${done_items}/${total_items} (${pct}%)"
            fi
        else
            echo -e "│ Tarefa: ${YELLOW}⏳ AGUARDANDO${NC}"
            ((waiting++))
        fi
        
        # Último commit
        if dir_exists "$worktree_path"; then
            local commit=$(cd "$worktree_path" && git log --oneline -1 2>/dev/null || echo "nenhum")
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
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "📊 Total: $total | ✅ $done | 🔄 $running | ⏳ $waiting | 🚫 $blocked"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    if [[ $done -eq $total ]] && [[ $total -gt 0 ]]; then
        echo ""
        echo -e "${GREEN}🎉 TODOS OS AGENTES CONCLUÍRAM!${NC}"
        return 0
    fi
    
    return 1
}

wait_for_completion() {
    log_info "Aguardando agentes terminarem..."
    
    while true; do
        if check_status; then
            return 0
        fi
        echo ""
        log_info "Próxima verificação em 30s... (Ctrl+C para sair)"
        sleep 30
    done
}

show_logs() {
    local name=$1
    local lines=${2:-50}
    
    if [[ -z "$name" ]]; then
        echo "Uso: $0 logs <agente> [linhas]"
        return 1
    fi
    
    local logfile="$ORCHESTRATION_DIR/logs/$name.log"
    
    if file_exists "$logfile"; then
        tail -"$lines" "$logfile"
    else
        log_error "Log não encontrado: $logfile"
    fi
}

follow_logs() {
    local name=$1
    
    if [[ -z "$name" ]]; then
        echo "Uso: $0 follow <agente>"
        return 1
    fi
    
    tail -f "$ORCHESTRATION_DIR/logs/$name.log"
}

# =============================================
# MERGE E FINALIZAÇÃO
# =============================================

merge_all() {
    local target=${1:-main}
    
    log_step "Iniciando merge para: $target"
    
    # Verificar conclusão
    for task_file in "$ORCHESTRATION_DIR/tasks"/*.md; do
        [[ -f "$task_file" ]] || continue
        local name=$(basename "$task_file" .md)
        local worktree_path="../${PROJECT_NAME}-$name"
        
        if ! file_exists "$worktree_path/DONE.md"; then
            log_error "Agente $name não terminou!"
            return 1
        fi
    done
    
    git checkout "$target" || { log_error "Falha ao mudar para $target"; return 1; }
    git pull origin "$target" 2>/dev/null || true
    
    local merged=0
    
    for task_file in "$ORCHESTRATION_DIR/tasks"/*.md; do
        [[ -f "$task_file" ]] || continue
        local name=$(basename "$task_file" .md)
        local branch="feature/$name"
        
        log_info "Merging $branch..."
        
        if git merge "$branch" -m "feat: merge $name"; then
            log_success "$branch merged"
            ((merged++))
        else
            log_error "Conflito em $branch!"
            echo "Resolva manualmente e continue"
            return 1
        fi
    done
    
    log_success "✨ Merge completo! ($merged branches)"
}

cleanup() {
    log_step "Limpando worktrees..."
    
    local archive_dir="$ORCHESTRATION_DIR/archive/$(date '+%Y%m%d_%H%M%S')"
    ensure_dir "$archive_dir"
    
    for task_file in "$ORCHESTRATION_DIR/tasks"/*.md; do
        [[ -f "$task_file" ]] || continue
        
        local name=$(basename "$task_file" .md)
        local worktree_path="../${PROJECT_NAME}-$name"
        
        stop_agent "$name" 2>/dev/null || true
        
        # Arquivar
        cp "$worktree_path/DONE.md" "$archive_dir/${name}_DONE.md" 2>/dev/null || true
        cp "$worktree_path/PROGRESS.md" "$archive_dir/${name}_PROGRESS.md" 2>/dev/null || true
        cp "$worktree_path/.claude/AGENTS_USED" "$archive_dir/${name}_AGENTS.txt" 2>/dev/null || true
        
        git worktree remove "$worktree_path" --force 2>/dev/null && \
            log_success "Removido: $worktree_path"
        
        mv "$task_file" "$archive_dir/"
    done
    
    rm -f "$ORCHESTRATION_DIR/logs"/*.log
    rm -f "$ORCHESTRATION_DIR/pids"/*
    
    log_success "Cleanup completo!"
}

# =============================================
# MEMÓRIA
# =============================================

show_memory() {
    if file_exists "$MEMORY_FILE"; then
        cat "$MEMORY_FILE"
    else
        log_error "PROJECT_MEMORY.md não encontrado"
    fi
}

update_memory() {
    log_step "Atualizando memória..."
    
    local current_date=$(date '+%Y-%m-%d %H:%M')
    sed -i.bak "s/> \*\*Última atualização\*\*:.*/> **Última atualização**: $current_date/" "$MEMORY_FILE"
    rm -f "${MEMORY_FILE}.bak"
    
    log_success "Memória atualizada"
}

# =============================================
# HELP
# =============================================

show_help() {
    cat << 'EOF'

🤖 ORQUESTRADOR DE AGENTES CLAUDE v3.0
   Com Agentes Especializados

Uso: orchestrate.sh <comando> [argumentos]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

AGENTES ESPECIALIZADOS:
  agents list               Listar agentes disponíveis
  agents install <agente>   Instalar agente
  agents install-preset <p> Instalar preset de agentes
  agents installed          Ver agentes instalados

INICIALIZAÇÃO:
  init                      Criar estrutura
  
EXECUÇÃO:
  setup <nome> [opções]     Criar worktree com agentes
    --preset <preset>       Usar preset de agentes
    --agents <a1,a2,a3>     Especificar agentes
  
  start [agentes]           Iniciar agentes
  stop <agente>             Parar agente
  restart <agente>          Reiniciar agente

MONITORAMENTO:
  status                    Ver status
  wait                      Aguardar conclusão
  logs <agente> [n]         Ver logs
  follow <agente>           Seguir logs

FINALIZAÇÃO:
  merge [branch]            Fazer merge
  cleanup                   Limpar worktrees

MEMÓRIA:
  show-memory               Ver memória
  update-memory             Atualizar memória

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

PRESETS DE AGENTES:
  auth      → backend-developer, security-auditor, typescript-pro
  api       → api-designer, backend-developer, test-automator
  frontend  → frontend-developer, react-specialist, ui-designer
  fullstack → fullstack-developer, typescript-pro, test-automator
  mobile    → mobile-developer, flutter-expert, ui-designer
  devops    → devops-engineer, kubernetes-specialist, terraform-engineer
  data      → data-engineer, data-scientist, postgres-pro
  ml        → ml-engineer, ai-engineer, mlops-engineer
  security  → security-auditor, penetration-tester, security-engineer
  review    → code-reviewer, architect-reviewer, security-auditor

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

EXEMPLO COMPLETO:

  # 1. Inicializar
  ./orchestrate.sh init
  
  # 2. Instalar agentes
  .claude/scripts/agents.sh install-preset auth
  .claude/scripts/agents.sh install-preset api
  
  # 3. Criar worktrees com agentes especializados
  ./orchestrate.sh setup auth --preset auth
  ./orchestrate.sh setup api --preset api
  
  # 4. Criar tarefas em .claude/orchestration/tasks/
  
  # 5. Iniciar
  ./orchestrate.sh start
  
  # 6. Monitorar
  ./orchestrate.sh wait
  
  # 7. Finalizar
  ./orchestrate.sh merge
  ./orchestrate.sh cleanup

EOF
}

# =============================================
# MAIN
# =============================================

main() {
    local cmd=${1:-"help"}
    shift || true
    
    case "$cmd" in
        # Agentes
        agents)
            if file_exists "$AGENTS_SCRIPT"; then
                "$AGENTS_SCRIPT" "$@"
            else
                log_error "Script de agentes não encontrado"
                log_info "Execute: $0 init"
            fi
            ;;
        
        # Inicialização
        init) init_orchestration ;;
        
        # Execução
        setup)
            [[ -z "${1:-}" ]] && { log_error "Especifique o nome"; exit 1; }
            create_worktree "$@"
            ;;
        start)
            if [[ -z "${1:-}" ]]; then
                for tf in "$ORCHESTRATION_DIR/tasks"/*.md; do
                    [[ -f "$tf" ]] || continue
                    start_agent "$(basename "$tf" .md)"
                    sleep 2
                done
            else
                for name in "$@"; do start_agent "$name"; sleep 2; done
            fi
            ;;
        stop) stop_agent "$1" ;;
        restart) stop_agent "$1"; sleep 2; start_agent "$1" ;;
        
        # Monitoramento
        status) check_status ;;
        wait) wait_for_completion ;;
        logs) show_logs "$@" ;;
        follow) follow_logs "$1" ;;
        
        # Finalização
        merge) merge_all "$@" ;;
        cleanup) cleanup ;;
        
        # Memória
        show-memory) show_memory ;;
        update-memory) update_memory ;;
        
        # Help
        help|--help|-h) show_help ;;
        
        *)
            log_error "Comando desconhecido: $cmd"
            show_help
            exit 1
            ;;
    esac
}

main "$@"

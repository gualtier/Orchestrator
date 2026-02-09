#!/bin/bash

# ===========================================
# 🤖 GERENCIADOR DE AGENTES ESPECIALIZADOS
#    Integration with VoltAgent/awesome-claude-code-subagents
# ===========================================

set -eo pipefail

CLAUDE_DIR=".claude"
AGENTS_DIR="$CLAUDE_DIR/agents"
AGENTS_REPO="https://raw.githubusercontent.com/VoltAgent/awesome-claude-code-subagents/main"

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ===========================================
# AGENT CATALOG (using function)
# ===========================================

get_agent_path() {
    local name="$1"
    case "$name" in
        # Core Development
        api-designer) echo "categories/01-core-development/api-designer.md" ;;
        backend-developer) echo "categories/01-core-development/backend-developer.md" ;;
        frontend-developer) echo "categories/01-core-development/frontend-developer.md" ;;
        fullstack-developer) echo "categories/01-core-development/fullstack-developer.md" ;;
        mobile-developer) echo "categories/01-core-development/mobile-developer.md" ;;
        microservices-architect) echo "categories/01-core-development/microservices-architect.md" ;;
        graphql-architect) echo "categories/01-core-development/graphql-architect.md" ;;
        websocket-engineer) echo "categories/01-core-development/websocket-engineer.md" ;;
        ui-designer) echo "categories/01-core-development/ui-designer.md" ;;
        
        # Language Specialists
        typescript-pro) echo "categories/02-language-specialists/typescript-pro.md" ;;
        javascript-pro) echo "categories/02-language-specialists/javascript-pro.md" ;;
        python-pro) echo "categories/02-language-specialists/python-pro.md" ;;
        golang-pro) echo "categories/02-language-specialists/golang-pro.md" ;;
        rust-engineer) echo "categories/02-language-specialists/rust-engineer.md" ;;
        java-architect) echo "categories/02-language-specialists/java-architect.md" ;;
        csharp-developer) echo "categories/02-language-specialists/csharp-developer.md" ;;
        php-pro) echo "categories/02-language-specialists/php-pro.md" ;;
        react-specialist) echo "categories/02-language-specialists/react-specialist.md" ;;
        vue-expert) echo "categories/02-language-specialists/vue-expert.md" ;;
        angular-architect) echo "categories/02-language-specialists/angular-architect.md" ;;
        nextjs-developer) echo "categories/02-language-specialists/nextjs-developer.md" ;;
        django-developer) echo "categories/02-language-specialists/django-developer.md" ;;
        laravel-specialist) echo "categories/02-language-specialists/laravel-specialist.md" ;;
        spring-boot-engineer) echo "categories/02-language-specialists/spring-boot-engineer.md" ;;
        flutter-expert) echo "categories/02-language-specialists/flutter-expert.md" ;;
        swift-expert) echo "categories/02-language-specialists/swift-expert.md" ;;
        kotlin-specialist) echo "categories/02-language-specialists/kotlin-specialist.md" ;;
        sql-pro) echo "categories/02-language-specialists/sql-pro.md" ;;
        
        # Infrastructure
        devops-engineer) echo "categories/03-infrastructure/devops-engineer.md" ;;
        cloud-architect) echo "categories/03-infrastructure/cloud-architect.md" ;;
        kubernetes-specialist) echo "categories/03-infrastructure/kubernetes-specialist.md" ;;
        terraform-engineer) echo "categories/03-infrastructure/terraform-engineer.md" ;;
        database-administrator) echo "categories/03-infrastructure/database-administrator.md" ;;
        security-engineer) echo "categories/03-infrastructure/security-engineer.md" ;;
        sre-engineer) echo "categories/03-infrastructure/sre-engineer.md" ;;
        deployment-engineer) echo "categories/03-infrastructure/deployment-engineer.md" ;;
        network-engineer) echo "categories/03-infrastructure/network-engineer.md" ;;
        platform-engineer) echo "categories/03-infrastructure/platform-engineer.md" ;;
        
        # Quality & Security
        code-reviewer) echo "categories/04-quality-security/code-reviewer.md" ;;
        security-auditor) echo "categories/04-quality-security/security-auditor.md" ;;
        qa-expert) echo "categories/04-quality-security/qa-expert.md" ;;
        test-automator) echo "categories/04-quality-security/test-automator.md" ;;
        performance-engineer) echo "categories/04-quality-security/performance-engineer.md" ;;
        debugger) echo "categories/04-quality-security/debugger.md" ;;
        penetration-tester) echo "categories/04-quality-security/penetration-tester.md" ;;
        accessibility-tester) echo "categories/04-quality-security/accessibility-tester.md" ;;
        architect-reviewer) echo "categories/04-quality-security/architect-reviewer.md" ;;
        
        # Data & AI
        data-engineer) echo "categories/05-data-ai/data-engineer.md" ;;
        data-scientist) echo "categories/05-data-ai/data-scientist.md" ;;
        ml-engineer) echo "categories/05-data-ai/ml-engineer.md" ;;
        ai-engineer) echo "categories/05-data-ai/ai-engineer.md" ;;
        llm-architect) echo "categories/05-data-ai/llm-architect.md" ;;
        mlops-engineer) echo "categories/05-data-ai/mlops-engineer.md" ;;
        prompt-engineer) echo "categories/05-data-ai/prompt-engineer.md" ;;
        postgres-pro) echo "categories/05-data-ai/postgres-pro.md" ;;
        
        # Developer Experience
        documentation-engineer) echo "categories/06-developer-experience/documentation-engineer.md" ;;
        refactoring-specialist) echo "categories/06-developer-experience/refactoring-specialist.md" ;;
        legacy-modernizer) echo "categories/06-developer-experience/legacy-modernizer.md" ;;
        cli-developer) echo "categories/06-developer-experience/cli-developer.md" ;;
        build-engineer) echo "categories/06-developer-experience/build-engineer.md" ;;
        git-workflow-manager) echo "categories/06-developer-experience/git-workflow-manager.md" ;;
        
        # Specialized Domains
        blockchain-developer) echo "categories/07-specialized-domains/blockchain-developer.md" ;;
        game-developer) echo "categories/07-specialized-domains/game-developer.md" ;;
        iot-engineer) echo "categories/07-specialized-domains/iot-engineer.md" ;;
        fintech-engineer) echo "categories/07-specialized-domains/fintech-engineer.md" ;;
        payment-integration) echo "categories/07-specialized-domains/payment-integration.md" ;;
        
        # Business & Product
        product-manager) echo "categories/08-business-product/product-manager.md" ;;
        technical-writer) echo "categories/08-business-product/technical-writer.md" ;;
        business-analyst) echo "categories/08-business-product/business-analyst.md" ;;
        scrum-master) echo "categories/08-business-product/scrum-master.md" ;;
        
        # Meta & Orchestration
        workflow-orchestrator) echo "categories/09-meta-orchestration/workflow-orchestrator.md" ;;
        multi-agent-coordinator) echo "categories/09-meta-orchestration/multi-agent-coordinator.md" ;;
        task-distributor) echo "categories/09-meta-orchestration/task-distributor.md" ;;
        
        # Research & Analysis
        research-analyst) echo "categories/10-research-analysis/research-analyst.md" ;;
        data-researcher) echo "categories/10-research-analysis/data-researcher.md" ;;
        
        *) echo "" ;;
    esac
}

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

# ===========================================
# FUNCTIONS
# ===========================================

ensure_dir() {
    mkdir -p "$1"
}

download_agent() {
    local name=$1
    local path=$(get_agent_path "$name")
    
    if [[ -z "$path" ]]; then
        log_error "Agente não encontrado: $name"
        return 1
    fi
    
    local url="$AGENTS_REPO/$path"
    local dest="$AGENTS_DIR/$name.md"
    
    ensure_dir "$AGENTS_DIR"
    
    log_info "Baixando: $name"
    
    if curl -sL "$url" -o "$dest" 2>/dev/null; then
        if [[ -s "$dest" ]]; then
            log_success "Agente instalado: $dest"
            return 0
        else
            log_error "Arquivo vazio - agente pode não existir: $name"
            rm -f "$dest"
            return 1
        fi
    else
        log_error "Falha ao baixar: $name"
        return 1
    fi
}

download_preset() {
    local preset=$1
    local agents=$(get_preset_agents "$preset")
    
    if [[ -z "$agents" ]]; then
        log_error "Preset não encontrado: $preset"
        echo ""
        echo "Presets disponíveis:"
        echo "  auth, api, frontend, fullstack, mobile"
        echo "  devops, data, ml, security, review"
        return 1
    fi
    
    log_info "Instalando preset '$preset': $agents"
    
    for agent in $agents; do
        download_agent "$agent"
    done
}

list_agents() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║              AGENTES ESPECIALIZADOS DISPONÍVEIS                  ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
    
    echo ""
    echo -e "${YELLOW}📦 PRESETS (conjuntos prontos):${NC}"
    echo ""
    echo -e "  ${GREEN}auth${NC}      → backend-developer, security-auditor, typescript-pro"
    echo -e "  ${GREEN}api${NC}       → api-designer, backend-developer, test-automator"
    echo -e "  ${GREEN}frontend${NC}  → frontend-developer, react-specialist, ui-designer"
    echo -e "  ${GREEN}fullstack${NC} → fullstack-developer, typescript-pro, test-automator"
    echo -e "  ${GREEN}mobile${NC}    → mobile-developer, flutter-expert, ui-designer"
    echo -e "  ${GREEN}devops${NC}    → devops-engineer, kubernetes-specialist, terraform-engineer"
    echo -e "  ${GREEN}data${NC}      → data-engineer, data-scientist, postgres-pro"
    echo -e "  ${GREEN}ml${NC}        → ml-engineer, ai-engineer, mlops-engineer"
    echo -e "  ${GREEN}security${NC}  → security-auditor, penetration-tester, security-engineer"
    echo -e "  ${GREEN}review${NC}    → code-reviewer, architect-reviewer, security-auditor"
    
    echo ""
    echo -e "${YELLOW}🤖 AGENTES POR CATEGORIA:${NC}"
    
    echo ""
    echo -e "${BLUE}[core] Core Development:${NC}"
    echo "  api-designer, backend-developer, frontend-developer, fullstack-developer"
    echo "  mobile-developer, microservices-architect, graphql-architect, websocket-engineer"
    
    echo ""
    echo -e "${BLUE}[languages] Language Specialists:${NC}"
    echo "  typescript-pro, javascript-pro, python-pro, golang-pro, rust-engineer"
    echo "  java-architect, react-specialist, vue-expert, angular-architect, nextjs-developer"
    echo "  django-developer, laravel-specialist, spring-boot-engineer, flutter-expert"
    
    echo ""
    echo -e "${BLUE}[infrastructure] Infrastructure:${NC}"
    echo "  devops-engineer, cloud-architect, kubernetes-specialist, terraform-engineer"
    echo "  database-administrator, security-engineer, sre-engineer, deployment-engineer"
    
    echo ""
    echo -e "${BLUE}[quality] Quality & Security:${NC}"
    echo "  code-reviewer, security-auditor, qa-expert, test-automator"
    echo "  performance-engineer, debugger, penetration-tester, architect-reviewer"
    
    echo ""
    echo -e "${BLUE}[data-ai] Data & AI:${NC}"
    echo "  data-engineer, data-scientist, ml-engineer, ai-engineer"
    echo "  llm-architect, mlops-engineer, prompt-engineer, postgres-pro"
    
    echo ""
    echo -e "${BLUE}[devex] Developer Experience:${NC}"
    echo "  documentation-engineer, refactoring-specialist, legacy-modernizer"
    echo "  cli-developer, build-engineer, git-workflow-manager"
    
    echo ""
    echo -e "${BLUE}[specialized] Specialized Domains:${NC}"
    echo "  blockchain-developer, game-developer, iot-engineer"
    echo "  fintech-engineer, payment-integration"
    
    echo ""
    echo -e "${YELLOW}Uso:${NC}"
    echo "  $0 install <agent>              # Install specific agent"
    echo "  $0 install-preset <preset>    # Instalar preset"
}

list_installed() {
    echo ""
    echo -e "${CYAN}Agentes instalados:${NC}"
    echo ""
    
    if [[ -d "$AGENTS_DIR" ]]; then
        local count=0
        for f in "$AGENTS_DIR"/*.md; do
            [[ -f "$f" ]] || continue
            local name=$(basename "$f" .md)
            echo "  ✓ $name"
            ((count++)) || true
        done
        
        if [[ $count -eq 0 ]]; then
            echo "  Nenhum agente instalado"
        else
            echo ""
            echo "  Total: $count agentes"
        fi
    else
        echo "  Nenhum agente instalado"
    fi
}

copy_agents_to_worktree() {
    local worktree_path=$1
    shift
    local agents=("$@")
    
    local dest="$worktree_path/.claude/agents"
    ensure_dir "$dest"
    
    for agent in "${agents[@]}"; do
        local src="$AGENTS_DIR/$agent.md"
        if [[ -f "$src" ]]; then
            cp "$src" "$dest/"
            log_info "Copiado $agent para $worktree_path"
        else
            log_warn "Agente não instalado: $agent (instale com: $0 install $agent)"
        fi
    done
}

show_help() {
    cat << 'EOF'

🤖 GERENCIADOR DE AGENTES ESPECIALIZADOS

Integração com VoltAgent/awesome-claude-code-subagents

Uso: agents.sh <comando> [argumentos]

COMANDOS:
  list                      Listar agentes disponíveis
  installed                 Listar agentes instalados
  install <agente>          Instalar agente específico
  install-preset <preset>   Instalar preset de agentes
  copy <worktree> <agents>  Copiar agentes para worktree

PRESETS DISPONÍVEIS:
  auth        → backend-developer, security-auditor, typescript-pro
  api         → api-designer, backend-developer, test-automator
  frontend    → frontend-developer, react-specialist, ui-designer
  fullstack   → fullstack-developer, typescript-pro, test-automator
  mobile      → mobile-developer, flutter-expert, ui-designer
  devops      → devops-engineer, kubernetes-specialist, terraform-engineer
  data        → data-engineer, data-scientist, postgres-pro
  ml          → ml-engineer, ai-engineer, mlops-engineer
  security    → security-auditor, penetration-tester, security-engineer
  review      → code-reviewer, architect-reviewer, security-auditor

EXEMPLOS:
  # Install preset for authentication module
  ./agents.sh install-preset auth

  # Install specific agents
  ./agents.sh install typescript-pro
  ./agents.sh install react-specialist

  # Copiar para worktree
  ./agents.sh copy ../meu-projeto-auth typescript-pro security-auditor

EOF
}

# ===========================================
# MAIN
# ===========================================

main() {
    local cmd=${1:-"help"}
    shift || true
    
    case "$cmd" in
        list)
            list_agents
            ;;
        installed)
            list_installed
            ;;
        install)
            if [[ -z "${1:-}" ]]; then
                log_error "Especifique o agente"
                exit 1
            fi
            for agent in "$@"; do
                download_agent "$agent"
            done
            ;;
        install-preset)
            if [[ -z "${1:-}" ]]; then
                log_error "Especifique o preset"
                exit 1
            fi
            download_preset "$1"
            ;;
        copy)
            local worktree=${1:-""}
            shift || true
            if [[ -z "$worktree" ]]; then
                log_error "Especifique o worktree"
                exit 1
            fi
            if [[ $# -eq 0 ]]; then
                log_error "Especifique os agentes"
                exit 1
            fi
            copy_agents_to_worktree "$worktree" "$@"
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "Comando desconhecido: $cmd"
            show_help
            exit 1
            ;;
    esac
}

main "$@"

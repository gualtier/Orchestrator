#!/bin/bash
# =============================================
# AGENTS - Gerenciamento de agentes
# =============================================

AGENTS_REPO="https://raw.githubusercontent.com/VoltAgent/awesome-claude-code-subagents/main"

# =============================================
# MAPEAMENTO DE AGENTES
# =============================================

get_agent_path() {
    local name=$1

    case "$name" in
        # Core Development
        api-designer) echo "categories/01-core-development/api-designer.md" ;;
        backend-developer) echo "categories/01-core-development/backend-developer.md" ;;
        frontend-developer) echo "categories/01-core-development/frontend-developer.md" ;;
        fullstack-developer) echo "categories/01-core-development/fullstack-developer.md" ;;
        mobile-developer) echo "categories/01-core-development/mobile-developer.md" ;;
        microservices-architect) echo "categories/01-core-development/microservices-architect.md" ;;
        ui-designer) echo "categories/01-core-development/ui-designer.md" ;;

        # Language Specialists
        typescript-pro) echo "categories/02-language-specialists/typescript-pro.md" ;;
        javascript-pro) echo "categories/02-language-specialists/javascript-pro.md" ;;
        python-pro) echo "categories/02-language-specialists/python-pro.md" ;;
        golang-pro) echo "categories/02-language-specialists/golang-pro.md" ;;
        rust-engineer) echo "categories/02-language-specialists/rust-engineer.md" ;;
        java-architect) echo "categories/02-language-specialists/java-architect.md" ;;
        react-specialist) echo "categories/02-language-specialists/react-specialist.md" ;;
        vue-expert) echo "categories/02-language-specialists/vue-expert.md" ;;
        nextjs-developer) echo "categories/02-language-specialists/nextjs-developer.md" ;;
        django-developer) echo "categories/02-language-specialists/django-developer.md" ;;
        flutter-expert) echo "categories/02-language-specialists/flutter-expert.md" ;;
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

        # Quality & Security
        code-reviewer) echo "categories/04-quality-security/code-reviewer.md" ;;
        security-auditor) echo "categories/04-quality-security/security-auditor.md" ;;
        qa-expert) echo "categories/04-quality-security/qa-expert.md" ;;
        test-automator) echo "categories/04-quality-security/test-automator.md" ;;
        performance-engineer) echo "categories/04-quality-security/performance-engineer.md" ;;
        debugger) echo "categories/04-quality-security/debugger.md" ;;
        penetration-tester) echo "categories/04-quality-security/penetration-tester.md" ;;
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

        # Specialized
        blockchain-developer) echo "categories/07-specialized-domains/blockchain-developer.md" ;;
        fintech-engineer) echo "categories/07-specialized-domains/fintech-engineer.md" ;;
        payment-integration) echo "categories/07-specialized-domains/payment-integration.md" ;;

        # Business
        product-manager) echo "categories/08-business-product/product-manager.md" ;;
        technical-writer) echo "categories/08-business-product/technical-writer.md" ;;
        business-analyst) echo "categories/08-business-product/business-analyst.md" ;;

        *) echo "" ;;
    esac
}

# =============================================
# DOWNLOAD DE AGENTES
# =============================================

download_agent() {
    local name=$1
    local path=$(get_agent_path "$name")

    if [[ -z "$path" ]]; then
        log_warn "Agente desconhecido: $name"
        return 1
    fi

    local url="$AGENTS_REPO/$path"
    local dest="$AGENTS_DIR/$name.md"

    ensure_dir "$AGENTS_DIR"

    if curl -sL "$url" -o "$dest" 2>/dev/null && [[ -s "$dest" ]]; then
        log_success "Agente baixado: $name"
        return 0
    else
        log_warn "Falha ao baixar: $name"
        rm -f "$dest"
        return 1
    fi
}

# Ensure agents are installed
ensure_agents_installed() {
    local agents="$1"
    local failed=0

    for agent in $agents; do
        if ! validate_name "$agent" "agente"; then
            ((failed++))
            continue
        fi

        local src="$AGENTS_DIR/$agent.md"
        if [[ ! -f "$src" ]] || [[ ! -s "$src" ]]; then
            log_info "Baixando agente: $agent"
            if ! download_agent "$agent"; then
                ((failed++))
            fi
        fi
    done

    return $failed
}

# List installed agents
list_installed_agents() {
    if [[ ! -d "$AGENTS_DIR" ]]; then
        echo ""
        return
    fi

    for file in "$AGENTS_DIR"/*.md; do
        [[ -f "$file" ]] || continue
        basename "$file" .md
    done
}

# Copiar agentes para worktree
copy_agents_to_worktree() {
    local worktree_path=$1
    local agents=$2

    local worktree_agents_dir="$worktree_path/.claude/agents"
    ensure_dir "$worktree_agents_dir"

    local copied=0
    for agent in $agents; do
        local src="$AGENTS_DIR/$agent.md"
        if file_exists "$src"; then
            cp "$src" "$worktree_agents_dir/"
            ((copied++))
        fi
    done

    # Save list of used agents
    echo "$agents" > "$worktree_path/.claude/AGENTS_USED"

    # Copiar AGENT_CLAUDE.md base
    if file_exists "$CLAUDE_DIR/AGENT_CLAUDE.md"; then
        cp "$CLAUDE_DIR/AGENT_CLAUDE.md" "$worktree_path/.claude/CLAUDE.md"
    fi

    return 0
}

# =============================================
# CLI DE AGENTES
# =============================================

cmd_agents() {
    local subcmd=${1:-list}
    shift || true

    case "$subcmd" in
        list)
            echo "Agentes disponíveis (VoltAgent):"
            echo ""
            echo "Core Development:"
            echo "  api-designer, backend-developer, frontend-developer"
            echo "  fullstack-developer, mobile-developer, ui-designer"
            echo ""
            echo "Language Specialists:"
            echo "  typescript-pro, javascript-pro, python-pro, golang-pro"
            echo "  rust-engineer, react-specialist, vue-expert, sql-pro"
            echo ""
            echo "Infrastructure:"
            echo "  devops-engineer, kubernetes-specialist, terraform-engineer"
            echo "  database-administrator, security-engineer"
            echo ""
            echo "Quality & Security:"
            echo "  code-reviewer, security-auditor, test-automator"
            echo "  penetration-tester, architect-reviewer"
            echo ""
            echo "Data & AI:"
            echo "  data-engineer, data-scientist, ml-engineer, postgres-pro"
            ;;

        installed)
            echo "Agentes instalados:"
            list_installed_agents | while read -r agent; do
                echo "  - $agent"
            done
            ;;

        install)
            local agent=$1
            if [[ -z "$agent" ]]; then
                log_error "Especifique o agente: $0 agents install <nome>"
                return 1
            fi
            download_agent "$agent"
            ;;

        install-preset)
            local preset=$1
            if ! validate_preset "$preset"; then
                return 1
            fi
            local agents=$(get_preset_agents "$preset")
            log_info "Instalando preset '$preset': $agents"
            ensure_agents_installed "$agents"
            ;;

        *)
            log_error "Subcomando desconhecido: $subcmd"
            echo "Uso: $0 agents [list|installed|install|install-preset]"
            return 1
            ;;
    esac
}

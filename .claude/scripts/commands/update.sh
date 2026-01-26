#!/bin/bash
# =============================================
# COMMAND: update - Atualização do orquestrador
# =============================================

# Configuração
ORCHESTRATOR_BACKUP_DIR="$ORCHESTRATION_DIR/.backups"
ORCHESTRATOR_SCRIPTS_PATH=".claude/scripts"
MAX_BACKUPS=5

# =============================================
# FUNÇÕES AUXILIARES PRIVADAS
# =============================================

_has_remote() {
    git remote get-url origin &>/dev/null
}

_get_remote_default_branch() {
    # Tenta descobrir o branch padrão do remote
    local branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
    if [[ -z "$branch" ]]; then
        # Fallback: tenta main, depois master
        if git rev-parse --verify origin/main &>/dev/null; then
            branch="main"
        elif git rev-parse --verify origin/master &>/dev/null; then
            branch="master"
        fi
    fi
    echo "${branch:-main}"
}

_get_local_version() {
    local version_line=$(grep -o "ORQUESTRADOR DE AGENTES CLAUDE v[0-9.]*" "$SCRIPT_DIR/orchestrate.sh" 2>/dev/null)
    echo "${version_line##*v}"
}

_get_remote_version() {
    local branch=$(_get_remote_default_branch)
    local remote_content=$(git show "origin/$branch:$ORCHESTRATOR_SCRIPTS_PATH/orchestrate.sh" 2>/dev/null)
    local version_line=$(echo "$remote_content" | grep -o "ORQUESTRADOR DE AGENTES CLAUDE v[0-9.]*")
    echo "${version_line##*v}"
}

_get_commits_behind() {
    local branch=$(_get_remote_default_branch)
    git rev-list --count "HEAD..origin/$branch" -- "$ORCHESTRATOR_SCRIPTS_PATH" 2>/dev/null || echo "0"
}

_get_pending_commits() {
    local branch=$(_get_remote_default_branch)
    git log --oneline "HEAD..origin/$branch" -- "$ORCHESTRATOR_SCRIPTS_PATH" 2>/dev/null
}

_get_changed_files() {
    local branch=$(_get_remote_default_branch)
    git diff --name-only "HEAD" "origin/$branch" -- "$ORCHESTRATOR_SCRIPTS_PATH" 2>/dev/null
}

_has_local_changes() {
    ! git diff --quiet HEAD -- "$ORCHESTRATOR_SCRIPTS_PATH" 2>/dev/null
}

_create_backup() {
    local backup_name=$(date '+%Y%m%d_%H%M%S')
    local backup_path="$ORCHESTRATOR_BACKUP_DIR/$backup_name"

    ensure_dir "$ORCHESTRATOR_BACKUP_DIR"
    ensure_dir "$backup_path"

    if cp -r "$SCRIPT_DIR"/* "$backup_path/" 2>/dev/null; then
        echo "$backup_path"
        return 0
    else
        return 1
    fi
}

_restore_backup() {
    local backup_path=$1

    if [[ -d "$backup_path" ]]; then
        # Limpar scripts atuais
        rm -rf "$SCRIPT_DIR/lib" "$SCRIPT_DIR/commands" "$SCRIPT_DIR/tests" "$SCRIPT_DIR/completions" 2>/dev/null
        rm -f "$SCRIPT_DIR/orchestrate.sh" "$SCRIPT_DIR/agents.sh" 2>/dev/null

        # Restaurar do backup
        cp -r "$backup_path"/* "$SCRIPT_DIR/"
        return $?
    fi
    return 1
}

_cleanup_old_backups() {
    if [[ -d "$ORCHESTRATOR_BACKUP_DIR" ]]; then
        # Listar diretórios por data, manter apenas os últimos MAX_BACKUPS
        local count=0
        for dir in $(ls -1dt "$ORCHESTRATOR_BACKUP_DIR"/*/ 2>/dev/null); do
            ((count++))
            if [[ $count -gt $MAX_BACKUPS ]]; then
                rm -rf "$dir" 2>/dev/null
            fi
        done
    fi
}

_verify_scripts() {
    # Verificar se orchestrate.sh existe
    if [[ ! -f "$SCRIPT_DIR/orchestrate.sh" ]]; then
        log_error "orchestrate.sh não encontrado"
        return 1
    fi

    # Verificar sintaxe bash do arquivo principal
    if ! bash -n "$SCRIPT_DIR/orchestrate.sh" 2>/dev/null; then
        log_error "Erro de sintaxe em orchestrate.sh"
        return 1
    fi

    # Verificar se libs essenciais existem
    local required_libs=(core.sh git.sh logging.sh validation.sh process.sh agents.sh)
    for lib in "${required_libs[@]}"; do
        if [[ ! -f "$SCRIPT_DIR/lib/$lib" ]]; then
            log_error "Biblioteca faltando: lib/$lib"
            return 1
        fi
    done

    # Verificar se commands essenciais existem
    local required_cmds=(init.sh help.sh)
    for cmd in "${required_cmds[@]}"; do
        if [[ ! -f "$SCRIPT_DIR/commands/$cmd" ]]; then
            log_error "Comando faltando: commands/$cmd"
            return 1
        fi
    done

    return 0
}

_apply_update() {
    local branch=$(_get_remote_default_branch)

    # Checkout seletivo apenas dos scripts
    git checkout "origin/$branch" -- "$ORCHESTRATOR_SCRIPTS_PATH" 2>/dev/null
}

# =============================================
# COMANDOS PÚBLICOS
# =============================================

cmd_update_check() {
    log_header "VERIFICAR ATUALIZAÇÕES"

    # Validações
    validate_git_repo || return 1

    if ! _has_remote; then
        log_error "Remote 'origin' não configurado"
        log_info "Configure com: git remote add origin <url>"
        return 1
    fi

    log_step "Verificando atualizações..."

    local branch=$(_get_remote_default_branch)

    # Fetch silencioso
    if ! git fetch origin "$branch" --quiet 2>/dev/null; then
        log_error "Falha ao conectar com remote"
        log_info "Verifique sua conexão com a internet"
        return 1
    fi

    local local_version=$(_get_local_version)
    local remote_version=$(_get_remote_version)
    local commits_behind=$(_get_commits_behind)

    echo ""
    log_info "Versão local:  v$local_version"
    log_info "Versão remota: v$remote_version"
    log_info "Branch:        $branch"
    echo ""

    if [[ "$commits_behind" == "0" ]]; then
        log_success "Orquestrador está atualizado!"
        return 0
    fi

    log_warn "Há $commits_behind commit(s) de atualização disponível(is)"
    echo ""

    log_info "Commits pendentes:"
    _get_pending_commits | while read -r line; do
        echo "  - $line"
    done

    echo ""
    log_info "Arquivos que serão atualizados:"
    _get_changed_files | while read -r file; do
        echo "  - $file"
    done

    echo ""
    log_info "Execute '.claude/scripts/orchestrate.sh update' para atualizar"

    return 0
}

cmd_update() {
    log_header "ATUALIZAR ORQUESTRADOR"

    # Validações iniciais
    validate_git_repo || return 1

    if ! _has_remote; then
        log_error "Remote 'origin' não configurado"
        log_info "Configure com: git remote add origin <url>"
        return 1
    fi

    local branch=$(_get_remote_default_branch)

    # Verificar se há mudanças locais nos scripts
    if _has_local_changes; then
        log_warn "Há modificações locais nos scripts do orquestrador"
        echo ""
        log_info "Arquivos modificados localmente:"
        git diff --name-only HEAD -- "$ORCHESTRATOR_SCRIPTS_PATH" 2>/dev/null | while read -r file; do
            echo "  - $file"
        done
        echo ""
        if ! confirm "Suas modificações serão sobrescritas. Continuar?"; then
            log_info "Operação cancelada"
            return 0
        fi
    fi

    # Fetch
    log_step "Buscando atualizações..."
    if ! git fetch origin "$branch" --quiet 2>/dev/null; then
        log_error "Falha ao conectar com remote"
        return 1
    fi

    # Verificar se há updates
    local commits_behind=$(_get_commits_behind)

    if [[ "$commits_behind" == "0" ]]; then
        log_success "Orquestrador já está atualizado!"
        return 0
    fi

    # Mostrar informações
    local local_version=$(_get_local_version)
    local remote_version=$(_get_remote_version)

    echo ""
    log_info "Versão atual:  v$local_version"
    log_info "Nova versão:   v$remote_version"
    log_info "Commits:       $commits_behind"
    echo ""

    log_info "Changelog:"
    log_separator
    _get_pending_commits | while read -r line; do
        echo "  $line"
    done
    log_separator
    echo ""

    # Confirmar atualização
    if ! confirm "Deseja atualizar o orquestrador?"; then
        log_info "Atualização cancelada"
        return 0
    fi

    # Criar backup
    log_step "Criando backup..."
    local backup_path=$(_create_backup)

    if [[ -z "$backup_path" ]]; then
        log_error "Falha ao criar backup"
        return 1
    fi

    log_info "Backup criado: $backup_path"

    # Aplicar atualização
    log_step "Aplicando atualização..."

    if ! _apply_update; then
        log_error "Falha ao aplicar atualização"
        log_step "Restaurando backup..."

        if _restore_backup "$backup_path"; then
            log_success "Backup restaurado com sucesso"
        else
            log_error "CRÍTICO: Falha ao restaurar backup!"
            log_error "Backup em: $backup_path"
        fi
        return 1
    fi

    # Verificar integridade
    log_step "Verificando integridade..."

    if ! _verify_scripts; then
        log_error "Scripts corrompidos após atualização"
        log_step "Restaurando backup..."

        if _restore_backup "$backup_path"; then
            log_success "Backup restaurado com sucesso"
        else
            log_error "CRÍTICO: Falha ao restaurar backup!"
            log_error "Backup em: $backup_path"
        fi
        return 1
    fi

    # Limpar backups antigos
    _cleanup_old_backups

    # Registrar evento
    echo "[$(timestamp)] UPDATE: v$local_version -> v$remote_version" >> "$EVENTS_FILE"

    # Sucesso
    echo ""
    log_success "Orquestrador atualizado com sucesso!"
    log_info "v$local_version -> v$remote_version"
    echo ""
    log_info "Execute 'orchestrate.sh doctor' para verificar a instalação"

    return 0
}

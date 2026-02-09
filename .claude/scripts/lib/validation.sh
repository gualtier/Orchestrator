#!/bin/bash
# =============================================
# VALIDATION - Input validation
# =============================================

# =============================================
# NAME VALIDATION
# =============================================

# Validate worktree/branch name (only a-z, A-Z, 0-9, _, -)
validate_name() {
    local name=$1
    local type=${2:-"nome"}

    if [[ -z "$name" ]]; then
        log_error "$type não pode ser vazio"
        return 1
    fi

    if [[ ! $name =~ ^[a-zA-Z][a-zA-Z0-9_-]*$ ]]; then
        log_error "$type inválido: '$name'"
        log_info "Use apenas: a-z, A-Z, 0-9, _, - (deve começar com letra)"
        return 1
    fi

    if [[ ${#name} -gt 50 ]]; then
        log_error "$type muito longo: máximo 50 caracteres"
        return 1
    fi

    return 0
}

# Validate preset name
validate_preset() {
    local preset=$1
    local valid_presets=$(list_presets)

    if [[ -z "$preset" ]]; then
        log_error "Preset não especificado"
        return 1
    fi

    if [[ ! " $valid_presets " =~ " $preset " ]]; then
        log_error "Preset desconhecido: '$preset'"
        log_info "Presets válidos: $valid_presets"
        return 1
    fi

    return 0
}

# Validate agent list
validate_agents_list() {
    local agents=$1

    if [[ -z "$agents" ]]; then
        log_error "Lista de agentes vazia"
        return 1
    fi

    # Check format (comma or space separated)
    local agent
    for agent in ${agents//,/ }; do
        if ! validate_name "$agent" "agente"; then
            return 1
        fi
    done

    return 0
}

# =============================================
# FILE VALIDATION
# =============================================

# Validate minimum task file structure
validate_task_file() {
    local file=$1

    if ! file_exists "$file"; then
        log_error "Arquivo de tarefa não encontrado: $file"
        return 1
    fi

    # Check if not empty
    if [[ ! -s "$file" ]]; then
        log_error "Arquivo de tarefa vazio: $file"
        return 1
    fi

    # Check required sections
    local has_title=$(grep -c "^# " "$file" 2>/dev/null || echo 0)
    if [[ $has_title -eq 0 ]]; then
        log_warn "Arquivo de tarefa sem título (# ...): $file"
    fi

    local has_objective=$(grep -ci "objetivo\|objective\|goal" "$file" 2>/dev/null || echo 0)
    if [[ $has_objective -eq 0 ]]; then
        log_warn "Arquivo de tarefa sem seção de objetivo: $file"
    fi

    return 0
}

# Validate DONE.md structure
validate_done_file() {
    local file=$1
    local errors=0

    if ! file_exists "$file"; then
        return 1
    fi

    # Check recommended sections
    local has_summary=$(grep -ci "## resumo\|## summary" "$file" 2>/dev/null || echo 0)
    local has_files=$(grep -ci "## arquivos\|## files" "$file" 2>/dev/null || echo 0)
    local has_test=$(grep -ci "## como testar\|## test\|## testing" "$file" 2>/dev/null || echo 0)

    [[ $has_summary -eq 0 ]] && ((errors++))
    [[ $has_files -eq 0 ]] && ((errors++))
    [[ $has_test -eq 0 ]] && ((errors++))

    return $errors
}

# =============================================
# ENVIRONMENT VALIDATION
# =============================================

# Check if it's a git repository
validate_git_repo() {
    if ! git rev-parse --is-inside-work-tree &>/dev/null; then
        log_error "Não é um repositório Git"
        return 1
    fi
    return 0
}

# Check if Claude CLI is installed
validate_claude_cli() {
    if ! command -v claude &>/dev/null; then
        log_error "Claude CLI não encontrado"
        log_info "Instale em: https://claude.ai/download"
        return 1
    fi
    return 0
}

# Check for orphaned worktrees
check_orphan_worktrees() {
    local orphans=0

    while IFS= read -r line; do
        local path=$(echo "$line" | awk '{print $1}')
        if [[ ! -d "$path" ]]; then
            log_warn "Worktree órfã: $path"
            ((orphans++))
        fi
    done < <(git worktree list 2>/dev/null | tail -n +2)

    return $orphans
}

# =============================================
# SANITIZATION
# =============================================

# Escapa string para uso seguro em sed
escape_sed() {
    local str=$1
    printf '%s' "$str" | sed 's/[&/\]/\\&/g'
}

# Escapa string para uso seguro em JSON
escape_json() {
    local str=$1
    printf '%s' "$str" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\n/\\n/g'
}

# Remove caracteres perigosos de string
sanitize_string() {
    local str=$1
    printf '%s' "$str" | tr -cd '[:alnum:][:space:]._-'
}

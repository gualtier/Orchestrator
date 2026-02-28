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
    local type=${2:-"name"}

    if [[ -z "$name" ]]; then
        log_error "$type cannot be empty"
        return 1
    fi

    if [[ ! $name =~ ^[a-zA-Z][a-zA-Z0-9_-]*$ ]]; then
        log_error "Invalid $type: '$name'"
        log_info "Use only: a-z, A-Z, 0-9, _, - (must start with a letter)"
        return 1
    fi

    if [[ ${#name} -gt 50 ]]; then
        log_error "$type too long: maximum 50 characters"
        return 1
    fi

    return 0
}

# Validate preset name
validate_preset() {
    local preset=$1
    local valid_presets=$(list_presets)

    if [[ -z "$preset" ]]; then
        log_error "Preset not specified"
        return 1
    fi

    if [[ ! " $valid_presets " =~ " $preset " ]]; then
        log_error "Unknown preset: '$preset'"
        log_info "Valid presets: $valid_presets"
        return 1
    fi

    return 0
}

# Validate agent list
validate_agents_list() {
    local agents=$1

    if [[ -z "$agents" ]]; then
        log_error "Agent list is empty"
        return 1
    fi

    # Check format (comma or space separated)
    local agent
    for agent in ${agents//,/ }; do
        if ! validate_name "$agent" "agent"; then
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
        log_error "Task file not found: $file"
        return 1
    fi

    # Check if not empty
    if [[ ! -s "$file" ]]; then
        log_error "Task file is empty: $file"
        return 1
    fi

    # Check required sections
    local has_title=$(grep -c "^# " "$file" 2>/dev/null || echo 0)
    if [[ $has_title -eq 0 ]]; then
        log_warn "Task file has no title (# ...): $file"
    fi

    local has_objective=$(grep -ci "objective\|goal" "$file" 2>/dev/null || echo 0)
    if [[ $has_objective -eq 0 ]]; then
        log_warn "Task file has no objective section: $file"
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
    local has_summary=$(grep -ci "## summary" "$file" 2>/dev/null || echo 0)
    local has_files=$(grep -ci "## files" "$file" 2>/dev/null || echo 0)
    local has_test=$(grep -ci "## test\|## testing" "$file" 2>/dev/null || echo 0)

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
        log_error "Not a Git repository"
        return 1
    fi
    return 0
}

# Check if Claude CLI is installed
validate_claude_cli() {
    if ! command -v claude &>/dev/null; then
        log_error "Claude CLI not found"
        log_info "Install from: https://claude.ai/download"
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
            log_warn "Orphaned worktree: $path"
            ((orphans++))
        fi
    done < <(git worktree list 2>/dev/null | tail -n +2)

    return $orphans
}

# =============================================
# SANITIZATION
# =============================================

# Escape string for safe use in sed
escape_sed() {
    local str=$1
    printf '%s' "$str" | sed 's/[&/\]/\\&/g'
}

# Escape string for safe use in JSON
escape_json() {
    local str=$1
    printf '%s' "$str" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\n/\\n/g'
}

# Remove dangerous characters from string
sanitize_string() {
    local str=$1
    printf '%s' "$str" | tr -cd '[:alnum:][:space:]._-'
}

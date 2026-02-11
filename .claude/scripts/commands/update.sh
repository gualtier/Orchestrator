#!/bin/bash
# =============================================
# COMMAND: update - Orchestrator update
# =============================================

# Configuration
ORCHESTRATOR_BACKUP_DIR="$ORCHESTRATION_DIR/.backups"
ORCHESTRATOR_SCRIPTS_PATH=".claude/scripts"
MAX_BACKUPS=5

# All paths that should be updated
ORCHESTRATOR_UPDATE_PATHS=(
    ".claude/scripts"
    ".claude/skills"
    ".claude/specs/constitution.md"
    ".claude/specs/templates"
    ".claude/AGENT_CLAUDE_BASE.md"
    "CLAUDE.md"
)

# =============================================
# PRIVATE HELPER FUNCTIONS
# =============================================

_has_remote() {
    git remote get-url origin &>/dev/null
}

_get_remote_default_branch() {
    local branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
    if [[ -z "$branch" ]]; then
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
    git rev-list --count "HEAD..origin/$branch" -- "${ORCHESTRATOR_UPDATE_PATHS[@]}" 2>/dev/null || echo "0"
}

_get_pending_commits() {
    local branch=$(_get_remote_default_branch)
    git log --oneline "HEAD..origin/$branch" -- "${ORCHESTRATOR_UPDATE_PATHS[@]}" 2>/dev/null
}

_get_changed_files() {
    local branch=$(_get_remote_default_branch)
    git diff --name-only "HEAD" "origin/$branch" -- "${ORCHESTRATOR_UPDATE_PATHS[@]}" 2>/dev/null
}

_has_local_changes() {
    ! git diff --quiet HEAD -- "${ORCHESTRATOR_UPDATE_PATHS[@]}" 2>/dev/null
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
        rm -rf "$SCRIPT_DIR/lib" "$SCRIPT_DIR/commands" "$SCRIPT_DIR/tests" "$SCRIPT_DIR/completions" 2>/dev/null
        rm -f "$SCRIPT_DIR/orchestrate.sh" "$SCRIPT_DIR/agents.sh" 2>/dev/null

        cp -r "$backup_path"/* "$SCRIPT_DIR/"
        return $?
    fi
    return 1
}

_cleanup_old_backups() {
    if [[ -d "$ORCHESTRATOR_BACKUP_DIR" ]]; then
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
    if [[ ! -f "$SCRIPT_DIR/orchestrate.sh" ]]; then
        log_error "orchestrate.sh not found"
        return 1
    fi

    if ! bash -n "$SCRIPT_DIR/orchestrate.sh" 2>/dev/null; then
        log_error "Syntax error in orchestrate.sh"
        return 1
    fi

    local required_libs=(core.sh git.sh logging.sh validation.sh process.sh agents.sh)
    for lib in "${required_libs[@]}"; do
        if [[ ! -f "$SCRIPT_DIR/lib/$lib" ]]; then
            log_error "Missing library: lib/$lib"
            return 1
        fi
    done

    local required_cmds=(init.sh help.sh)
    for cmd in "${required_cmds[@]}"; do
        if [[ ! -f "$SCRIPT_DIR/commands/$cmd" ]]; then
            log_error "Missing command: commands/$cmd"
            return 1
        fi
    done

    return 0
}

_apply_update() {
    local branch=$(_get_remote_default_branch)

    # Update all orchestrator paths (scripts, skills, specs, etc.)
    for path in "${ORCHESTRATOR_UPDATE_PATHS[@]}"; do
        if git ls-tree -r --name-only "origin/$branch" -- "$path" &>/dev/null; then
            git checkout "origin/$branch" -- "$path" 2>/dev/null || true
        fi
    done
}

_show_whats_new() {
    local old_version=$1
    local new_version=$2

    echo ""
    log_separator
    echo -e "${BOLD}  WHAT'S NEW in v${new_version}${NC}"
    log_separator

    # Compare major.minor to decide which notes to show
    local old_minor=$(echo "$old_version" | cut -d. -f1-2)
    local new_minor=$(echo "$new_version" | cut -d. -f1-2)

    # Show release notes for versions between old and new
    if _version_lt "$old_minor" "3.2"; then
        echo ""
        echo -e "  ${GREEN}v3.2 - Memory Management${NC}"
        echo "    - update-memory --full: auto-increment version + changelog"
    fi

    if _version_lt "$old_minor" "3.3"; then
        echo ""
        echo -e "  ${GREEN}v3.3 - Auto-Update & CLI${NC}"
        echo "    - update command with automatic backup"
        echo "    - install-cli: global 'orch' shortcut"
    fi

    if _version_lt "$old_minor" "3.4"; then
        echo ""
        echo -e "  ${GREEN}v3.4 - Learning & Monitoring${NC}"
        echo "    - learn command: extract insights from completed tasks"
        echo "    - Enhanced status with progress bars, velocity, ETA"
        echo "    - Watch mode: live auto-refreshing status"
    fi

    if _version_lt "$old_minor" "3.5"; then
        echo ""
        echo -e "  ${GREEN}v3.5 - Spec-Driven Development & Skills${NC}"
        echo "    - SDD pipeline: specify -> research -> plan -> gate -> tasks"
        echo "    - Constitution system with editable project principles"
        echo "    - Mandatory research gate before planning"
        echo "    - 14 Claude Code Skills (/sdd-*, /orch-*)"
        echo "    - Autonomous architect: Claude auto-chains the pipeline"
        echo ""
        echo -e "  ${YELLOW}Quick start:${NC}"
        echo "    orch sdd init          # Initialize SDD (first time)"
        echo "    /sdd-specify \"desc\"    # Or just describe your feature"
    fi

    echo ""
    log_separator
    echo ""
    log_info "Run 'orch doctor' to verify the installation"
    log_info "Run 'orch help' for the full command list"
}

# Simple version comparison: returns 0 if $1 < $2
_version_lt() {
    local v1_major=$(echo "$1" | cut -d. -f1)
    local v1_minor=$(echo "$1" | cut -d. -f2)
    local v2_major=$(echo "$2" | cut -d. -f1)
    local v2_minor=$(echo "$2" | cut -d. -f2)

    v1_major=${v1_major:-0}
    v1_minor=${v1_minor:-0}
    v2_major=${v2_major:-0}
    v2_minor=${v2_minor:-0}

    if [[ $v1_major -lt $v2_major ]]; then
        return 0
    elif [[ $v1_major -eq $v2_major ]] && [[ $v1_minor -lt $v2_minor ]]; then
        return 0
    fi
    return 1
}

# =============================================
# PUBLIC COMMANDS
# =============================================

cmd_update_check() {
    log_header "CHECK FOR UPDATES"

    validate_git_repo || return 1

    if ! _has_remote; then
        log_error "Remote 'origin' not configured"
        log_info "Configure with: git remote add origin <url>"
        return 1
    fi

    log_step "Checking for updates..."

    local branch=$(_get_remote_default_branch)

    if ! git fetch origin "$branch" --quiet 2>/dev/null; then
        log_error "Failed to connect to remote"
        log_info "Check your internet connection"
        return 1
    fi

    local local_version=$(_get_local_version)
    local remote_version=$(_get_remote_version)
    local commits_behind=$(_get_commits_behind)

    echo ""
    log_info "Local version:  v$local_version"
    log_info "Remote version: v$remote_version"
    log_info "Branch:         $branch"
    echo ""

    if [[ "$commits_behind" == "0" ]]; then
        log_success "Orchestrator is up to date!"
        return 0
    fi

    log_warn "$commits_behind update commit(s) available"
    echo ""

    log_info "Pending commits:"
    _get_pending_commits | while read -r line; do
        echo "  - $line"
    done

    echo ""
    log_info "Files that will be updated:"
    _get_changed_files | while read -r file; do
        echo "  - $file"
    done

    echo ""
    log_info "Run 'orch update' to update"

    return 0
}

cmd_update() {
    log_header "UPDATE ORCHESTRATOR"

    validate_git_repo || return 1

    if ! _has_remote; then
        log_error "Remote 'origin' not configured"
        log_info "Configure with: git remote add origin <url>"
        return 1
    fi

    local branch=$(_get_remote_default_branch)

    # Check for local changes
    if _has_local_changes; then
        log_warn "Local modifications detected in orchestrator files"
        echo ""
        log_info "Modified files:"
        git diff --name-only HEAD -- "${ORCHESTRATOR_UPDATE_PATHS[@]}" 2>/dev/null | while read -r file; do
            echo "  - $file"
        done
        echo ""
        if ! confirm "Your modifications will be overwritten. Continue?"; then
            log_info "Update cancelled"
            return 0
        fi
    fi

    # Fetch
    log_step "Fetching updates..."
    if ! git fetch origin "$branch" --quiet 2>/dev/null; then
        log_error "Failed to connect to remote"
        return 1
    fi

    # Check for updates
    local commits_behind=$(_get_commits_behind)

    if [[ "$commits_behind" == "0" ]]; then
        log_success "Orchestrator is already up to date!"
        return 0
    fi

    # Show information
    local local_version=$(_get_local_version)
    local remote_version=$(_get_remote_version)

    echo ""
    log_info "Current version: v$local_version"
    log_info "New version:     v$remote_version"
    log_info "Commits:         $commits_behind"
    echo ""

    log_info "Changelog:"
    log_separator
    _get_pending_commits | while read -r line; do
        echo "  $line"
    done
    log_separator
    echo ""

    # Confirm update
    if ! confirm "Update orchestrator?"; then
        log_info "Update cancelled"
        return 0
    fi

    # Create backup
    log_step "Creating backup..."
    local backup_path=$(_create_backup)

    if [[ -z "$backup_path" ]]; then
        log_error "Failed to create backup"
        return 1
    fi

    log_info "Backup saved: $backup_path"

    # Apply update
    log_step "Applying update..."

    if ! _apply_update; then
        log_error "Failed to apply update"
        log_step "Restoring backup..."

        if _restore_backup "$backup_path"; then
            log_success "Backup restored successfully"
        else
            log_error "CRITICAL: Failed to restore backup!"
            log_error "Backup at: $backup_path"
        fi
        return 1
    fi

    # Check integrity
    log_step "Verifying integrity..."

    if ! _verify_scripts; then
        log_error "Scripts corrupted after update"
        log_step "Restoring backup..."

        if _restore_backup "$backup_path"; then
            log_success "Backup restored successfully"
        else
            log_error "CRITICAL: Failed to restore backup!"
            log_error "Backup at: $backup_path"
        fi
        return 1
    fi

    # Ensure new directories exist
    ensure_dir "$CLAUDE_DIR/specs/active" 2>/dev/null || true
    ensure_dir "$CLAUDE_DIR/specs/archive" 2>/dev/null || true

    # Clean old backups
    _cleanup_old_backups

    # Log event
    echo "[$(timestamp)] UPDATE: v$local_version -> v$remote_version" >> "$EVENTS_FILE"

    # Success + What's New
    echo ""
    log_success "Orchestrator updated successfully!"
    log_info "v$local_version -> v$remote_version"

    _show_whats_new "$local_version" "$remote_version"

    return 0
}

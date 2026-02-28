#!/bin/bash
# =============================================
# COMMAND: update - Orchestrator update
# =============================================

# Configuration
ORCHESTRATOR_BACKUP_DIR="$ORCHESTRATION_DIR/.backups"
ORCHESTRATOR_SCRIPTS_PATH=".claude/scripts"
ORCHESTRATOR_REPO_URL="https://github.com/gualtier/Orchestrator.git"
MAX_BACKUPS=5

# All paths that should be updated
ORCHESTRATOR_UPDATE_PATHS=(
    ".claude/scripts"
    ".claude/skills"
    ".claude/specs/constitution.md"
    ".claude/specs/templates"
    ".claude/AGENT_CLAUDE_BASE.md"
    ".claude/CAPABILITIES.md"
)

# =============================================
# PRIVATE HELPER FUNCTIONS
# =============================================

# Resolve the remote used for orchestrator updates.
# Prefers a dedicated "orchestrator" remote, falls back to "origin".
_resolve_remote() {
    if git remote get-url orchestrator &>/dev/null; then
        echo "orchestrator"
    elif git remote get-url origin &>/dev/null; then
        echo "origin"
    else
        echo ""
    fi
}

_has_remote() {
    local remote=$(_resolve_remote)
    [[ -n "$remote" ]]
}

# Ensure the "orchestrator" remote exists, creating it if needed.
_ensure_orchestrator_remote() {
    if git remote get-url orchestrator &>/dev/null; then
        return 0
    fi

    # If origin already points to the Orchestrator repo, no need for a separate remote
    local origin_url=$(git remote get-url origin 2>/dev/null || echo "")
    if [[ "$origin_url" == *"gualtier/Orchestrator"* ]]; then
        return 0
    fi

    # Add dedicated remote
    log_step "Adding 'orchestrator' remote for updates..."
    if git remote add orchestrator "$ORCHESTRATOR_REPO_URL" 2>/dev/null; then
        log_success "Remote 'orchestrator' added: $ORCHESTRATOR_REPO_URL"
        return 0
    else
        log_error "Failed to add 'orchestrator' remote"
        return 1
    fi
}

_get_remote_default_branch() {
    local remote=$(_resolve_remote)
    local branch=$(git symbolic-ref "refs/remotes/$remote/HEAD" 2>/dev/null | sed "s@^refs/remotes/$remote/@@")
    if [[ -z "$branch" ]]; then
        if git rev-parse --verify "$remote/main" &>/dev/null; then
            branch="main"
        elif git rev-parse --verify "$remote/master" &>/dev/null; then
            branch="master"
        fi
    fi
    echo "${branch:-main}"
}

_get_local_version() {
    # Support both old Portuguese and new English header
    local version_line=$(grep -o "CLAUDE AGENT ORCHESTRATOR v[0-9.]*\|ORQUESTRADOR DE AGENTES CLAUDE v[0-9.]*" "$SCRIPT_DIR/orchestrate.sh" 2>/dev/null | head -1)
    echo "${version_line##*v}"
}

_get_remote_version() {
    local remote=$(_resolve_remote)
    local branch=$(_get_remote_default_branch)
    local remote_content=$(git show "$remote/$branch:$ORCHESTRATOR_SCRIPTS_PATH/orchestrate.sh" 2>/dev/null)
    # Support both old Portuguese and new English header
    local version_line=$(echo "$remote_content" | grep -o "CLAUDE AGENT ORCHESTRATOR v[0-9.]*\|ORQUESTRADOR DE AGENTES CLAUDE v[0-9.]*" | head -1)
    echo "${version_line##*v}"
}

_get_commits_behind() {
    local remote=$(_resolve_remote)
    local branch=$(_get_remote_default_branch)
    git rev-list --count "HEAD..$remote/$branch" -- "${ORCHESTRATOR_UPDATE_PATHS[@]}" 2>/dev/null || echo "0"
}

_get_pending_commits() {
    local remote=$(_resolve_remote)
    local branch=$(_get_remote_default_branch)
    git log --oneline "HEAD..$remote/$branch" -- "${ORCHESTRATOR_UPDATE_PATHS[@]}" 2>/dev/null
}

_get_changed_files() {
    local remote=$(_resolve_remote)
    local branch=$(_get_remote_default_branch)
    git diff --name-only "HEAD" "$remote/$branch" -- "${ORCHESTRATOR_UPDATE_PATHS[@]}" 2>/dev/null
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
    local remote=$(_resolve_remote)
    local branch=$(_get_remote_default_branch)

    # Update all orchestrator paths (scripts, skills, specs, etc.)
    for path in "${ORCHESTRATOR_UPDATE_PATHS[@]}"; do
        if git ls-tree -r --name-only "$remote/$branch" -- "$path" &>/dev/null; then
            git checkout "$remote/$branch" -- "$path" 2>/dev/null || true
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

    # Show release notes for versions between old and new
    if _version_lt "$old_version" "3.2"; then
        echo ""
        echo -e "  ${GREEN}v3.2 - Memory Management${NC}"
        echo "    - update-memory --full: auto-increment version + changelog"
    fi

    if _version_lt "$old_version" "3.3"; then
        echo ""
        echo -e "  ${GREEN}v3.3 - Auto-Update & CLI${NC}"
        echo "    - update command with automatic backup"
        echo "    - install-cli: global 'orch' shortcut"
    fi

    if _version_lt "$old_version" "3.4"; then
        echo ""
        echo -e "  ${GREEN}v3.4 - Learning & Monitoring${NC}"
        echo "    - learn command: extract insights from completed tasks"
        echo "    - Enhanced status with progress bars, velocity, ETA"
        echo "    - Watch mode: live auto-refreshing status"
    fi

    if _version_lt "$old_version" "3.5"; then
        echo ""
        echo -e "  ${GREEN}v3.5 - Spec-Driven Development & Skills${NC}"
        echo "    - SDD pipeline: specify -> research -> plan -> gate -> tasks"
        echo "    - Constitution system with editable project principles"
        echo "    - Mandatory research gate before planning"
        echo "    - Claude Code Skills (/sdd-*, /orch-*)"
        echo "    - Autonomous architect: Claude auto-chains the pipeline"
        echo ""
        echo -e "  ${YELLOW}Quick start:${NC}"
        echo "    orch sdd init          # Initialize SDD (first time)"
        echo "    /sdd-specify \"desc\"    # Or just describe your feature"
    fi

    if _version_lt "$old_version" "3.6"; then
        echo ""
        echo -e "  ${GREEN}v3.6 - Active Error Monitoring${NC}"
        echo "    - Error detection engine: incremental log polling (~5-25ms/agent)"
        echo "    - 3-tier severity: CRITICAL / WARNING / INFO with color-coded display"
        echo "    - Corrective action suggestions per error type"
        echo "    - Error dashboard: orch errors (--watch, --agent, --recent, --clear)"
        echo "    - Integrated into status and wait commands"
        echo "    - /orch-errors skill for real-time monitoring"
        echo "    - 15 Claude Code Skills total"
    fi

    if _version_lt "$old_version" "3.7"; then
        echo ""
        echo -e "  ${GREEN}v3.7 - SDD Autopilot${NC}"
        echo "    - sdd run [number]: end-to-end pipeline execution after plan approval"
        echo "    - Dual mode: single spec or all planned specs at once"
        echo "    - Fail-fast on gate failure, task errors, or setup errors"
        echo "    - Integration reminder for multi-agent runs"
        echo "    - /sdd-run Claude Code skill"
    fi

    if _version_lt "$old_version" "3.8"; then
        echo ""
        echo -e "  ${GREEN}v3.8 - Agent Teams Backend${NC}"
        echo "    - Dual execution: --mode teams|worktree on sdd run"
        echo "    - Native agent coordination via Claude Code Agent Teams"
        echo "    - Team lead prompt auto-generated from SDD artifacts"
        echo "    - Branch-per-teammate file conflict mitigation"
        echo "    - Quality gate hooks: TeammateIdle, TaskCompleted"
        echo "    - team start|status|stop subcommands"
        echo "    - /orch-team-start and /orch-team-status skills"
    fi

    if _version_lt "$old_version" "3.9"; then
        echo ""
        echo -e "  ${GREEN}v3.9 - Autonomous SDD Pipeline${NC}"
        echo "    - sdd run --auto-merge: zero-touch pipeline (run → merge → archive)"
        echo "    - Hooks auto-bypass during autopilot (no more manual approvals)"
        echo "    - Auto update-memory, learn, and archive after agents complete"
        echo "    - Stale worktrees cleaned up automatically on spec archive"
        echo "    - Smarter hooks: command-based (faster, no LLM latency)"
        echo "    - Self-dev docs check prevents stale README/CAPABILITIES"
        echo ""
        echo -e "  ${YELLOW}Quick start:${NC}"
        echo "    /sdd-run 001 --auto-merge   # Fully hands-off"
    fi

    if _version_lt "$old_version" "3.9.1"; then
        echo ""
        echo -e "  ${GREEN}v3.9.1 - Async-First Execution${NC}"
        echo "    - RULE #2: ASYNC-FIRST — NEVER block waiting for agents"
        echo "    - All starts use --no-monitor (non-blocking launch)"
        echo "    - 30s polling loops for status + errors (fast failure detection)"
        echo "    - Updated skills: orch-start, sdd-run, orch-status, orch-errors"
        echo "    - Correct/wrong pattern examples in CLAUDE.md"
    fi

    if _version_lt "$old_version" "3.9.2"; then
        echo ""
        echo -e "  ${GREEN}v3.9.2 - Agent Behavioral Rules${NC}"
        echo "    - RULE #3: AGENT BEHAVIOR — plan, verify, fix, learn"
        echo "    - Plan before building, verify before done"
        echo "    - Autonomous bug fixing, real-time lesson capture"
    fi

    if _version_lt "$old_version" "3.9.3"; then
        echo ""
        echo -e "  ${GREEN}v3.9.3 - Distribution Ready${NC}"
        echo "    - All strings translated to English (330+ instances)"
        echo "    - Complete .gitignore for runtime/personal files"
        echo "    - PROJECT_MEMORY.template.md for clean new-user setup"
        echo "    - Post-compact state injection (agents, errors, SDD phase)"
        echo "    - Version detection supports old and new header formats"
    fi

    echo ""
    log_separator
    echo ""
    log_info "Run 'orch doctor' to verify the installation"
    log_info "Run 'orch help' for the full command list"
}

# Version comparison: returns 0 if $1 < $2 (supports major.minor.patch)
_version_lt() {
    local v1_major=$(echo "$1" | cut -d. -f1)
    local v1_minor=$(echo "$1" | cut -d. -f2)
    local v1_patch=$(echo "$1" | cut -d. -f3)
    local v2_major=$(echo "$2" | cut -d. -f1)
    local v2_minor=$(echo "$2" | cut -d. -f2)
    local v2_patch=$(echo "$2" | cut -d. -f3)

    v1_major=${v1_major:-0}
    v1_minor=${v1_minor:-0}
    v1_patch=${v1_patch:-0}
    v2_major=${v2_major:-0}
    v2_minor=${v2_minor:-0}
    v2_patch=${v2_patch:-0}

    if [[ $v1_major -lt $v2_major ]]; then
        return 0
    elif [[ $v1_major -eq $v2_major ]]; then
        if [[ $v1_minor -lt $v2_minor ]]; then
            return 0
        elif [[ $v1_minor -eq $v2_minor ]] && [[ $v1_patch -lt $v2_patch ]]; then
            return 0
        fi
    fi
    return 1
}

# =============================================
# PUBLIC COMMANDS
# =============================================

cmd_update_check() {
    log_header "CHECK FOR UPDATES"

    validate_git_repo || return 1

    _ensure_orchestrator_remote || return 1

    if ! _has_remote; then
        log_error "No update remote configured"
        log_info "Configure with: git remote add orchestrator $ORCHESTRATOR_REPO_URL"
        return 1
    fi

    local remote=$(_resolve_remote)

    log_step "Checking for updates (remote: $remote)..."

    local branch=$(_get_remote_default_branch)

    if ! git fetch "$remote" "$branch" --quiet 2>/dev/null; then
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
    log_info "Remote:         $remote ($branch)"
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

    _ensure_orchestrator_remote || return 1

    if ! _has_remote; then
        log_error "No update remote configured"
        log_info "Configure with: git remote add orchestrator $ORCHESTRATOR_REPO_URL"
        return 1
    fi

    local remote=$(_resolve_remote)
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
    log_step "Fetching updates (remote: $remote)..."
    if ! git fetch "$remote" "$branch" --quiet 2>/dev/null; then
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

    # Reload from the newly downloaded file so _show_whats_new
    # includes release notes for versions the OLD script didn't know about
    source "$SCRIPT_DIR/commands/update.sh"

    _show_whats_new "$local_version" "$remote_version"

    return 0
}

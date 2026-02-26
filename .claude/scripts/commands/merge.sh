#!/bin/bash
# =============================================
# COMMAND: merge/cleanup - Finalization
# =============================================

cmd_merge() {
    local target="main"
    local dry_run=false
    local auto_cleanup=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)   dry_run=true; shift ;;
            --cleanup)   auto_cleanup=true; shift ;;
            *)           target="$1"; shift ;;
        esac
    done

    # Bug fix: Detect if user passed a worktree name instead of a branch name
    if [[ "$target" != "main" ]]; then
        local check_task="$ORCHESTRATION_DIR/tasks/${target}.md"
        if [[ -f "$check_task" ]]; then
            log_error "'$target' is a worktree name, not a target branch."
            log_info "Usage: orchestrate.sh merge [target-branch] [--dry-run] [--cleanup]"
            log_info "  orchestrate.sh merge              # merge all worktrees to main"
            log_info "  orchestrate.sh merge develop       # merge all worktrees to develop"
            log_info "  orchestrate.sh merge --dry-run     # pre-flight check without merging"
            log_info "  orchestrate.sh merge --cleanup     # merge + auto-remove worktrees"
            return 1
        fi
    fi

    # Dry-run mode: show what would happen without executing
    if $dry_run; then
        _merge_dry_run "$target"
        return $?
    fi

    log_step "Iniciando merge para: $target"

    # Check completion of all tasks
    for task_file in "$ORCHESTRATION_DIR/tasks"/*.md; do
        [[ -f "$task_file" ]] || continue
        local name=$(basename "$task_file" .md)
        local worktree_path=$(get_worktree_path "$name")

        # Pular reviews
        [[ "$name" == review-* ]] && continue

        # Check for uncommitted changes (excluding orchestrator artifacts)
        local uncommitted=0
        if dir_exists "$worktree_path"; then
            uncommitted=$(cd "$worktree_path" && git status --porcelain 2>/dev/null | \
                grep -v -E '^(\?\?| M|M ) \.claude/(AGENTS_USED|CLAUDE\.md)' | \
                grep -v -E '^(\?\?| M|M ) uv\.lock$' | \
                wc -l | tr -d ' ')
        fi
        if [[ $uncommitted -gt 0 ]]; then
            log_warn "Agent $name has $uncommitted uncommitted file(s)! These changes will be LOST on merge."
            log_info "Inspect with: cd $(get_worktree_path "$name") && git status"
            if ! confirm "Continue merging $name anyway?"; then
                log_info "Merge aborted. Commit or discard changes in worktree first."
                return 1
            fi
        fi

        if ! file_exists "$worktree_path/DONE.md"; then
            # Fallback: check if agent made commits despite missing DONE.md
            local commits=0
            if dir_exists "$worktree_path"; then
                commits=$(cd "$worktree_path" && git log --oneline main..HEAD 2>/dev/null | wc -l | tr -d ' ')
            fi
            if [[ $commits -gt 0 ]]; then
                log_warn "Agent $name has no DONE.md but made $commits commit(s). Proceeding with merge."
            else
                log_error "Agent $name did not finish (no DONE.md, no commits)"
                log_info "Use: $0 verify $name"
                return 1
            fi
        fi
    done

    # Save original branch to restore on failure
    local original_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")

    # Mudar para branch alvo
    git checkout "$target" || {
        log_error "Falha ao mudar para $target"
        return 1
    }

    git pull origin "$target" 2>/dev/null || true

    local merged=0
    local failed=0

    for task_file in "$ORCHESTRATION_DIR/tasks"/*.md; do
        [[ -f "$task_file" ]] || continue
        local name=$(basename "$task_file" .md)
        local branch="feature/$name"

        # Pular reviews
        [[ "$name" == review-* ]] && continue

        log_info "Merging $branch..."

        if git merge "$branch" -m "feat: merge $name"; then
            # Remove worktree artifacts that shouldn't live in the target branch
            local artifacts_removed=false
            for artifact in DONE.md PROGRESS.md BLOCKED.md; do
                if [[ -f "$artifact" ]]; then
                    git rm -f "$artifact" 2>/dev/null && artifacts_removed=true
                fi
            done
            if $artifacts_removed; then
                git commit -m "chore: remove worktree artifacts from $name merge"
            fi

            log_success "$branch merged"
            ((merged++)) || true
        else
            # Abort the failed merge so subsequent merges can proceed
            git merge --abort 2>/dev/null || true
            ((failed++)) || true

            log_error "Conflito em $branch (merge abortado automaticamente)"
            log_info "Após o merge, resolva manualmente com: git merge $branch"

            if ! confirm "Continuar com próximo merge?"; then
                git checkout "$original_branch" 2>/dev/null || true
                return 1
            fi
        fi
    done

    if [[ $failed -eq 0 ]]; then
        log_success "Merge completo! ($merged branches)"
        log_info "💡 Tip: Extract learnings with: $0 learn extract"

        # Auto-archive specs whose tasks are all merged
        _auto_archive_completed_specs
    else
        log_warn "Merge parcial: $merged OK, $failed com conflitos"
    fi

    # Registrar evento
    echo "[$(timestamp)] MERGED: $merged branches to $target" >> "$EVENTS_FILE"

    # Auto-cleanup if requested
    if $auto_cleanup && [[ $failed -eq 0 ]]; then
        log_step "Auto-cleanup: removing merged worktrees..."
        FORCE=true cmd_cleanup
    fi
}

# Pre-flight check: show what merge would do without executing
_merge_dry_run() {
    local target=$1

    log_header "MERGE DRY-RUN (pre-flight check)"
    echo "  Target branch: $target"
    echo ""

    local total=0
    local ready=0
    local problems=0

    for task_file in "$ORCHESTRATION_DIR/tasks"/*.md; do
        [[ -f "$task_file" ]] || continue
        local name=$(basename "$task_file" .md)
        local worktree_path=$(get_worktree_path "$name")
        local branch="feature/$name"

        [[ "$name" == review-* ]] && continue
        ((total++)) || true

        echo -e "  ${BOLD}$name${NC} ($branch)"

        # Check branch exists
        if ! branch_exists "$branch"; then
            echo -e "    ${RED}Branch does not exist${NC}"
            ((problems++)) || true
            continue
        fi

        # Check commits
        local commits=0
        if dir_exists "$worktree_path"; then
            commits=$(cd "$worktree_path" && git log --oneline main..HEAD 2>/dev/null | wc -l | tr -d ' ')
        fi
        echo "    Commits: $commits"

        # Check DONE.md
        if file_exists "$worktree_path/DONE.md"; then
            echo -e "    DONE.md: ${GREEN}present${NC}"
        elif [[ $commits -gt 0 ]]; then
            echo -e "    DONE.md: ${YELLOW}missing (but has commits)${NC}"
        else
            echo -e "    DONE.md: ${RED}missing (no commits either)${NC}"
            ((problems++)) || true
        fi

        # Check uncommitted changes (filtered)
        local uncommitted=0
        if dir_exists "$worktree_path"; then
            uncommitted=$(cd "$worktree_path" && git status --porcelain 2>/dev/null | \
                grep -v -E '^(\?\?| M|M ) \.claude/(AGENTS_USED|CLAUDE\.md)' | \
                grep -v -E '^(\?\?| M|M ) uv\.lock$' | \
                wc -l | tr -d ' ')
        fi
        if [[ $uncommitted -gt 0 ]]; then
            echo -e "    Uncommitted: ${YELLOW}$uncommitted file(s)${NC}"
        else
            echo -e "    Uncommitted: ${GREEN}clean${NC}"
        fi

        # Check for merge conflicts
        if branch_exists "$branch"; then
            if simulate_merge "$branch" "$target" 2>/dev/null; then
                echo -e "    Merge: ${GREEN}no conflicts${NC}"
                ((ready++)) || true
            else
                echo -e "    Merge: ${RED}CONFLICTS detected${NC}"
                ((problems++)) || true
            fi
        fi

        # Check for artifacts that will be cleaned
        local artifact_list=""
        for artifact in DONE.md PROGRESS.md BLOCKED.md; do
            if dir_exists "$worktree_path" && (cd "$worktree_path" && git show "HEAD:$artifact" &>/dev/null); then
                artifact_list+="$artifact "
            fi
        done
        if [[ -n "$artifact_list" ]]; then
            echo -e "    Artifacts to clean: ${GRAY}$artifact_list${NC}"
        fi

        echo ""
    done

    log_separator
    if [[ $problems -eq 0 ]]; then
        echo -e "  ${GREEN}Ready to merge: $ready/$total branches, 0 problems${NC}"
        echo "  Run: orchestrate.sh merge"
    else
        echo -e "  ${YELLOW}$ready/$total ready, $problems problem(s) found${NC}"
        echo "  Fix issues above before merging."
    fi
    echo ""

    return 0
}

# Clean up orchestrator artifacts (tasks, worktrees, PIDs, logs) belonging to a spec.
# Called when a spec is archived so stale worktrees don't pollute status output.
_cleanup_spec_artifacts() {
    local spec_name=$1   # e.g. "006-feature-name"
    local spec_num=${spec_name%%-*}
    local cleaned=0

    for task_file in "$ORCHESTRATION_DIR/tasks"/*.md; do
        [[ -f "$task_file" ]] || continue

        # Match tasks belonging to this spec (via spec-ref line or task name prefix)
        if grep -q "spec-ref:.*${spec_num}" "$task_file" 2>/dev/null || \
           [[ "$(basename "$task_file" .md)" == "${spec_name}" ]]; then

            local task_name=$(basename "$task_file" .md)
            local worktree_path=$(get_worktree_path "$task_name")

            # Stop agent if still running
            stop_agent_process "$task_name" true 2>/dev/null || true

            # Remove worktree
            if dir_exists "$worktree_path"; then
                git worktree remove "$worktree_path" --force 2>/dev/null || true
            fi

            # Clean up PID, start-time, and log files
            rm -f "$(get_pid_file "$task_name")" 2>/dev/null
            rm -f "$(get_start_time_file "$task_name")" 2>/dev/null
            rm -f "$(get_log_file "$task_name")" 2>/dev/null

            # Remove the task file itself
            rm -f "$task_file"
            ((cleaned++)) || true
        fi
    done

    # Prune any orphaned worktree references
    git worktree prune 2>/dev/null || true

    if [[ $cleaned -gt 0 ]]; then
        log_info "Cleaned $cleaned stale task(s)/worktree(s) for spec $spec_name"
    fi
}

# Auto-archive specs when all their task branches have been merged
_auto_archive_completed_specs() {
    [[ -d "$SPECS_ACTIVE" ]] || return 0

    for spec_dir in "$SPECS_ACTIVE"/*/; do
        [[ -d "$spec_dir" ]] || continue
        [[ -f "$spec_dir/tasks.md" ]] || continue

        local spec_name=$(basename "$spec_dir")
        local spec_num=${spec_name%%-*}
        local task_count=0
        local merged_count=0

        # Count tasks belonging to this spec
        for task_file in "$ORCHESTRATION_DIR/tasks"/*.md; do
            [[ -f "$task_file" ]] || continue
            if grep -q "spec-ref:.*${spec_num}" "$task_file" 2>/dev/null; then
                ((task_count++))
                local task_name=$(basename "$task_file" .md)
                local branch="feature/$task_name"

                # Check if branch was already merged into current branch
                if git branch --merged HEAD 2>/dev/null | grep -q "$branch"; then
                    ((merged_count++))
                fi
            fi
        done

        # If all tasks merged, auto-archive
        if [[ $task_count -gt 0 ]] && [[ $merged_count -eq $task_count ]]; then
            _cleanup_spec_artifacts "$spec_name"
            ensure_dir "$SPECS_ARCHIVE"
            mv "$spec_dir" "$SPECS_ARCHIVE/"
            log_success "Spec auto-archived: $spec_name ($task_count/$task_count tasks merged)"

            if [[ -f "$EVENTS_FILE" ]]; then
                echo "[$(timestamp)] SDD_AUTO_ARCHIVE: ${spec_name}" >> "$EVENTS_FILE"
            fi
        fi
    done
}

cmd_cleanup() {
    log_step "Limpando worktrees..."

    # Confirm destructive operation
    if ! confirm "Remover todas as worktrees? Dados não commitados serão perdidos."; then
        log_info "Operação cancelada"
        return 0
    fi

    local archive_dir="$ORCHESTRATION_DIR/archive/$(date '+%Y%m%d_%H%M%S')"
    ensure_dir "$archive_dir"

    local removed=0

    for task_file in "$ORCHESTRATION_DIR/tasks"/*.md; do
        [[ -f "$task_file" ]] || continue

        local name=$(basename "$task_file" .md)
        local worktree_path=$(get_worktree_path "$name")

        # Stop agent if running
        stop_agent_process "$name" true 2>/dev/null || true

        # Arquivar artefatos
        cp "$worktree_path/DONE.md" "$archive_dir/${name}_DONE.md" 2>/dev/null || true
        cp "$worktree_path/PROGRESS.md" "$archive_dir/${name}_PROGRESS.md" 2>/dev/null || true
        cp "$worktree_path/BLOCKED.md" "$archive_dir/${name}_BLOCKED.md" 2>/dev/null || true
        cp "$worktree_path/.claude/AGENTS_USED" "$archive_dir/${name}_AGENTS.txt" 2>/dev/null || true

        # Remover worktree
        if git worktree remove "$worktree_path" --force 2>/dev/null; then
            log_success "Removido: $name"
            ((removed++))
        else
            log_warn "Falha ao remover: $name"
        fi

        # Move task to file
        mv "$task_file" "$archive_dir/"
    done

    # Limpar logs e PIDs
    rm -f "$ORCHESTRATION_DIR/logs"/*.log
    rm -f "$ORCHESTRATION_DIR/pids"/*

    # Clean orphaned worktrees
    git worktree prune 2>/dev/null

    log_success "Cleanup completo! ($removed worktrees removidas)"
    log_info "Artefatos arquivados em: $archive_dir"

    # Registrar evento
    echo "[$(timestamp)] CLEANUP: $removed worktrees archived" >> "$EVENTS_FILE"
}

cmd_show_memory() {
    if file_exists "$MEMORY_FILE"; then
        cat "$MEMORY_FILE"
    else
        log_error "PROJECT_MEMORY.md não encontrado"
        return 1
    fi
}

cmd_update_memory() {
    local bump_version=false
    local generate_changelog=false
    local commits_count=5

    # Parse argumentos
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --bump|--version) bump_version=true; shift ;;
            --changelog) generate_changelog=true; shift ;;
            --commits) commits_count="$2"; shift 2 ;;
            --full) bump_version=true; generate_changelog=true; shift ;;
            *) shift ;;
        esac
    done

    log_step "Atualizando memória..."

    if ! file_exists "$MEMORY_FILE"; then
        log_error "PROJECT_MEMORY.md não encontrado"
        return 1
    fi

    local current_date=$(date '+%Y-%m-%d %H:%M')
    local escaped_date=$(escape_sed "$current_date")

    # 1. Update timestamp (support both English and Portuguese labels)
    local ts_label="Last update"
    if grep -q '> \*\*Última atualização\*\*:' "$MEMORY_FILE" 2>/dev/null; then
        ts_label="Última atualização"
    fi
    if [[ "$(uname)" == "Darwin" ]]; then
        sed -i '' "s|> \*\*${ts_label}\*\*:.*|> **${ts_label}**: $escaped_date|" "$MEMORY_FILE"
    else
        sed -i "s|> \*\*${ts_label}\*\*:.*|> **${ts_label}**: $escaped_date|" "$MEMORY_FILE"
    fi
    log_info "Timestamp updated"

    # 2. Increment version (if requested)
    if [[ "$bump_version" == "true" ]]; then
        _bump_memory_version
    fi

    # 3. Generate changelog (if requested)
    if [[ "$generate_changelog" == "true" ]]; then
        _generate_changelog "$commits_count"
    fi

    log_success "Memória atualizada"
}

# Increment version in X.Y format
_bump_memory_version() {
    # Support both English and Portuguese labels
    local current_version=$(grep -o '> \*\*\(Version\|Versão\)\*\*: [0-9.]*' "$MEMORY_FILE" | grep -o '[0-9.]*$')

    if [[ -z "$current_version" ]]; then
        log_warn "Version not found in memory"
        return 0
    fi

    # Detect which label is used (English or Portuguese)
    local label="Version"
    if grep -q '> \*\*Versão\*\*:' "$MEMORY_FILE" 2>/dev/null; then
        label="Versão"
    fi

    # Parse major.minor.patch
    local major=$(echo "$current_version" | cut -d. -f1)
    local minor=$(echo "$current_version" | cut -d. -f2)
    local patch=$(echo "$current_version" | cut -d. -f3)

    # Increment: if patch exists, bump patch; otherwise bump minor
    local new_version
    if [[ -n "$patch" ]]; then
        patch=$((patch + 1))
        new_version="${major}.${minor}.${patch}"
    else
        minor=$((minor + 1))
        new_version="${major}.${minor}"
    fi

    # Update in file
    if [[ "$(uname)" == "Darwin" ]]; then
        sed -i '' "s|> \*\*${label}\*\*: $current_version|> **${label}**: $new_version|" "$MEMORY_FILE"
    else
        sed -i "s|> \*\*${label}\*\*: $current_version|> **${label}**: $new_version|" "$MEMORY_FILE"
    fi

    log_info "Version: $current_version → $new_version"
}

# Generate changelog based on recent commits
_generate_changelog() {
    local count=${1:-5}
    local changelog_file="$ORCHESTRATION_DIR/CHANGELOG.md"
    local today=$(date '+%Y-%m-%d')

    log_info "Gerando changelog (últimos $count commits)..."

    # Get recent commits
    local commits=$(git log --oneline -n "$count" --pretty=format:"- %s (%h)" 2>/dev/null)

    if [[ -z "$commits" ]]; then
        log_warn "Nenhum commit encontrado"
        return 0
    fi

    # Create or update changelog
    local entry="
## [$today]

$commits
"

    if file_exists "$changelog_file"; then
        # Insert after title
        local temp_file=$(mktemp)
        {
            head -n 2 "$changelog_file"
            echo "$entry"
            tail -n +3 "$changelog_file"
        } > "$temp_file"
        mv "$temp_file" "$changelog_file"
    else
        # Create new
        cat > "$changelog_file" << EOF
# Changelog

$entry
EOF
    fi

    log_info "Changelog atualizado: $changelog_file"

    # Registrar evento
    echo "[$(timestamp)] CHANGELOG: $count commits adicionados" >> "$EVENTS_FILE"
}

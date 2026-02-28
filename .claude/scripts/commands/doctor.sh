#!/bin/bash
# =============================================
# COMMAND: doctor - System diagnostics
# =============================================

cmd_doctor() {
    log_header "ORCHESTRATOR DIAGNOSTICS"

    local errors=0
    local warnings=0

    # 1. Git
    echo -e "${YELLOW}[1/8] Checking Git...${NC}"
    if command -v git &>/dev/null; then
        local git_version=$(git --version | awk '{print $3}')
        log_success "Git installed: $git_version"
    else
        log_error "Git not found"
        ((errors++))
    fi

    # 2. Claude CLI
    echo -e "${YELLOW}[2/8] Checking Claude CLI...${NC}"
    if command -v claude &>/dev/null; then
        local claude_version=$(claude --version 2>/dev/null || echo "unknown version")
        log_success "Claude CLI installed: $claude_version"
    else
        log_error "Claude CLI not found"
        log_info "Install at: https://claude.ai/download"
        ((errors++))
    fi

    # 3. Git Repository
    echo -e "${YELLOW}[3/8] Checking repository...${NC}"
    if git rev-parse --is-inside-work-tree &>/dev/null; then
        log_success "Valid Git repository"
        local branch=$(current_branch)
        log_info "Current branch: $branch"
    else
        log_error "Not a Git repository"
        ((errors++))
    fi

    # 4. Directory structure
    echo -e "${YELLOW}[4/8] Checking structure...${NC}"
    local dirs_ok=true
    for dir in "$CLAUDE_DIR" "$ORCHESTRATION_DIR" "$AGENTS_DIR"; do
        if dir_exists "$dir"; then
            log_success "Directory exists: $(basename "$dir")"
        else
            log_warn "Directory missing: $(basename "$dir")"
            ((warnings++))
            dirs_ok=false
        fi
    done

    if [[ "$dirs_ok" == "false" ]]; then
        log_info "Run: $0 init"
    fi

    # 5. Worktrees
    echo -e "${YELLOW}[5/8] Checking worktrees...${NC}"
    local worktree_count=$(git worktree list 2>/dev/null | wc -l | tr -d ' ')
    log_info "Total worktrees: $worktree_count"

    # Check for orphans
    local orphans=0
    while IFS= read -r line; do
        local path=$(echo "$line" | awk '{print $1}')
        if [[ ! -d "$path" ]] && [[ "$path" != "$PROJECT_ROOT" ]]; then
            log_warn "Orphaned worktree: $path"
            ((orphans++))
        fi
    done < <(git worktree list 2>/dev/null)

    if [[ $orphans -gt 0 ]]; then
        log_warn "$orphans orphaned worktree(s) found"
        log_info "Run: git worktree prune"
        ((warnings++))
    else
        log_success "No orphaned worktrees"
    fi

    # 6. Processes
    echo -e "${YELLOW}[6/8] Checking processes...${NC}"
    local running=0
    local zombies=0

    for pidfile in "$ORCHESTRATION_DIR/pids"/*.pid; do
        [[ -f "$pidfile" ]] || continue
        local name=$(basename "$pidfile" .pid)
        local pid=$(cat "$pidfile")

        if kill -0 "$pid" 2>/dev/null; then
            log_info "Process running: $name (PID: $pid)"
            ((running++))
        else
            log_warn "Orphaned PID file: $name (process dead)"
            ((zombies++))
        fi
    done

    if [[ $zombies -gt 0 ]]; then
        log_warn "$zombies orphaned PID file(s)"
        log_info "Run: rm -f $ORCHESTRATION_DIR/pids/*.pid"
        ((warnings++))
    fi

    log_info "$running agent(s) running"

    # 7. Disk space
    echo -e "${YELLOW}[7/8] Checking disk space...${NC}"
    local disk_free=$(df -h . 2>/dev/null | tail -1 | awk '{print $4}')
    local disk_pct=$(df -h . 2>/dev/null | tail -1 | awk '{print $5}' | tr -d '%')

    if [[ $disk_pct -gt 90 ]]; then
        log_error "Disk almost full: $disk_pct% used"
        ((errors++))
    elif [[ $disk_pct -gt 80 ]]; then
        log_warn "Disk low on space: $disk_pct% used"
        ((warnings++))
    else
        log_success "Disk space OK: $disk_free free"
    fi

    # 8. Logs
    echo -e "${YELLOW}[8/8] Checking logs...${NC}"
    local log_count=$(ls -1 "$ORCHESTRATION_DIR/logs"/*.log 2>/dev/null | wc -l | tr -d ' ')
    local log_size=$(du -sh "$ORCHESTRATION_DIR/logs" 2>/dev/null | awk '{print $1}')

    log_info "$log_count log file(s) ($log_size)"

    # Check large logs
    for logfile in "$ORCHESTRATION_DIR/logs"/*.log; do
        [[ -f "$logfile" ]] || continue
        local size=$(stat -f%z "$logfile" 2>/dev/null || stat -c%s "$logfile" 2>/dev/null || echo 0)
        if [[ $size -gt 10485760 ]]; then  # 10MB
            log_warn "Large log: $(basename "$logfile") ($(numfmt --to=iec $size 2>/dev/null || echo "${size}B"))"
            ((warnings++))
        fi
    done

    # Summary
    echo ""
    log_separator

    if [[ $errors -eq 0 ]] && [[ $warnings -eq 0 ]]; then
        echo -e "${GREEN}✅ SYSTEM HEALTHY${NC}"
        echo "No problems found."
        return 0
    elif [[ $errors -eq 0 ]]; then
        echo -e "${YELLOW}⚠️  SYSTEM HAS WARNINGS${NC}"
        echo "$warnings warning(s) found"
        return 0
    else
        echo -e "${RED}❌ PROBLEMS FOUND${NC}"
        echo "$errors error(s), $warnings warning(s)"
        return 1
    fi
}

cmd_doctor_fix() {
    log_step "Fixing problems automatically..."

    # Clean orphaned PIDs
    for pidfile in "$ORCHESTRATION_DIR/pids"/*.pid; do
        [[ -f "$pidfile" ]] || continue
        local pid=$(cat "$pidfile")
        if ! kill -0 "$pid" 2>/dev/null; then
            rm -f "$pidfile"
            rm -f "${pidfile%.pid}.started"
            log_info "Removed orphaned PID: $(basename "$pidfile")"
        fi
    done

    # Clean orphaned worktrees
    git worktree prune 2>/dev/null
    log_info "Orphaned worktrees removed"

    # Rotate large logs
    rotate_logs

    log_success "Fixes applied"
    log_info "Run '$0 doctor' to verify"
}

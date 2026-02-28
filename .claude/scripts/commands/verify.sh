#!/bin/bash
# =============================================
# COMMAND: verify/review/pre-merge/report
# =============================================

cmd_verify() {
    local name=$1

    if [[ -z "$name" ]]; then
        log_error "Usage: $0 verify <worktree>"
        return 1
    fi

    local worktree_path=$(get_worktree_path "$name")
    local errors=0
    local warnings=0

    log_header "VERIFICATION: $name"

    # 1. Check if worktree exists
    if ! dir_exists "$worktree_path"; then
        log_error "Worktree not found: $worktree_path"
        return 1
    fi

    # 2. Check DONE.md
    echo -e "${YELLOW}[1/5] Checking DONE.md...${NC}"
    if file_exists "$worktree_path/DONE.md"; then
        log_success "DONE.md exists"

        local done_errors=0
        validate_done_file "$worktree_path/DONE.md" || done_errors=$?

        if [[ $done_errors -gt 0 ]]; then
            log_warn "DONE.md incomplete ($done_errors missing sections)"
            ((warnings++))
        fi
    else
        log_error "DONE.md not found"
        ((errors++))
    fi

    # 3. Check pending files
    echo -e "${YELLOW}[2/5] Checking pending files...${NC}"
    local uncommitted=$(cd "$worktree_path" && git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    if [[ $uncommitted -gt 0 ]]; then
        log_warn "$uncommitted uncommitted file(s)"
        ((warnings++))
        (cd "$worktree_path" && git status --short)
    else
        log_success "All files committed"
    fi

    # 4. Check if there is BLOCKED.md
    echo -e "${YELLOW}[3/5] Checking blockers...${NC}"
    if file_exists "$worktree_path/BLOCKED.md"; then
        log_error "Task is BLOCKED"
        cat "$worktree_path/BLOCKED.md"
        ((errors++))
    else
        log_success "No blockers"
    fi

    # 5. Check tests
    echo -e "${YELLOW}[4/5] Checking tests...${NC}"
    local has_tests=false

    if file_exists "$worktree_path/package.json"; then
        local test_script=$(grep -o '"test"' "$worktree_path/package.json" 2>/dev/null || echo "")
        if [[ -n "$test_script" ]]; then
            has_tests=true
            log_info "Found: npm test"
        fi
    fi

    if file_exists "$worktree_path/Makefile"; then
        if grep -q "^test:" "$worktree_path/Makefile" 2>/dev/null; then
            has_tests=true
            log_info "Found: make test"
        fi
    fi

    if ! $has_tests; then
        log_info "No test script detected"
    fi

    # 6. Check commits
    echo -e "${YELLOW}[5/6] Checking commits...${NC}"
    local commit_count=$(cd "$worktree_path" && count_commits_since main)
    log_info "$commit_count commit(s) since main"

    # 7. Check spec traceability (SDD)
    echo -e "${YELLOW}[6/6] Checking SDD traceability...${NC}"
    local task_file="$ORCHESTRATION_DIR/tasks/${name}.md"
    if grep -q "spec-ref:" "$task_file" 2>/dev/null; then
        local spec_ref=$(grep "spec-ref:" "$task_file" | head -1 | sed 's/.*spec-ref: *//')
        if file_exists "$PROJECT_ROOT/$spec_ref"; then
            log_success "Task traceable to spec: $spec_ref"
        else
            log_warn "Referenced spec not found: $spec_ref"
            ((warnings++))
        fi
    else
        log_info "No SDD reference (direct task mode)"
    fi

    # Summary
    echo ""
    log_separator
    if [[ $errors -eq 0 ]] && [[ $warnings -eq 0 ]]; then
        echo -e "${GREEN}✅ VERIFICATION PASSED${NC}"
        return 0
    elif [[ $errors -eq 0 ]]; then
        echo -e "${YELLOW}⚠️  VERIFICATION WITH WARNINGS: $warnings warning(s)${NC}"
        return 0
    else
        echo -e "${RED}❌ VERIFICATION FAILED: $errors error(s), $warnings warning(s)${NC}"
        return 1
    fi
}

cmd_verify_all() {
    local failed=0
    local passed=0

    for task_file in "$ORCHESTRATION_DIR/tasks"/*.md; do
        [[ -f "$task_file" ]] || continue
        local name=$(basename "$task_file" .md)

        if cmd_verify "$name"; then
            ((passed++))
        else
            ((failed++))
        fi
    done

    echo ""
    log_separator
    echo -e "📊 SUMMARY: ✅ $passed passed | ❌ $failed failed"
    log_separator

    [[ $failed -eq 0 ]]
}

cmd_review() {
    local name=$1

    if [[ -z "$name" ]]; then
        log_error "Usage: $0 review <worktree>"
        return 1
    fi

    local worktree_path=$(get_worktree_path "$name")
    local review_name="review-$name"

    if ! dir_exists "$worktree_path"; then
        log_error "Worktree not found: $worktree_path"
        return 1
    fi

    if ! file_exists "$worktree_path/DONE.md"; then
        log_error "Worktree is not complete (no DONE.md)"
        return 1
    fi

    log_step "Creating review for: $name"

    # Get branch
    local source_branch=$(cd "$worktree_path" && current_branch)

    # Create review worktree
    cmd_setup "$review_name" --preset review --from "$source_branch" || return 1

    # Create review task
    local review_task="$ORCHESTRATION_DIR/tasks/$review_name.md"

    cat > "$review_task" << EOF
# Review: $name

## Objective
Review the code developed in worktree \`$name\`.

## Branch
\`$source_branch\`

## Checklist

### Code Quality
- [ ] Code follows best practices
- [ ] Clear naming
- [ ] Small functions

### Security
- [ ] No vulnerabilities
- [ ] Inputs validated
- [ ] No hardcoded secrets

### Architecture
- [ ] Follows project patterns
- [ ] Good separation of concerns

### Tests
- [ ] Tests exist
- [ ] Tests make sense

## Files to Review
$(cd "$worktree_path" && files_changed_since main | sed 's/^/- /')

## Deliverable
Create REVIEW.md with issues and suggestions.
EOF

    log_success "Review created: $review_name"
    log_info "Run: $0 start $review_name"
}

cmd_pre_merge() {
    log_step "Running pre-merge checks..."

    local all_passed=true
    local worktrees=()

    # List worktrees (ignore reviews)
    for task_file in "$ORCHESTRATION_DIR/tasks"/*.md; do
        [[ -f "$task_file" ]] || continue
        local name=$(basename "$task_file" .md)
        [[ "$name" == review-* ]] && continue
        worktrees+=("$name")
    done

    if [[ ${#worktrees[@]} -eq 0 ]]; then
        log_error "No worktrees found"
        return 1
    fi

    log_header "PRE-MERGE CHECK"

    # 1. Check all
    echo -e "${YELLOW}[1/3] Checking worktrees...${NC}"
    for name in "${worktrees[@]}"; do
        if cmd_verify "$name" > /dev/null 2>&1; then
            log_success "$name: OK"
        else
            log_error "$name: FAILED"
            all_passed=false
        fi
    done

    # 2. Check conflicts
    echo ""
    echo -e "${YELLOW}[2/3] Checking potential conflicts...${NC}"

    local all_files=""
    for name in "${worktrees[@]}"; do
        local worktree_path=$(get_worktree_path "$name")
        local files=$(cd "$worktree_path" && files_changed_since main 2>/dev/null)
        all_files="$all_files"$'\n'"$files"
    done

    local duplicates=$(echo "$all_files" | sort | uniq -d | grep -v '^$' || true)

    if [[ -n "$duplicates" ]]; then
        log_warn "Files in multiple worktrees:"
        echo "$duplicates" | while read -r file; do
            [[ -n "$file" ]] && echo "  - $file"
        done
    else
        log_success "No conflicting files"
    fi

    # 3. Simulate merge
    echo ""
    echo -e "${YELLOW}[3/3] Simulating merge...${NC}"

    for name in "${worktrees[@]}"; do
        local branch="feature/$name"
        if simulate_merge "$branch" main; then
            log_success "$branch: merge OK"
        else
            log_error "$branch: conflict detected"
            all_passed=false
        fi
    done

    # Summary
    echo ""
    log_separator
    if $all_passed; then
        echo -e "${GREEN}✅ PRE-MERGE PASSED${NC}"
        return 0
    else
        echo -e "${RED}❌ PRE-MERGE FAILED${NC}"
        return 1
    fi
}

cmd_report() {
    log_step "Generating report..."

    local report_file="$ORCHESTRATION_DIR/REPORT_$(date '+%Y%m%d_%H%M%S').md"

    cat > "$report_file" << EOF
# Development Report

> **Generated at**: $(date '+%Y-%m-%d %H:%M:%S')
> **Project**: $PROJECT_NAME

---

## Summary

EOF

    local total=0 done=0 blocked=0

    for task_file in "$ORCHESTRATION_DIR/tasks"/*.md; do
        [[ -f "$task_file" ]] || continue
        ((total++))
        local name=$(basename "$task_file" .md)
        local worktree_path=$(get_worktree_path "$name")

        file_exists "$worktree_path/DONE.md" && ((done++))
        file_exists "$worktree_path/BLOCKED.md" && ((blocked++))
    done

    cat >> "$report_file" << EOF
| Metric       | Value |
|--------------|-------|
| Total        | $total |
| Completed    | $done |
| Blocked      | $blocked |
| In progress  | $((total - done - blocked)) |

---

## Details

EOF

    for task_file in "$ORCHESTRATION_DIR/tasks"/*.md; do
        [[ -f "$task_file" ]] || continue
        local name=$(basename "$task_file" .md)
        local worktree_path=$(get_worktree_path "$name")

        echo "### $name" >> "$report_file"
        echo "" >> "$report_file"

        # Agents
        if file_exists "$worktree_path/.claude/AGENTS_USED"; then
            echo "**Agents**: $(cat "$worktree_path/.claude/AGENTS_USED")" >> "$report_file"
            echo "" >> "$report_file"
        fi

        # Status
        local status=$(get_agent_status "$name")
        echo "**Status**: $status" >> "$report_file"
        echo "" >> "$report_file"

        # DONE.md
        if file_exists "$worktree_path/DONE.md"; then
            echo "<details><summary>DONE.md</summary>" >> "$report_file"
            echo "" >> "$report_file"
            cat "$worktree_path/DONE.md" >> "$report_file"
            echo "</details>" >> "$report_file"
        fi

        echo "" >> "$report_file"
        echo "---" >> "$report_file"
        echo "" >> "$report_file"
    done

    log_success "Report generated: $report_file"
    cat "$report_file"
}

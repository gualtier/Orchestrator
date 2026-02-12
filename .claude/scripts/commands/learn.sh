#!/bin/bash
# =============================================
# LEARN COMMAND - Extract and incorporate learnings
# =============================================

# Load learning library
source "$LIB_DIR/learning.sh"

# =============================================
# MAIN LEARN COMMAND
# =============================================

cmd_learn() {
    local subcmd=${1:-help}
    [[ $# -gt 0 ]] && shift

    case "$subcmd" in
        extract)
            cmd_learn_extract "$@"
            ;;
        review)
            cmd_learn_review "$@"
            ;;
        add-role)
            cmd_learn_add_role "$@"
            ;;
        show)
            cmd_learn_show "$@"
            ;;
        help|--help|-h)
            cmd_learn_help
            ;;
        *)
            log_error "Unknown subcommand: $subcmd"
            cmd_learn_help
            return 1
            ;;
    esac
}

# =============================================
# EXTRACT SUBCOMMAND
# =============================================

cmd_learn_extract() {
    local last_n=5
    local extract_all=false
    local auto_apply=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --last) last_n="$2"; shift 2 ;;
            --all) extract_all=true; shift ;;
            --apply) auto_apply=true; shift ;;
            *) shift ;;
        esac
    done

    log_step "📚 Extracting learnings from completed tasks..."

    # Check if archive directory exists
    local archive_dir="$ORCHESTRATION_DIR/archive"
    if ! dir_exists "$archive_dir"; then
        log_warn "No archive directory found. Complete and merge tasks first."
        return 0
    fi

    # Get list of archived tasks
    local task_count=$(count_archived_tasks)
    if [[ "$task_count" == "0" ]]; then
        log_warn "No archived tasks found. Complete and merge tasks first."
        return 0
    fi

    log_info "Found $task_count archived task(s)"

    # Determine which tasks to process
    local tasks_to_process
    if [[ "$extract_all" == "true" ]]; then
        tasks_to_process=$(get_archived_tasks)
        log_info "Extracting from all $task_count tasks"
    else
        tasks_to_process=$(get_archived_tasks | head -n "$last_n")
        local actual_count=$(echo "$tasks_to_process" | wc -l | tr -d ' ')
        log_info "Extracting from last $actual_count task(s)"
    fi

    # Ensure pending directory exists
    ensure_dir "$LEARNINGS_PENDING"

    # Process each task
    local pattern_count=0
    local pitfall_count=0
    local effectiveness_count=0

    while IFS= read -r task_name; do
        [[ -z "$task_name" ]] && continue

        log_info "Processing: $task_name"

        # Get task files
        local files=$(get_task_files "$task_name")
        local done_file=$(echo "$files" | cut -d'|' -f1)
        local progress_file=$(echo "$files" | cut -d'|' -f2)
        local agents_file=$(echo "$files" | cut -d'|' -f3)

        # Extract information
        local done_data=$(extract_from_done_file "$done_file" "$task_name")
        local progress_data=$(extract_from_progress_file "$progress_file")
        local agents=$(extract_from_agents_file "$agents_file")

        # Parse data
        local summary=$(echo "$done_data" | cut -d'|' -f1)
        local files_changed=$(echo "$done_data" | cut -d'|' -f2)
        local testing=$(echo "$done_data" | cut -d'|' -f3)
        local problems=$(echo "$done_data" | cut -d'|' -f4)
        local solutions=$(echo "$done_data" | cut -d'|' -f5)

        # Skip if no meaningful data
        if [[ -z "$summary" && -z "$problems" ]]; then
            log_info "  No extractable insights"
            continue
        fi

        # Categorize learning
        local category=$(categorize_learning "$summary" "$files_changed" "$problems")

        # Generate learning markdown
        local learning_content=""
        local preset=$(echo "$agents" | cut -d',' -f1 | sed 's/-developer$//' | sed 's/-specialist$//')

        case "$category" in
            pattern)
                learning_content=$(generate_pattern_markdown "$task_name" "$preset" "$summary" "$files_changed")
                ((pattern_count++))
                ;;
            pitfall)
                learning_content=$(generate_pitfall_markdown "$task_name" "$agents" "$problems" "$solutions")
                ((pitfall_count++))
                ;;
            effectiveness)
                learning_content=$(generate_effectiveness_markdown "$preset" "$task_name" "yes")
                ((effectiveness_count++))
                ;;
        esac

        # Save to pending directory
        if [[ -n "$learning_content" ]]; then
            local pending_file="$LEARNINGS_PENDING/${category}_${task_name}_$(date +%Y%m%d_%H%M%S).md"
            echo "$learning_content" > "$pending_file"
            log_info "  Saved ${category} learning"
        fi

    done <<< "$tasks_to_process"

    # Summary
    local total_insights=$((pattern_count + pitfall_count + effectiveness_count))

    if [[ $total_insights -eq 0 ]]; then
        log_warn "No insights extracted"
        return 0
    fi

    log_success "Extraction complete!"
    echo ""
    echo "Found insights:"
    [[ $pattern_count -gt 0 ]] && echo "  • $pattern_count architecture pattern(s)"
    [[ $pitfall_count -gt 0 ]] && echo "  • $pitfall_count common pitfall(s)"
    [[ $effectiveness_count -gt 0 ]] && echo "  • $effectiveness_count agent effectiveness note(s)"
    echo ""
    echo "Learnings saved to: $LEARNINGS_PENDING/"
    echo ""

    # Auto-apply if requested
    if [[ "$auto_apply" == "true" ]]; then
        log_info "Auto-applying learnings..."
        cmd_learn_review --auto
    else
        log_info "💡 Review and apply with: $0 learn review"
    fi
}

# =============================================
# REVIEW SUBCOMMAND
# =============================================

cmd_learn_review() {
    local auto_apply=false

    # Parse arguments
    if [[ "$1" == "--auto" ]]; then
        auto_apply=true
    fi

    log_step "📚 Reviewing pending learnings..."

    # Check for pending learnings
    if ! dir_exists "$LEARNINGS_PENDING" || [[ -z "$(ls -A "$LEARNINGS_PENDING" 2>/dev/null)" ]]; then
        log_warn "No pending learnings found"
        log_info "Extract learnings first with: $0 learn extract"
        return 0
    fi

    local pending_files=$(find "$LEARNINGS_PENDING" -name "*.md" -type f | sort)
    local total_files=$(echo "$pending_files" | wc -l | tr -d ' ')

    log_info "Found $total_files pending learning(s)"
    echo ""

    # Backup CLAUDE.md before modifications
    backup_claude_md || return 1

    # Ensure learnings section exists
    if ! has_learnings_section; then
        log_info "Creating PROJECT LEARNINGS section in CLAUDE.md..."
        create_learnings_section
    fi

    local applied_count=0
    local skipped_count=0
    local current=1

    while IFS= read -r learning_file; do
        [[ -z "$learning_file" ]] && continue

        local category=$(basename "$learning_file" | cut -d'_' -f1)
        local learning_content=$(cat "$learning_file")

        # Display learning
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "[$current/$total_files] $(echo "$category" | tr '[:lower:]' '[:upper:]') LEARNING"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "$learning_content"

        # Check for duplicate
        if check_duplicate_learning "$learning_content"; then
            log_warn "⚠️  Similar learning already exists in CLAUDE.md"
        fi

        # Prompt user (unless auto-apply)
        local choice="y"
        if [[ "$auto_apply" != "true" ]]; then
            read -p "Apply this learning? [y/n/s(kip)] " choice
        fi

        case "${choice,,}" in
            y|yes|"")
                # Append to CLAUDE.md
                append_learning_to_claude "$category" "$learning_content"
                log_success "✓ Applied"
                ((applied_count++))
                # Move to archive
                mv "$learning_file" "$LEARNINGS_ARCHIVE/"
                ;;
            s|skip)
                log_info "○ Skipped"
                ((skipped_count++))
                # Move to archive
                mv "$learning_file" "$LEARNINGS_ARCHIVE/"
                ;;
            *)
                log_info "○ Not applied"
                ((skipped_count++))
                ;;
        esac

        echo ""
        ((current++))

    done <<< "$pending_files"

    # Summary
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_success "Review complete!"
    echo ""
    echo "Results:"
    echo "  • Applied: $applied_count"
    echo "  • Skipped: $skipped_count"
    echo ""

    if [[ $applied_count -gt 0 ]]; then
        log_info "✓ CLAUDE.md updated with $applied_count learning(s)"
        log_info "💡 Commit changes with: git add CLAUDE.md && git commit -m 'docs(claude): incorporate learnings'"
    fi
}

# =============================================
# ADD-ROLE SUBCOMMAND
# =============================================

cmd_learn_add_role() {
    local role_file=$1
    local role_name=""

    # Parse arguments
    shift
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --name) role_name="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    # Validate input
    if [[ -z "$role_file" ]]; then
        log_error "Usage: $0 learn add-role <file> [--name \"Role Name\"]"
        return 1
    fi

    if ! file_exists "$role_file"; then
        log_error "File not found: $role_file"
        return 1
    fi

    # Default role name from filename
    if [[ -z "$role_name" ]]; then
        role_name=$(basename "$role_file" .md | tr '-' ' ' | sed 's/\b\w/\U&/g')
    fi

    log_step "📚 Adding specialized role: $role_name"

    # Read agent content
    local agent_content=$(cat "$role_file")

    # Preview
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Preview:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "$agent_content" | head -20
    if [[ $(echo "$agent_content" | wc -l) -gt 20 ]]; then
        echo "..."
        echo "[$(echo "$agent_content" | wc -l | tr -d ' ') lines total]"
    fi
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Confirm
    if ! confirm "Add this role to CLAUDE.md?" "n"; then
        log_info "Cancelled"
        return 0
    fi

    # Backup CLAUDE.md
    backup_claude_md || return 1

    # Ensure learnings section exists
    if ! has_learnings_section; then
        log_info "Creating PROJECT LEARNINGS section in CLAUDE.md..."
        create_learnings_section
    fi

    # Generate role markdown
    local date=$(date '+%Y-%m-%d')
    local role_markdown=$(cat << EOF
#### $role_name - Added: $date
**Source**: $(basename "$role_file")

$agent_content

**When to activate**: For tasks requiring this specialized expertise

EOF
)

    # Append to CLAUDE.md
    append_learning_to_claude "role" "$role_markdown"

    # Copy to roles directory
    ensure_dir "$LEARNINGS_ROLES"
    local target_file="$LEARNINGS_ROLES/$(basename "$role_file")"
    cp "$role_file" "$target_file"

    log_success "✓ Role added to CLAUDE.md"
    log_info "✓ Source saved to: $target_file"
    echo ""
    log_info "💡 Commit changes with: git add CLAUDE.md .claude/learnings/ && git commit -m 'feat(claude): add $role_name specialized role'"
}

# =============================================
# SHOW SUBCOMMAND
# =============================================

cmd_learn_show() {
    local claude_file="$PROJECT_ROOT/CLAUDE.md"

    if ! has_learnings_section; then
        log_warn "No PROJECT LEARNINGS section found in CLAUDE.md"
        log_info "Extract learnings first with: $0 learn extract"
        return 0
    fi

    log_step "📚 Current Project Learnings"
    echo ""

    # Extract and display learnings section
    sed -n '/^## 📚 PROJECT LEARNINGS/,/^## /p' "$claude_file" | sed '$d'
}

# =============================================
# HELP SUBCOMMAND
# =============================================

cmd_learn_help() {
    cat << 'EOF'

📚 Learn Command - Extract and incorporate project knowledge

USAGE:
  orch learn extract [options]  Extract insights from completed tasks
  orch learn review             Review pending learnings
  orch learn add-role <file>    Add external agent role to CLAUDE.md
  orch learn show               Show current learnings section

OPTIONS:
  --last N        Extract from last N tasks (default: 5)
  --all           Extract from all archived tasks
  --apply         Auto-apply without review (use with caution)
  --name "Name"   Name for external role (with add-role)

EXAMPLES:
  # Extract from last 5 tasks and review
  orch learn extract --last 5
  orch learn review

  # Extract from all tasks
  orch learn extract --all

  # Add custom agent role
  orch learn add-role ./my-agent.md --name "Domain Expert"

  # Extract and auto-apply
  orch learn extract --apply

  # Show current learnings
  orch learn show

WORKFLOW:
  1. Complete and merge tasks: orch merge && orch cleanup
  2. Extract learnings: orch learn extract
  3. Review and apply: orch learn review
  4. Commit changes: git add CLAUDE.md && git commit

Learn more: https://github.com/gualtier/Orchestrator

EOF
}

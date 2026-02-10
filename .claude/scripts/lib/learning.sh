#!/bin/bash
# =============================================
# LEARNING - Learning extraction and management
# =============================================

# =============================================
# FILE PARSING FUNCTIONS
# =============================================

# Extract information from DONE.md file
extract_from_done_file() {
    local done_file=$1
    local task_name=$2

    if ! file_exists "$done_file"; then
        return 1
    fi

    # Extract summary section (## Summary or ## Resumo)
    local summary=$(sed -n '/^## \(Summary\|Resumo\)/,/^##/p' "$done_file" | sed '1d;$d' | tr '\n' ' ' | xargs)

    # Extract files section (## Files or ## Arquivos)
    local files=$(sed -n '/^## \(Files\|Arquivos\)/,/^##/p' "$done_file" | grep '^-' | sed 's/^- //')

    # Extract testing section (## Test or ## Como Testar)
    local testing=$(sed -n '/^## \(.*Test.*\|Como Testar\)/,/^##/p' "$done_file" | sed '1d;$d' | tr '\n' ' ' | xargs)

    # Look for problems/solutions keywords
    local problems=$(grep -i -E "(problem|issue|challenge|blocker|error|failed)" "$done_file" | head -3)
    local solutions=$(grep -i -E "(solution|fixed|resolved|solved|workaround)" "$done_file" | head -3)

    # Output in format: summary|files|testing|problems|solutions
    echo "$summary|$files|$testing|$problems|$solutions"
}

# Extract information from PROGRESS.md file
extract_from_progress_file() {
    local progress_file=$1

    if ! file_exists "$progress_file"; then
        return 1
    fi

    # Look for blockers or challenges
    local blockers=$(grep -i -E "(blocked|blocker|challenge|difficult|issue)" "$progress_file" | head -5)

    # Extract completed steps
    local completed=$(grep -E "^\- \[x\]" "$progress_file" | head -5)

    echo "$blockers|$completed"
}

# Extract agents from AGENTS.txt file
extract_from_agents_file() {
    local agents_file=$1

    if ! file_exists "$agents_file"; then
        return 1
    fi

    # Read agents, one per line
    cat "$agents_file" | tr '\n' ',' | sed 's/,$//'
}

# =============================================
# CATEGORIZATION LOGIC
# =============================================

# Determine learning category based on content
categorize_learning() {
    local summary=$1
    local files=$2
    local problems=$3

    # Check for patterns (repeated file structures, architectural decisions)
    if echo "$files" | grep -q -E "(\.sh|\.md|lib/|commands/)"; then
        echo "pattern"
        return 0
    fi

    # Check for pitfalls (problems mentioned)
    if [[ -n "$problems" ]]; then
        echo "pitfall"
        return 0
    fi

    # Default to effectiveness tracking
    echo "effectiveness"
}

# =============================================
# MARKDOWN GENERATION
# =============================================

# Generate pattern learning markdown
generate_pattern_markdown() {
    local task_name=$1
    local preset=$2
    local summary=$3
    local files=$4
    local date=$(date '+%Y-%m-%d')

    cat << EOF
#### ${task_name} Pattern - Discovered: $date
**Context**: Task '$task_name' using preset '$preset'
**Pattern**: $summary
**Files**: $files
**When to use**: For similar scenarios involving these components

EOF
}

# Generate pitfall learning markdown
generate_pitfall_markdown() {
    local task_name=$1
    local agents=$2
    local problem=$3
    local solution=$4
    local date=$(date '+%Y-%m-%d')

    cat << EOF
#### ${task_name} Issue - Resolved: $date
**Task**: '$task_name'
**Agents**: $agents
**Problem**: $problem
**Solution**: $solution
**Prevention**: Review similar patterns before implementation

EOF
}

# Generate agent effectiveness markdown
generate_effectiveness_markdown() {
    local preset=$1
    local task_name=$2
    local success=$3
    local date=$(date '+%Y-%m-%d')

    cat << EOF
#### Preset '$preset' - Task: $task_name
**Completed**: $date
**Success**: $success
**Notes**: Effective for this type of task

EOF
}

# =============================================
# CLAUDE.MD MODIFICATION
# =============================================

# Backup CLAUDE.md
backup_claude_md() {
    local claude_file="$PROJECT_ROOT/CLAUDE.md"
    local backup_file="CLAUDE.md.backup.$(date +%Y%m%d_%H%M%S)"
    local backup_path="$LEARNINGS_ARCHIVE/backups/$backup_file"

    if ! file_exists "$claude_file"; then
        log_error "CLAUDE.md not found"
        return 1
    fi

    ensure_dir "$LEARNINGS_ARCHIVE/backups"
    cp "$claude_file" "$backup_path"

    # Keep only last 10 backups
    ls -t "$LEARNINGS_ARCHIVE/backups/" | tail -n +11 | xargs -I {} rm "$LEARNINGS_ARCHIVE/backups/{}" 2>/dev/null || true

    log_info "Backup created: $backup_file"
}

# Check if PROJECT LEARNINGS section exists in CLAUDE.md
has_learnings_section() {
    local claude_file="$PROJECT_ROOT/CLAUDE.md"
    grep -q "^## 📚 PROJECT LEARNINGS" "$claude_file"
}

# Create PROJECT LEARNINGS section in CLAUDE.md
create_learnings_section() {
    local claude_file="$PROJECT_ROOT/CLAUDE.md"
    local current_date=$(date '+%Y-%m-%d %H:%M')

    cat >> "$claude_file" << EOF

---

## 📚 PROJECT LEARNINGS

> Auto-updated by: \`orch learn\`
> Last extraction: $current_date

### Architecture Patterns

### Common Pitfalls & Solutions

### Agent Effectiveness Notes

### Custom Workflows

### Specialized Roles

EOF

    log_info "Created PROJECT LEARNINGS section"
}

# Append learning to appropriate subsection in CLAUDE.md
append_learning_to_claude() {
    local category=$1
    local learning_content=$2
    local claude_file="$PROJECT_ROOT/CLAUDE.md"

    # Determine target subsection
    local subsection=""
    case "$category" in
        pattern)
            subsection="### Architecture Patterns"
            ;;
        pitfall)
            subsection="### Common Pitfalls & Solutions"
            ;;
        effectiveness)
            subsection="### Agent Effectiveness Notes"
            ;;
        workflow)
            subsection="### Custom Workflows"
            ;;
        role)
            subsection="### Specialized Roles"
            ;;
        *)
            log_error "Unknown category: $category"
            return 1
            ;;
    esac

    # Create temp file
    local temp_file=$(mktemp)

    # Find subsection and insert learning content after it
    awk -v subsection="$subsection" -v content="$learning_content" '
        {
            print
            if ($0 == subsection) {
                print ""
                printf "%s", content
                inserted = 1
            }
        }
    ' "$claude_file" > "$temp_file"

    mv "$temp_file" "$claude_file"

    # Update timestamp
    update_learnings_timestamp
}

# Update "Last extraction" timestamp in CLAUDE.md
update_learnings_timestamp() {
    local claude_file="$PROJECT_ROOT/CLAUDE.md"
    local current_date=$(date '+%Y-%m-%d %H:%M')

    if [[ "$(uname)" == "Darwin" ]]; then
        sed -i '' "s|> Last extraction:.*|> Last extraction: $current_date|" "$claude_file"
    else
        sed -i "s|> Last extraction:.*|> Last extraction: $current_date|" "$claude_file"
    fi
}

# =============================================
# VALIDATION
# =============================================

# Check for duplicate learning content
check_duplicate_learning() {
    local learning_content=$1
    local claude_file="$PROJECT_ROOT/CLAUDE.md"

    # Extract first line of learning (usually the title)
    local title=$(echo "$learning_content" | head -1 | sed 's/^#### //')

    # Check if similar title exists
    if grep -q "#### $title" "$claude_file"; then
        return 0  # Duplicate found
    fi

    return 1  # No duplicate
}

# Validate learning markdown format
validate_learning_markdown() {
    local learning_content=$1

    # Check if it starts with ####
    if ! echo "$learning_content" | head -1 | grep -q "^####"; then
        return 1
    fi

    return 0
}

# =============================================
# EXTRACTION HELPERS
# =============================================

# Get list of archived tasks
get_archived_tasks() {
    local archive_dir="$ORCHESTRATION_DIR/archive"

    if ! dir_exists "$archive_dir"; then
        return 1
    fi

    # Find all *_DONE.md files and extract task names
    find "$archive_dir" -name "*_DONE.md" -type f | sed 's|.*/||; s|_DONE\.md$||'
}

# Count archived tasks
count_archived_tasks() {
    local archive_dir="$ORCHESTRATION_DIR/archive"

    if ! dir_exists "$archive_dir"; then
        echo "0"
        return
    fi

    find "$archive_dir" -name "*_DONE.md" -type f | wc -l | tr -d ' '
}

# Get archived task files
get_task_files() {
    local task_name=$1
    local archive_dir="$ORCHESTRATION_DIR/archive"

    echo "${archive_dir}/${task_name}_DONE.md|${archive_dir}/${task_name}_PROGRESS.md|${archive_dir}/${task_name}_AGENTS.txt"
}

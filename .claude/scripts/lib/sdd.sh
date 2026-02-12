#!/bin/bash
# =============================================
# SDD - Spec-Driven Development Library
# Inspired by GitHub Spec-Kit
# =============================================

# =============================================
# SPEC NUMBERING
# =============================================

# Get the next spec number (001, 002, ...)
next_spec_number() {
    local max=0

    # Scan active and archive directories
    for dir in "$SPECS_ACTIVE" "$SPECS_ARCHIVE"; do
        [[ -d "$dir" ]] || continue
        for spec_dir in "$dir"/*/; do
            [[ -d "$spec_dir" ]] || continue
            local name=$(basename "$spec_dir")
            local num=${name%%-*}
            # Remove leading zeros for arithmetic
            num=$((10#$num)) 2>/dev/null || continue
            [[ $num -gt $max ]] && max=$num
        done
    done

    printf "%03d" $((max + 1))
}

# Slugify a description into a valid directory name
slugify() {
    echo "$*" | tr '[:upper:]' '[:lower:]' | \
        sed 's/[^a-z0-9 ]//g' | \
        tr ' ' '-' | \
        sed 's/--*/-/g' | \
        sed 's/^-//;s/-$//' | \
        cut -c1-50
}

# Get spec directory path by number (searches active first, then archive)
spec_dir_for() {
    local number=$1

    # Search active
    for dir in "$SPECS_ACTIVE"/${number}-*/; do
        [[ -d "$dir" ]] && echo "${dir%/}" && return 0
    done

    # Search archive
    for dir in "$SPECS_ARCHIVE"/${number}-*/; do
        [[ -d "$dir" ]] && echo "${dir%/}" && return 0
    done

    return 1
}

# Get spec name (directory basename) by number
spec_name_for() {
    local dir
    dir=$(spec_dir_for "$1") || return 1
    basename "$dir"
}

# =============================================
# SPEC LIFECYCLE
# =============================================

# Detect spec status based on which files exist
get_spec_status() {
    local spec_dir=$1

    # Check if tasks were generated and worktrees exist
    local spec_name=$(basename "$spec_dir")
    local spec_num=${spec_name%%-*}
    local has_tasks=false

    if [[ -f "$spec_dir/tasks.md" ]]; then
        has_tasks=true
    fi

    if $has_tasks; then
        # Check if any worktrees are actively running or merged
        local task_count=0
        local done_count=0

        for task_file in "$ORCHESTRATION_DIR/tasks"/*.md; do
            [[ -f "$task_file" ]] || continue
            if grep -q "spec-ref:.*${spec_num}" "$task_file" 2>/dev/null; then
                ((task_count++))
                local task_name=$(basename "$task_file" .md)
                local worktree_path=$(get_worktree_path "$task_name")
                if [[ -f "$worktree_path/DONE.md" ]]; then
                    ((done_count++))
                fi
            fi
        done

        if [[ $task_count -gt 0 ]] && [[ $done_count -eq $task_count ]]; then
            echo "completed"
        elif [[ $task_count -gt 0 ]]; then
            echo "executing ($done_count/$task_count done)"
        else
            echo "tasks-ready"
        fi
    elif [[ -f "$spec_dir/plan.md" ]]; then
        echo "planned"
    elif [[ -f "$spec_dir/research.md" ]]; then
        echo "researched"
    elif [[ -f "$spec_dir/spec.md" ]]; then
        echo "specified"
    else
        echo "empty"
    fi
}

# List all active specs
list_active_specs() {
    [[ -d "$SPECS_ACTIVE" ]] || return 0

    for spec_dir in "$SPECS_ACTIVE"/*/; do
        [[ -d "$spec_dir" ]] || continue
        local name=$(basename "$spec_dir")
        local status=$(get_spec_status "$spec_dir")
        echo "$name|$status"
    done
}

# =============================================
# TEMPLATE RENDERING
# =============================================

# Render a template file with variable substitution
render_template() {
    local template_file=$1
    local output_file=$2
    shift 2

    if [[ ! -f "$template_file" ]]; then
        log_error "Template not found: $template_file"
        return 1
    fi

    cp "$template_file" "$output_file"

    # Process key=value pairs
    while [[ $# -gt 0 ]]; do
        local key="${1%%=*}"
        local value="${1#*=}"
        # Use | as sed delimiter to avoid issues with /
        sed -i '' "s|{{${key}}}|${value}|g" "$output_file" 2>/dev/null || \
            sed -i "s|{{${key}}}|${value}|g" "$output_file"
        shift
    done
}

# =============================================
# CONSTITUTION
# =============================================

# Check if constitution exists
has_constitution() {
    [[ -f "$CONSTITUTION_FILE" ]]
}

# Parse constitution articles into a list
list_constitution_articles() {
    [[ -f "$CONSTITUTION_FILE" ]] || return 1

    grep -E "^## Article" "$CONSTITUTION_FILE" | \
        sed 's/^## //' | \
        while IFS= read -r line; do
            echo "  $line"
        done
}

# =============================================
# CONSTITUTIONAL GATES
# =============================================

# Check constitutional gates against a plan
check_gates() {
    local plan_file=$1
    local spec_dir=$(dirname "$plan_file")
    local errors=0
    local warnings=0

    log_header "CONSTITUTIONAL GATES"

    # Gate 1: Research-First (Article I)
    echo -e "${YELLOW}[1/4] Research-First Gate...${NC}"
    if [[ -f "$spec_dir/research.md" ]]; then
        local research_lines=$(wc -l < "$spec_dir/research.md" | tr -d ' ')
        if [[ $research_lines -gt 15 ]]; then
            log_success "Research documented ($research_lines lines)"
        else
            log_warn "Research seems thin ($research_lines lines) - consider adding more detail"
            ((warnings++))
        fi
    else
        log_error "Research missing - research.md required before planning"
        ((errors++))
    fi

    # Gate 2: Simplicity (Article III)
    echo -e "${YELLOW}[2/4] Simplicity Gate...${NC}"
    local worktree_count=$(parse_worktree_mapping "$plan_file" | wc -l | tr -d ' ')

    if [[ $worktree_count -le 3 ]]; then
        log_success "Module count OK ($worktree_count modules)"
    elif [[ $worktree_count -le 5 ]]; then
        log_warn "Many modules ($worktree_count) - consider simplifying"
        ((warnings++))
    else
        log_error "Too many modules ($worktree_count) - constitution limits to 3 initial"
        ((errors++))
    fi

    # Gate 3: Test-First (Article II)
    echo -e "${YELLOW}[3/4] Test-First Gate...${NC}"
    if grep -qi "test strategy\|test plan\|testing" "$plan_file" 2>/dev/null; then
        log_success "Test strategy defined"
    else
        log_warn "No test strategy section found in plan"
        ((warnings++))
    fi

    # Gate 4: Spec Traceability (Article VI)
    echo -e "${YELLOW}[4/4] Spec Traceability Gate...${NC}"
    if [[ -f "$spec_dir/spec.md" ]]; then
        local req_count=$(grep -c "REQ-" "$spec_dir/spec.md" 2>/dev/null || echo 0)
        if [[ $req_count -gt 0 ]]; then
            log_success "Spec has $req_count traceable requirements"
        else
            log_warn "No REQ- markers in spec - add for traceability"
            ((warnings++))
        fi
    fi

    # Summary
    echo ""
    log_separator
    if [[ $errors -eq 0 ]] && [[ $warnings -eq 0 ]]; then
        echo -e "${GREEN}GATES PASSED${NC}"
        return 0
    elif [[ $errors -eq 0 ]]; then
        echo -e "${YELLOW}GATES PASSED WITH $warnings WARNING(S)${NC}"
        return 0
    else
        echo -e "${RED}GATES FAILED: $errors error(s), $warnings warning(s)${NC}"
        return 1
    fi
}

# =============================================
# TASK GENERATION (SDD -> ORCHESTRATOR BRIDGE)
# =============================================

# Parse the Worktree Mapping table from plan.md
# Returns lines of: module|worktree_name|preset
parse_worktree_mapping() {
    local plan_file=$1
    local in_table=false
    local header_passed=false

    while IFS= read -r line; do
        # Detect start of Worktree Mapping section
        if echo "$line" | grep -qi "## Worktree Mapping"; then
            in_table=true
            continue
        fi

        # Stop at next section (any heading level: ##, ###, etc.)
        if $in_table && echo "$line" | grep -qE "^#{2,} "; then
            break
        fi

        # Skip if not in table
        $in_table || continue

        # Skip empty lines
        [[ -z "$line" ]] && continue

        # Skip table header and separator
        if echo "$line" | grep -q "^|.*Module\|^|.*---"; then
            header_passed=true
            continue
        fi

        # Parse table rows
        if $header_passed && echo "$line" | grep -q "^|"; then
            local module=$(echo "$line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}')
            local wt_name=$(echo "$line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $3); print $3}')
            local preset=$(echo "$line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $4); print $4}')

            [[ -n "$module" ]] && echo "${module}|${wt_name}|${preset}"
        fi
    done < "$plan_file"
}

# Generate orchestrator task files from a plan
generate_tasks_from_plan() {
    local spec_dir=$1
    local plan_file="$spec_dir/plan.md"
    local spec_file="$spec_dir/spec.md"
    local spec_name=$(basename "$spec_dir")
    local spec_num=${spec_name%%-*}
    local generated=0

    if [[ ! -f "$plan_file" ]]; then
        log_error "No plan.md found in $spec_dir"
        return 1
    fi

    ensure_dir "$ORCHESTRATION_DIR/tasks"

    # Extract acceptance criteria from spec
    local acceptance_criteria=""
    if [[ -f "$spec_file" ]]; then
        acceptance_criteria=$(sed -n '/## Acceptance Criteria/,/^## /p' "$spec_file" | sed '$d' | tail -n +2)
    fi

    # Extract implementation order
    local impl_order=""
    impl_order=$(sed -n '/## Implementation Order/,/^## /p' "$plan_file" | sed '$d' | tail -n +2)

    # Parse worktree mapping and generate tasks
    local mappings
    mappings=$(parse_worktree_mapping "$plan_file")

    if [[ -z "$mappings" ]]; then
        log_warn "No Worktree Mapping table found in plan.md"
        log_info "Generating a single task from the plan..."

        # Fallback: generate single task
        local task_file="$ORCHESTRATION_DIR/tasks/${spec_name}.md"
        local feature_name=${spec_name#*-}

        cat > "$task_file" << TASKEOF
# Task: ${feature_name}

> spec-ref: .claude/specs/active/${spec_name}/spec.md

## Objective
Implement the feature as described in the specification.

## Spec Reference
See: \`.claude/specs/active/${spec_name}/spec.md\`

## Requirements
$(sed -n '/## Functional Requirements/,/^## /p' "$spec_file" 2>/dev/null | sed '$d' | tail -n +2 || echo "- [ ] See spec.md for full requirements")

## Acceptance Criteria
${acceptance_criteria:-"- [ ] See spec.md for acceptance criteria"}

## Scope

### DO
- [ ] Implement all requirements from spec
- [ ] Follow the technical approach in plan.md
- [ ] Write tests before implementation

### DON'T DO
$(sed -n '/## Out of Scope/,/^## /p' "$spec_file" 2>/dev/null | sed '$d' | tail -n +2 || echo "- See spec.md Out of Scope section")

## Completion Criteria
- [ ] All requirements implemented
- [ ] Tests passing
- [ ] DONE.md created with spec-ref
TASKEOF
        ((generated++))
    else
        # Generate one task per worktree mapping entry
        echo "$mappings" | while IFS='|' read -r module wt_name preset; do
            [[ -z "$wt_name" ]] && continue

            local task_file="$ORCHESTRATION_DIR/tasks/${wt_name}.md"

            cat > "$task_file" << TASKEOF
# Task: ${module}

> spec-ref: .claude/specs/active/${spec_name}/spec.md
> preset: ${preset}

## Objective
Implement the **${module}** module as described in the specification.

## Spec Reference
See: \`.claude/specs/active/${spec_name}/spec.md\`
Plan: \`.claude/specs/active/${spec_name}/plan.md\`

## Requirements
$(sed -n '/## Functional Requirements/,/^## /p' "$spec_file" 2>/dev/null | sed '$d' | tail -n +2 || echo "- [ ] See spec.md for full requirements")

## Acceptance Criteria
${acceptance_criteria:-"- [ ] See spec.md for acceptance criteria"}

## Scope

### DO
- [ ] Implement the ${module} module
- [ ] Follow the technical approach in plan.md
- [ ] Write tests before implementation
- [ ] Reference research.md for technology decisions

### DON'T DO
- Do NOT implement other modules
$(sed -n '/## Out of Scope/,/^## /p' "$spec_file" 2>/dev/null | sed '$d' | tail -n +2 | sed 's/^//' || echo "- See spec.md Out of Scope section")

### FILES
See plan.md Architecture section for file structure.

## Completion Criteria
- [ ] ${module} module implemented
- [ ] Tests passing
- [ ] DONE.md created with spec-ref
TASKEOF
            ((generated++))
            log_success "Generated task: ${wt_name}.md (preset: ${preset})"
        done
    fi

    # Save task summary in spec dir
    echo "# Generated Tasks" > "$spec_dir/tasks.md"
    echo "" >> "$spec_dir/tasks.md"
    echo "> Generated: $(date '+%Y-%m-%d %H:%M:%S')" >> "$spec_dir/tasks.md"
    echo "" >> "$spec_dir/tasks.md"

    if [[ -n "$mappings" ]]; then
        echo "| Worktree | Module | Preset |" >> "$spec_dir/tasks.md"
        echo "|----------|--------|--------|" >> "$spec_dir/tasks.md"
        echo "$mappings" | while IFS='|' read -r module wt_name preset; do
            echo "| ${wt_name} | ${module} | ${preset} |" >> "$spec_dir/tasks.md"
        done
    fi

    echo "" >> "$spec_dir/tasks.md"
    echo "## Next Steps" >> "$spec_dir/tasks.md"
    echo "" >> "$spec_dir/tasks.md"
    echo '```bash' >> "$spec_dir/tasks.md"
    if [[ -n "$mappings" ]]; then
        echo "$mappings" | while IFS='|' read -r module wt_name preset; do
            echo "orchestrate.sh setup ${wt_name} --preset ${preset}" >> "$spec_dir/tasks.md"
        done
    else
        echo "orchestrate.sh setup ${spec_name} --preset <choose-preset>" >> "$spec_dir/tasks.md"
    fi
    echo "orchestrate.sh start" >> "$spec_dir/tasks.md"
    echo '```' >> "$spec_dir/tasks.md"

    return 0
}

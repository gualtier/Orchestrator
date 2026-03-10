#!/bin/bash
# =============================================
# COMMAND: sdd (Spec-Driven Development)
# Inspired by GitHub Spec-Kit
# =============================================

cmd_sdd() {
    local subcmd=${1:-"help"}
    shift || true

    case "$subcmd" in
        init)         cmd_sdd_init "$@" ;;
        constitution) cmd_sdd_constitution "$@" ;;
        specify)      cmd_sdd_specify "$@" ;;
        research)     cmd_sdd_research "$@" ;;
        plan)         cmd_sdd_plan "$@" ;;
        tasks)        cmd_sdd_tasks "$@" ;;
        status)       cmd_sdd_status ;;
        gate)         cmd_sdd_gate "$@" ;;
        run)          cmd_sdd_run "$@" ;;
        validate)     cmd_sdd_validate "$@" ;;
        kaizen)       cmd_sdd_kaizen "$@" ;;
        archive)      cmd_sdd_archive "$@" ;;
        help|--help)  cmd_sdd_help ;;
        *)
            log_error "Unknown SDD subcommand: $subcmd"
            cmd_sdd_help
            return 1
            ;;
    esac
}

# =============================================
# SDD INIT
# =============================================

cmd_sdd_init() {
    log_header "SDD - INITIALIZING SPEC-DRIVEN DEVELOPMENT"

    # Create directory structure
    ensure_dir "$SPECS_DIR"
    ensure_dir "$SPECS_ACTIVE"
    ensure_dir "$SPECS_ARCHIVE"
    ensure_dir "$SPECS_TEMPLATES"

    log_success "Created directory structure"

    # Create default templates
    if ! _sdd_create_default_templates; then
        log_error "Failed to create default templates"
        return 1
    fi

    # Create default constitution if it doesn't exist
    if [[ ! -f "$CONSTITUTION_FILE" ]]; then
        _sdd_create_default_constitution
        log_success "Created default constitution: $CONSTITUTION_FILE"
    else
        log_info "Constitution already exists: $CONSTITUTION_FILE"
    fi

    echo ""
    log_separator
    echo -e "${GREEN}SDD initialized successfully!${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Review/customize your constitution:"
    echo "     $CONSTITUTION_FILE"
    echo ""
    echo "  2. Create your first spec:"
    echo "     orchestrate.sh sdd specify \"your feature description\""
    echo ""
}

# =============================================
# SDD CONSTITUTION
# =============================================

cmd_sdd_constitution() {
    if [[ ! -f "$CONSTITUTION_FILE" ]]; then
        log_info "No constitution found. Creating default..."
        ensure_dir "$SPECS_DIR"
        _sdd_create_default_constitution
        log_success "Created: $CONSTITUTION_FILE"
    fi

    log_header "PROJECT CONSTITUTION"
    cat "$CONSTITUTION_FILE"
    echo ""
    log_info "Edit at: $CONSTITUTION_FILE"
}

# =============================================
# SDD SPECIFY
# =============================================

cmd_sdd_specify() {
    local description="$*"

    if [[ -z "$description" ]]; then
        log_error "Usage: orchestrate.sh sdd specify \"feature description\""
        return 1
    fi

    # Ensure SDD is initialized
    if [[ ! -d "$SPECS_DIR" ]]; then
        log_info "SDD not initialized. Running init first..."
        cmd_sdd_init
    fi

    local number=$(next_spec_number)
    local slug=$(slugify "$description")
    if [[ -z "$slug" ]]; then
        log_error "Description produces empty slug after filtering special characters"
        log_info "Use alphanumeric characters in the description"
        return 1
    fi
    local spec_name="${number}-${slug}"
    local spec_dir="$SPECS_ACTIVE/$spec_name"

    ensure_dir "$spec_dir"

    # Render spec template
    local date_now=$(date '+%Y-%m-%d')

    if [[ -f "$SPECS_TEMPLATES/spec.md" ]]; then
        render_template "$SPECS_TEMPLATES/spec.md" "$spec_dir/spec.md" \
            "FEATURE_NAME=$description" \
            "SPEC_NUMBER=$number" \
            "DATE=$date_now"
    else
        # Inline fallback if template missing
        cat > "$spec_dir/spec.md" << SPECEOF
# Spec: ${description}

> Spec: ${number} | Created: ${date_now} | Status: DRAFT

## Problem Statement
[What needs to be solved and why]

## User Stories
- As a [user], I want [action] so that [benefit]

## Functional Requirements
- [ ] REQ-1: [description]

## Non-Functional Requirements
- [ ] Performance: [criteria]
- [ ] Security: [criteria]

## Acceptance Criteria
- [ ] AC-1: Given [context], when [action], then [result]

## Out of Scope
- [What NOT to do]

## Open Questions
- [NEEDS CLARIFICATION] [question]

## Dependencies
- [External dependencies or other specs]
SPECEOF
    fi

    log_header "SPEC CREATED: ${spec_name}"
    echo "  Path: $spec_dir/spec.md"
    echo ""
    echo "Next steps:"
    echo "  1. Refine the spec with Claude - fill in all sections"
    echo "  2. Mark [NEEDS CLARIFICATION] for uncertain areas"
    echo "  3. When ready, create research:"
    echo "     orchestrate.sh sdd research $number"
    echo ""

    # Log event
    if [[ -f "$EVENTS_FILE" ]]; then
        echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] SDD_SPECIFY: ${spec_name}" >> "$EVENTS_FILE"
    fi
}

# =============================================
# SDD RESEARCH (MANDATORY)
# =============================================

cmd_sdd_research() {
    local spec_number=$1

    if [[ -z "$spec_number" ]]; then
        log_error "Usage: orchestrate.sh sdd research <spec-number>"
        echo "  Example: orchestrate.sh sdd research 001"
        return 1
    fi

    local spec_dir
    spec_dir=$(spec_dir_for "$spec_number")
    if [[ $? -ne 0 ]] || [[ -z "$spec_dir" ]]; then
        log_error "Spec not found: $spec_number"
        log_info "Run 'orchestrate.sh sdd status' to see active specs"
        return 1
    fi

    if [[ ! -f "$spec_dir/spec.md" ]]; then
        log_error "No spec.md found. Run 'sdd specify' first."
        return 1
    fi

    local spec_name=$(basename "$spec_dir")
    local date_now=$(date '+%Y-%m-%d')

    if [[ -f "$spec_dir/research.md" ]]; then
        log_warn "research.md already exists: $spec_dir/research.md"
        if ! confirm "Overwrite?"; then
            log_info "Keeping existing research.md"
            return 0
        fi
    fi

    # Extract feature name from spec (fallback to slug from dir name)
    local feature_name
    feature_name=$(head -1 "$spec_dir/spec.md" 2>/dev/null | sed 's/^# Spec: //')
    if [[ -z "$feature_name" ]] || [[ "$feature_name" == "$(head -1 "$spec_dir/spec.md" 2>/dev/null)" ]]; then
        # sed didn't match "# Spec: " prefix — use spec dir name as fallback
        feature_name="${spec_name#*-}"
    fi

    if [[ -f "$SPECS_TEMPLATES/research.md" ]]; then
        render_template "$SPECS_TEMPLATES/research.md" "$spec_dir/research.md" \
            "FEATURE_NAME=$feature_name" \
            "SPEC_NUMBER=$spec_number" \
            "DATE=$date_now" \
            "SPEC_PATH=.claude/specs/active/${spec_name}/spec.md"
    else
        # Inline fallback
        cat > "$spec_dir/research.md" << RESEOF
# Research: ${feature_name}

> Spec: ${spec_number} | Created: ${date_now}
> Spec Reference: .claude/specs/active/${spec_name}/spec.md

## Library Analysis
| Library | Version | Pros | Cons | Decision |
|---------|---------|------|------|----------|
| [lib]   | [ver]   | [+]  | [-]  | [use/skip] |

## Performance Considerations
- [Benchmarks, expected load, bottlenecks]

## Security Implications
- [Attack vectors, auth requirements, data sensitivity]

## Existing Patterns in Codebase
- [What already exists that can be reused]
- [Conventions and patterns to follow]

## Constraints & Limitations
- [Infrastructure limits, budget, timeline]
- [Team expertise gaps]

## Recommendations
[Summary of findings and recommended approach based on research]

## Sources
- [Links to docs, benchmarks, articles consulted]
RESEOF
    fi

    log_header "RESEARCH CREATED: ${spec_name}"
    echo "  Path: $spec_dir/research.md"
    echo ""
    echo "This is a MANDATORY step. Fill in the research with Claude:"
    echo "  - Investigate libraries, frameworks, tools"
    echo "  - Check performance benchmarks"
    echo "  - Analyze security implications"
    echo "  - Look for existing patterns in the codebase"
    echo ""
    echo "When research is complete:"
    echo "  orchestrate.sh sdd plan $spec_number"
    echo ""

    # Log event
    if [[ -f "$EVENTS_FILE" ]]; then
        echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] SDD_RESEARCH: ${spec_name}" >> "$EVENTS_FILE"
    fi
}

# =============================================
# SDD PLAN
# =============================================

cmd_sdd_plan() {
    local spec_number=$1

    if [[ -z "$spec_number" ]]; then
        log_error "Usage: orchestrate.sh sdd plan <spec-number>"
        return 1
    fi

    local spec_dir
    spec_dir=$(spec_dir_for "$spec_number")
    if [[ $? -ne 0 ]] || [[ -z "$spec_dir" ]]; then
        log_error "Spec not found: $spec_number"
        return 1
    fi

    # MANDATORY: Research gate
    if [[ ! -f "$spec_dir/research.md" ]]; then
        log_error "RESEARCH REQUIRED: research.md not found"
        echo ""
        echo "  The SDD workflow requires research before planning."
        echo "  Run: orchestrate.sh sdd research $spec_number"
        echo ""
        echo "  This ensures technical decisions are grounded in investigation,"
        echo "  not assumptions."
        return 1
    fi

    local spec_name=$(basename "$spec_dir")
    local date_now=$(date '+%Y-%m-%d')

    if [[ -f "$spec_dir/plan.md" ]]; then
        log_warn "plan.md already exists: $spec_dir/plan.md"
        if ! confirm "Overwrite?"; then
            return 0
        fi
    fi

    # Extract feature name from spec (fallback to slug from dir name)
    local feature_name
    feature_name=$(head -1 "$spec_dir/spec.md" 2>/dev/null | sed 's/^# Spec: //')
    if [[ -z "$feature_name" ]] || [[ "$feature_name" == "$(head -1 "$spec_dir/spec.md" 2>/dev/null)" ]]; then
        feature_name="${spec_name#*-}"
    fi

    if [[ -f "$SPECS_TEMPLATES/plan.md" ]]; then
        render_template "$SPECS_TEMPLATES/plan.md" "$spec_dir/plan.md" \
            "FEATURE_NAME=$feature_name" \
            "SPEC_NUMBER=$spec_number" \
            "DATE=$date_now" \
            "SPEC_PATH=.claude/specs/active/${spec_name}/spec.md" \
            "RESEARCH_PATH=.claude/specs/active/${spec_name}/research.md"
    else
        # Inline fallback
        cat > "$spec_dir/plan.md" << PLANEOF
# Plan: ${feature_name}

> Spec: ${spec_number} | Created: ${date_now}
> Spec Reference: .claude/specs/active/${spec_name}/spec.md
> Research Reference: .claude/specs/active/${spec_name}/research.md

## Technical Approach
[Chosen approach and rationale, grounded in research findings]

## Technology Decisions
| Decision | Choice | Rationale | Research Ref |
|----------|--------|-----------|--------------|
| [area]   | [tech] | [why]     | [section]    |

## Worktree Mapping
| Module | Worktree Name | Preset | Agents |
|--------|--------------|--------|--------|
| [module] | [name] | [preset] | [auto] |

## Architecture
[Architecture description]

## Data Model
[If applicable]

## API Contracts
[If applicable]

## Constitutional Gates
- [ ] Research-First: all decisions backed by research
- [ ] Simplicity: max 3 initial modules
- [ ] Test-First: tests defined before implementation
- [ ] Integration-First: tests with real environment

## Implementation Order
1. Phase 1: [parallel modules]
2. Phase 2: [dependent modules]

## Test Strategy
[How to test end-to-end]

## Risks
- [Risk] -> [Mitigation]
PLANEOF
    fi

    log_header "PLAN CREATED: ${spec_name}"
    echo "  Path: $spec_dir/plan.md"
    echo ""
    echo "Next steps:"
    echo "  1. Fill in the Worktree Mapping table (module, name, preset)"
    echo "  2. Define the architecture and tech decisions"
    echo "  3. Reference research findings in your decisions"
    echo "  4. Check constitutional gates:"
    echo "     orchestrate.sh sdd gate $spec_number"
    echo "  5. Generate tasks:"
    echo "     orchestrate.sh sdd tasks $spec_number"
    echo ""

    # Log event
    if [[ -f "$EVENTS_FILE" ]]; then
        echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] SDD_PLAN: ${spec_name}" >> "$EVENTS_FILE"
    fi
}

# =============================================
# SDD TASKS (BRIDGE TO ORCHESTRATOR)
# =============================================

cmd_sdd_tasks() {
    local spec_number=$1

    if [[ -z "$spec_number" ]]; then
        log_error "Usage: orchestrate.sh sdd tasks <spec-number>"
        return 1
    fi

    local spec_dir
    spec_dir=$(spec_dir_for "$spec_number")
    if [[ $? -ne 0 ]] || [[ -z "$spec_dir" ]]; then
        log_error "Spec not found: $spec_number"
        return 1
    fi

    if [[ ! -f "$spec_dir/plan.md" ]]; then
        log_error "No plan.md found. Run 'sdd plan $spec_number' first."
        return 1
    fi

    local spec_name=$(basename "$spec_dir")

    # Clean orphan tasks before generating new ones
    _clean_orphan_tasks 2>/dev/null || true

    log_header "GENERATING TASKS: ${spec_name}"

    generate_tasks_from_plan "$spec_dir"

    echo ""
    log_separator
    echo -e "${GREEN}Tasks generated successfully!${NC}"
    echo ""
    echo "Generated tasks in: $ORCHESTRATION_DIR/tasks/"
    ls -1 "$ORCHESTRATION_DIR/tasks/"*.md 2>/dev/null | while read -r f; do
        echo "  - $(basename "$f")"
    done
    echo ""
    echo "Next steps:"
    echo "  For each task, create a worktree:"

    # Show setup commands from the generated tasks.md
    if [[ -f "$spec_dir/tasks.md" ]]; then
        sed -n '/```bash/,/```/p' "$spec_dir/tasks.md" | grep -v '```' | while read -r line; do
            echo "    $line"
        done
    fi

    echo ""
    echo "  Then start all agents:"
    echo "    orchestrate.sh start"
    echo ""

    # Log event
    if [[ -f "$EVENTS_FILE" ]]; then
        echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] SDD_TASKS: ${spec_name}" >> "$EVENTS_FILE"
    fi
}

# =============================================
# SDD STATUS
# =============================================

cmd_sdd_status() {
    log_header "SDD - ACTIVE SPECS"

    if [[ ! -d "$SPECS_ACTIVE" ]]; then
        log_info "No SDD structure found. Run: orchestrate.sh sdd init"
        return 0
    fi

    local specs
    specs=$(list_active_specs)

    if [[ -z "$specs" ]]; then
        log_info "No active specs found."
        echo "  Create one with: orchestrate.sh sdd specify \"your feature\""
        return 0
    fi

    # Header
    printf "  %-30s %-6s %-15s %s\n" "SPEC" "PDCA" "STATUS" "NEXT STEP"
    log_separator

    echo "$specs" | while IFS='|' read -r name status; do
        local next_step=""
        local pdca_phase=$(get_pdca_phase "$status")
        case "$status" in
            empty)          next_step="-> run: sdd specify" ;;
            specified)      next_step="-> run: sdd research ${name%%-*}" ;;
            researched)     next_step="-> run: sdd plan ${name%%-*}" ;;
            planned)        next_step="-> run: sdd tasks ${name%%-*}" ;;
            tasks-ready)    next_step="-> run: setup & start" ;;
            executing*)     next_step="-> wait for agents" ;;
            completed)      next_step="-> run: sdd validate ${name%%-*}" ;;
            validated)      next_step="-> run: sdd archive ${name%%-*}" ;;
        esac

        printf "  %-30s %-6s %-15s %s\n" "$name" "$pdca_phase" "[$status]" "$next_step"
    done

    echo ""

    # Show constitution status
    if has_constitution; then
        local article_count=$(grep -c "^## Article" "$CONSTITUTION_FILE" 2>/dev/null || echo 0)
        log_info "Constitution: $article_count articles defined"
    else
        log_warn "No constitution. Run: orchestrate.sh sdd constitution"
    fi
}

# =============================================
# SDD GATE
# =============================================

cmd_sdd_gate() {
    local spec_number=$1

    if [[ -z "$spec_number" ]]; then
        log_error "Usage: orchestrate.sh sdd gate <spec-number>"
        return 1
    fi

    local spec_dir
    spec_dir=$(spec_dir_for "$spec_number")
    if [[ $? -ne 0 ]] || [[ -z "$spec_dir" ]]; then
        log_error "Spec not found: $spec_number"
        return 1
    fi

    if [[ ! -f "$spec_dir/plan.md" ]]; then
        log_error "No plan.md found. Run 'sdd plan $spec_number' first."
        return 1
    fi

    check_gates "$spec_dir/plan.md"
}

# =============================================
# SDD VALIDATE (POST-MERGE PRODUCTION VALIDATION)
# =============================================

cmd_sdd_validate() {
    local spec_number=$1
    local skip_mode=false

    # Parse arguments
    shift || true
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --skip) skip_mode=true; shift ;;
            *) shift ;;
        esac
    done

    if [[ -z "$spec_number" ]]; then
        log_error "Usage: orchestrate.sh sdd validate <spec-number> [--skip]"
        return 1
    fi

    local spec_dir
    spec_dir=$(spec_dir_for "$spec_number")
    if [[ $? -ne 0 ]] || [[ -z "$spec_dir" ]]; then
        log_error "Spec not found: $spec_number"
        return 1
    fi

    local spec_name=$(basename "$spec_dir")
    local spec_file="$spec_dir/spec.md"
    local validation_file="$spec_dir/validation.md"

    # Check if already validated
    if [[ -f "$validation_file" ]]; then
        local prev_result=$(grep -c "VALIDATED" "$validation_file" 2>/dev/null || echo 0)
        if [[ $prev_result -gt 0 ]]; then
            log_info "Spec already validated: $spec_name"
            echo ""
            cat "$validation_file"
            return 0
        else
            log_warn "Previous validation exists but did not pass — re-running"
        fi
    fi

    log_header "PRODUCTION VALIDATION: ${spec_name}"

    if $skip_mode; then
        # Create a skip validation file
        cat > "$validation_file" << VEOF
# Production Validation: ${spec_name}

> Validated: $(date '+%Y-%m-%d %H:%M:%S') | Method: SKIPPED

## Reason
Production validation skipped (--skip flag).
This spec does not require production validation (e.g., internal tooling, refactoring, infra-only).

## Signed Off By
Skipped by architect/developer.
VEOF
        log_success "Validation skipped — recorded in validation.md"

        # Log event
        if [[ -f "$EVENTS_FILE" ]]; then
            echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] SDD_VALIDATE_SKIP: ${spec_name}" >> "$EVENTS_FILE"
        fi
        return 0
    fi

    # Extract spec content for the validation agent
    local acceptance_criteria=""
    if [[ -f "$spec_file" ]]; then
        acceptance_criteria=$(sed -n '/## Acceptance Criteria/,/^## /p' "$spec_file" | sed '$d' | tail -n +2)
    fi

    local prod_validation=""
    if [[ -f "$spec_file" ]]; then
        prod_validation=$(sed -n '/## Production Validation/,/^## /p' "$spec_file" | sed '$d' | tail -n +2)
    fi

    # Build the full spec context for the agent
    local spec_content=""
    if [[ -f "$spec_file" ]]; then
        spec_content=$(cat "$spec_file")
    fi

    local plan_content=""
    if [[ -f "$spec_dir/plan.md" ]]; then
        plan_content=$(cat "$spec_dir/plan.md")
    fi

    # Build validation prompt
    local validation_prompt
    validation_prompt=$(cat << VPROMPT
You are a Production Validation Agent. Your job is to AUTONOMOUSLY verify that a recently merged feature works correctly in the real environment.

## Spec
${spec_content}

## Plan
${plan_content}

## Your Task

1. Read the Acceptance Criteria and Production Validation sections from the spec above.
2. For EACH criterion, run actual commands to verify it works:
   - Run tests (npm test, pytest, etc.) to confirm nothing is broken
   - Check that new files/modules exist and are properly wired
   - If there are API endpoints, test them (curl, httpie, etc.)
   - If there are database changes, verify schema/data
   - Check for error logs, warnings, or regressions
   - Import/require new modules to verify they load correctly
3. Record evidence for each check (command output, file contents, etc.)
4. Write results to: ${validation_file}

## Output Format

Write ${validation_file} with this exact structure:

\`\`\`markdown
# Production Validation: ${spec_name}

> Validated: [timestamp] | Method: AUTONOMOUS | Result: PASS or FAIL

## Checks Performed

### [Check Name]
- **Status**: PASS / FAIL
- **Command**: \`[what you ran]\`
- **Evidence**: [output/result]

### [Check Name]
...

## Summary
- Total checks: N
- Passed: N
- Failed: N

## Result
VALIDATED — All checks pass
(or)
FAILED — N check(s) failed (see details above)
\`\`\`

## Rules
- Be thorough but fast. Run real commands, not hypothetical ones.
- If a check requires a running server and none is available, test what you CAN test (imports, file existence, unit tests, config correctness).
- If ALL checks pass, write "VALIDATED" in the Result section.
- If ANY check fails, write "FAILED" in the Result section with details.
- Do NOT ask for human input. Decide autonomously.
VPROMPT
)

    # Launch validation agent
    log_info "Launching validation agent for $spec_name..."
    echo "  The agent will autonomously verify acceptance criteria."
    echo ""

    local logfile="${ORCHESTRATION_DIR}/logs/validate-${spec_name}.log"
    ensure_dir "$ORCHESTRATION_DIR/logs"

    # Run the validation agent
    (set +e; unset CLAUDECODE; claude --dangerously-skip-permissions --verbose --output-format stream-json -p "$validation_prompt" > "$logfile" 2>&1)
    local exit_code=$?

    # Check result
    if [[ -f "$validation_file" ]]; then
        if grep -q "VALIDATED" "$validation_file" 2>/dev/null; then
            log_success "Production validation PASSED"
            echo ""
            cat "$validation_file"
        elif grep -q "FAILED" "$validation_file" 2>/dev/null; then
            log_error "Production validation FAILED"
            echo ""
            cat "$validation_file"
            echo ""
            log_info "Fix the issues and re-run: orchestrate.sh sdd validate $spec_number"

            # Auto-create hotfix spec (PDCA Act phase)
            _create_hotfix_spec "$spec_name" "$validation_file"

            # Log event
            if [[ -f "$EVENTS_FILE" ]]; then
                echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] SDD_VALIDATE_FAIL: ${spec_name}" >> "$EVENTS_FILE"
            fi
            return 1
        else
            log_warn "Validation completed but result unclear — check $validation_file"
        fi
    else
        log_error "Validation agent did not create $validation_file"
        log_info "Check log: $logfile"

        # Log event
        if [[ -f "$EVENTS_FILE" ]]; then
            echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] SDD_VALIDATE_ERROR: ${spec_name}" >> "$EVENTS_FILE"
        fi
        return 1
    fi

    # Log event
    if [[ -f "$EVENTS_FILE" ]]; then
        echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] SDD_VALIDATE_PASS: ${spec_name}" >> "$EVENTS_FILE"
    fi
}

# =============================================
# SDD ARCHIVE
# =============================================

cmd_sdd_archive() {
    local spec_number=$1

    if [[ -z "$spec_number" ]]; then
        log_error "Usage: orchestrate.sh sdd archive <spec-number>"
        return 1
    fi

    local spec_dir
    spec_dir=$(spec_dir_for "$spec_number")
    if [[ $? -ne 0 ]] || [[ -z "$spec_dir" ]]; then
        log_error "Spec not found: $spec_number"
        return 1
    fi

    local spec_name=$(basename "$spec_dir")

    # Check if it's already archived
    if [[ "$spec_dir" == "$SPECS_ARCHIVE"/* ]]; then
        log_info "Spec already archived: $spec_name"
        return 0
    fi

    # Warn if not validated (Article VII)
    if [[ ! -f "$spec_dir/validation.md" ]]; then
        log_warn "Spec has NOT been production-validated"
        log_info "Run: orchestrate.sh sdd validate $spec_number"
        log_info "Or skip: orchestrate.sh sdd validate $spec_number --skip"
        if ! confirm "Archive without validation?"; then
            return 0
        fi
    fi

    # Warn if agents are still running for this spec
    local spec_num=${spec_name%%-*}
    local running_agents=0
    for task_file in "$ORCHESTRATION_DIR/tasks"/*.md; do
        [[ -f "$task_file" ]] || continue
        if grep -q "spec-ref:.*/${spec_num}-" "$task_file" 2>/dev/null; then
            local tname=$(basename "$task_file" .md)
            if is_process_running "$tname" 2>/dev/null; then
                ((running_agents++))
                log_warn "Agent '$tname' is still running"
            fi
        fi
    done
    if [[ $running_agents -gt 0 ]]; then
        log_warn "$running_agents agent(s) still running for this spec"
        if ! confirm "Archive anyway? Running agents will be stopped."; then
            return 0
        fi
    fi

    if ! confirm "Archive spec '$spec_name'?"; then
        return 0
    fi

    # Move first, then cleanup — prevents data loss if mv fails
    ensure_dir "$SPECS_ARCHIVE"
    if ! mv "$spec_dir" "$SPECS_ARCHIVE/"; then
        log_error "Failed to move spec to archive: $spec_name"
        return 1
    fi

    # Clean up stale tasks, worktrees, PIDs, and logs for this spec
    _cleanup_spec_artifacts "$spec_name"

    log_success "Archived: $spec_name -> specs/archive/"

    # Log event
    if [[ -f "$EVENTS_FILE" ]]; then
        echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] SDD_ARCHIVE: ${spec_name}" >> "$EVENTS_FILE"
    fi
}

# =============================================
# SDD KAIZEN REVIEW (PDCA Act Phase)
# =============================================

cmd_sdd_kaizen() {
    local spec_number=$1

    if [[ -z "$spec_number" ]]; then
        log_error "Usage: orchestrate.sh sdd kaizen <spec-number>"
        return 1
    fi

    local spec_dir
    spec_dir=$(spec_dir_for "$spec_number")
    if [[ $? -ne 0 ]] || [[ -z "$spec_dir" ]]; then
        log_error "Spec not found: $spec_number"
        return 1
    fi

    local spec_name=$(basename "$spec_dir")
    local spec_num=${spec_name%%-*}
    local kaizen_file="$spec_dir/kaizen.md"

    log_header "KAIZEN REVIEW: ${spec_name}"

    # Collect data from EVENTS.md
    local total_iterations=0
    local total_gate_fails=0
    local agent_count=0
    local agent_data=""

    for task_file in "$ORCHESTRATION_DIR/tasks"/*.md; do
        [[ -f "$task_file" ]] || continue
        if grep -q "spec-ref:.*/${spec_num}-" "$task_file" 2>/dev/null; then
            local agent_name=$(basename "$task_file" .md)
            ((agent_count++)) || true

            # Count iterations from EVENTS
            local iters=0
            if [[ -f "$EVENTS_FILE" ]]; then
                iters=$(grep -c "RALPH_ITER_START: $agent_name" "$EVENTS_FILE" 2>/dev/null || echo 0)
            fi
            total_iterations=$((total_iterations + iters))

            # Count gate failures
            local gfails=0
            if [[ -f "$EVENTS_FILE" ]]; then
                gfails=$(grep -c "RALPH_GATE_FAIL: $agent_name" "$EVENTS_FILE" 2>/dev/null || echo 0)
            fi
            total_gate_fails=$((total_gate_fails + gfails))

            # Get outcome
            local worktree_path=$(get_worktree_path "$agent_name")
            local outcome="unknown"
            if [[ -f "$worktree_path/DONE.md" ]]; then
                outcome="completed"
            elif [[ -f "$worktree_path/BLOCKED.md" ]]; then
                outcome="blocked"
            fi

            # Get elapsed time from events
            local elapsed="n/a"
            if [[ -f "$EVENTS_FILE" ]]; then
                local start_ts=$(grep "STARTING: $agent_name" "$EVENTS_FILE" 2>/dev/null | tail -1 | grep -o '^\[[^]]*\]' | tr -d '[]')
                local end_ts=$(grep "RALPH_COMPLETE: $agent_name\|RALPH_STALL: $agent_name\|RALPH_MAX_ITER: $agent_name" "$EVENTS_FILE" 2>/dev/null | tail -1 | grep -o '^\[[^]]*\]' | tr -d '[]')
                if [[ -n "$start_ts" ]] && [[ -n "$end_ts" ]]; then
                    elapsed="${start_ts} → ${end_ts}"
                fi
            fi

            agent_data+="| $agent_name | $iters | $gfails | $elapsed | $outcome |"$'\n'
        fi
    done

    # Collect what went well from DONE.md files
    local went_well=""
    for task_file in "$ORCHESTRATION_DIR/tasks"/*.md; do
        [[ -f "$task_file" ]] || continue
        if grep -q "spec-ref:.*/${spec_num}-" "$task_file" 2>/dev/null; then
            local agent_name=$(basename "$task_file" .md)
            local worktree_path=$(get_worktree_path "$agent_name")
            if [[ -f "$worktree_path/DONE.md" ]]; then
                local summary=$(sed -n '/## Summary/,/^## /p' "$worktree_path/DONE.md" 2>/dev/null | sed '$d' | tail -n +2 | head -5)
                [[ -n "$summary" ]] && went_well+="- **$agent_name**: $summary"$'\n'
            fi
        fi
    done

    # Collect what went wrong from BLOCKED.md files
    local went_wrong=""
    for task_file in "$ORCHESTRATION_DIR/tasks"/*.md; do
        [[ -f "$task_file" ]] || continue
        if grep -q "spec-ref:.*/${spec_num}-" "$task_file" 2>/dev/null; then
            local agent_name=$(basename "$task_file" .md)
            local worktree_path=$(get_worktree_path "$agent_name")
            if [[ -f "$worktree_path/BLOCKED.md" ]]; then
                local reason=$(head -5 "$worktree_path/BLOCKED.md" 2>/dev/null | tail -3)
                went_wrong+="- **$agent_name**: $reason"$'\n'
            fi
        fi
    done

    # Generate suggestions
    local suggestions=""
    local avg_iters=0
    if [[ $agent_count -gt 0 ]]; then
        avg_iters=$((total_iterations / agent_count))
    fi

    if [[ $avg_iters -gt 5 ]]; then
        suggestions+="- High avg iterations ($avg_iters) — consider more detailed specs and explicit gate commands"$'\n'
    fi
    if [[ $total_gate_fails -gt $total_iterations ]] 2>/dev/null; then
        suggestions+="- Gate failure rate >50% — review test setup and gate commands in task files"$'\n'
    fi
    if [[ -n "$went_wrong" ]]; then
        suggestions+="- Some agents blocked — consider breaking tasks into smaller units"$'\n'
    fi
    if [[ $avg_iters -le 2 ]] && [[ -z "$went_wrong" ]]; then
        suggestions+="- Low iteration count with no blockers — spec quality is excellent, maintain this pattern"$'\n'
    fi

    # Read metrics file if exists
    local metrics_summary=""
    local metrics_file="$ORCHESTRATION_DIR/metrics/${spec_num}*.json"
    local mfile=""
    for f in $metrics_file; do
        [[ -f "$f" ]] && mfile="$f" && break
    done

    # Write kaizen report
    cat > "$kaizen_file" << KEOF
# Kaizen Review: ${spec_name}

> Generated: $(date '+%Y-%m-%d %H:%M:%S')
> PDCA Phase: ACT (continuous improvement)

## What Went Well

${went_well:-"- No completion data available (agents may still be running)"}

## What Went Wrong

${went_wrong:-"- No blockers detected — all agents completed successfully"}

## Iteration Analysis

| Agent | Iterations | Gate Failures | Time | Outcome |
|-------|-----------|---------------|------|---------|
${agent_data:-"| (no agents found) | - | - | - | - |"}

## Metrics Summary

- **Total agents**: $agent_count
- **Total iterations**: $total_iterations
- **Average iterations/agent**: $avg_iters
- **Total gate failures**: $total_gate_fails

## Suggested Improvements

${suggestions:-"- No specific improvements suggested — process is working well"}
KEOF

    log_success "Kaizen report written: $kaizen_file"

    # Auto-update PROJECT_MEMORY.md with condensed lessons
    if [[ -f "$MEMORY_FILE" ]]; then
        local lesson_entry="
#### Kaizen: ${spec_name} ($(date '+%Y-%m-%d'))
- Iterations: $total_iterations across $agent_count agent(s) (avg: $avg_iters)
- Gate failures: $total_gate_fails
${suggestions}"

        # Check for existing Kaizen section
        if grep -q "### Kaizen Reviews" "$MEMORY_FILE" 2>/dev/null; then
            # Append to existing section (before next ### heading)
            local tmp_mem="${MEMORY_FILE}.kaizen_tmp"
            awk -v lesson="$lesson_entry" '
                /^### Kaizen Reviews/ { print; found=1; next }
                found && /^###/ { print lesson; print ""; found=0 }
                { print }
                END { if(found) print lesson }
            ' "$MEMORY_FILE" > "$tmp_mem" && mv "$tmp_mem" "$MEMORY_FILE"
        else
            # Create new section at end
            printf "\n### Kaizen Reviews\n%s\n" "$lesson_entry" >> "$MEMORY_FILE"
        fi
        log_success "Updated PROJECT_MEMORY.md with kaizen lessons"
    fi

    # Display summary
    echo ""
    printf "  %-15s %s\n" "Agents:" "$agent_count"
    printf "  %-15s %s\n" "Iterations:" "$total_iterations (avg: $avg_iters)"
    printf "  %-15s %s\n" "Gate Failures:" "$total_gate_fails"
    echo ""

    # Log event
    if [[ -f "$EVENTS_FILE" ]]; then
        echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] SDD_KAIZEN: ${spec_name} [agents=$agent_count, iters=$total_iterations, fails=$total_gate_fails]" >> "$EVENTS_FILE"
    fi
}

# =============================================
# SDD RUN (AUTOPILOT)
# =============================================

cmd_sdd_run() {
    local spec_number=""
    local mode="${EXECUTION_MODE:-worktree}"
    local auto_merge=false
    local ralph_mode=true
    local ralph_max_iterations=""
    local hitl_mode=false
    local kaizen_enabled=true
    local spec_dirs=()

    # Enable autopilot mode — hooks will pass through without blocking
    export SDD_AUTOPILOT=1

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --mode)
                mode="$2"
                shift 2
                ;;
            --mode=*)
                mode="${1#*=}"
                shift
                ;;
            --direct)
                mode="direct"
                shift
                ;;
            --auto-merge)
                auto_merge=true
                shift
                ;;
            --ralph)
                ralph_mode=true
                shift
                ;;
            --no-ralph)
                ralph_mode=false
                shift
                ;;
            --max-iterations)
                ralph_max_iterations="$2"
                shift 2
                ;;
            --hitl)
                hitl_mode=true
                shift
                ;;
            --afk)
                hitl_mode=false
                shift
                ;;
            --no-kaizen)
                kaizen_enabled=false
                shift
                ;;
            *)
                spec_number="$1"
                shift
                ;;
        esac
    done

    # Validate mode
    if [[ "$mode" != "worktree" ]] && [[ "$mode" != "teams" ]] && [[ "$mode" != "direct" ]]; then
        log_error "Invalid mode: $mode (must be 'worktree', 'teams', or 'direct')"
        return 1
    fi

    # Check teams availability if teams mode requested
    if [[ "$mode" == "teams" ]]; then
        if ! detect_teams_available; then
            log_error "Agent Teams not available (CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS != 1)"
            log_info "Set the env var or use worktree mode: sdd run $spec_number"
            return 1
        fi
    fi

    # Collect target specs
    if [[ -n "$spec_number" ]]; then
        # Single spec mode
        local spec_dir
        spec_dir=$(spec_dir_for "$spec_number")
        if [[ $? -ne 0 ]] || [[ -z "$spec_dir" ]]; then
            log_error "Spec not found: $spec_number"
            log_info "Run 'orchestrate.sh sdd status' to see active specs"
            return 1
        fi
        # Check if spec is already completed or executing
        local single_status=$(get_spec_status "$spec_dir")
        if [[ "$single_status" == "completed" ]]; then
            local sname=$(basename "$spec_dir")
            ensure_dir "$SPECS_ARCHIVE"
            if mv "$spec_dir" "$SPECS_ARCHIVE/" 2>/dev/null; then
                _cleanup_spec_artifacts "$sname"
            else
                log_warn "Could not archive $sname (move failed)"
            fi
            log_success "Spec $spec_number already completed — auto-archived: $sname"
            if [[ -f "$EVENTS_FILE" ]]; then
                echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] SDD_AUTO_ARCHIVE: ${sname}" >> "$EVENTS_FILE"
            fi
            return 0
        elif [[ "$single_status" == executing* ]]; then
            log_warn "Spec $spec_number is already executing ($single_status)"
            log_info "Use 'orchestrate.sh status' to monitor, or 'orchestrate.sh sdd archive $spec_number' to reset"
            return 1
        fi
        spec_dirs+=("$spec_dir")
    else
        # All specs mode: collect active specs that have plan.md
        if [[ ! -d "$SPECS_ACTIVE" ]]; then
            log_error "No SDD structure found. Run: orchestrate.sh sdd init"
            return 1
        fi

        local archived_count=0
        local skipped_executing=0
        for dir in "$SPECS_ACTIVE"/*/; do
            [[ -d "$dir" ]] || continue
            if [[ -f "$dir/plan.md" ]]; then
                local status=$(get_spec_status "${dir%/}")
                if [[ "$status" == "completed" ]]; then
                    # Auto-archive completed specs: move first, cleanup after
                    local sname=$(basename "${dir%/}")
                    ensure_dir "$SPECS_ARCHIVE"
                    if mv "${dir%/}" "$SPECS_ARCHIVE/" 2>/dev/null; then
                        _cleanup_spec_artifacts "$sname"
                        log_success "Auto-archived completed spec: $sname"
                        if [[ -f "$EVENTS_FILE" ]]; then
                            echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] SDD_AUTO_ARCHIVE: ${sname}" >> "$EVENTS_FILE"
                        fi
                    else
                        log_warn "Could not archive $sname (move failed), skipping"
                    fi
                    ((archived_count++))
                    continue
                elif [[ "$status" == executing* ]]; then
                    log_warn "Skipping $(basename "${dir%/}") — already executing ($status)"
                    ((skipped_executing++))
                    continue
                fi
                spec_dirs+=("${dir%/}")
            fi
        done

        if [[ $archived_count -gt 0 ]]; then
            log_info "Auto-archived $archived_count completed spec(s)"
        fi
        if [[ $skipped_executing -gt 0 ]]; then
            log_info "Skipped $skipped_executing spec(s) already executing"
        fi

        if [[ ${#spec_dirs[@]} -eq 0 ]]; then
            log_error "No specs with plan.md found"
            log_info "Create a plan first: orchestrate.sh sdd plan <number>"
            return 1
        fi
    fi

    # Validate prerequisites for all specs
    for spec_dir in "${spec_dirs[@]}"; do
        local name=$(basename "$spec_dir")
        if [[ ! -f "$spec_dir/spec.md" ]]; then
            log_error "[$name] No spec.md found"
            return 1
        fi
        if [[ ! -f "$spec_dir/research.md" ]]; then
            log_error "[$name] No research.md found. Run: sdd research ${name%%-*}"
            return 1
        fi
        if [[ ! -f "$spec_dir/plan.md" ]]; then
            log_error "[$name] No plan.md found. Run: sdd plan ${name%%-*}"
            return 1
        fi
    done

    local spec_count=${#spec_dirs[@]}
    log_header "SDD AUTOPILOT: $spec_count spec(s)"
    if $auto_merge; then
        echo "  Pipeline: gate -> tasks -> setup -> start -> monitor -> merge -> validate -> archive"
    else
        echo "  Pipeline: gate -> tasks -> setup -> start -> monitor"
    fi
    if $ralph_mode; then
        echo "  Ralph mode: enabled (iterative self-correcting loops)"
    fi
    echo "  Autopilot: SDD_AUTOPILOT=1 (hooks bypassed)"
    echo ""

    # List specs being processed
    for spec_dir in "${spec_dirs[@]}"; do
        echo "  - $(basename "$spec_dir")"
    done
    echo ""

    # Log event
    if [[ -f "$EVENTS_FILE" ]]; then
        echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] SDD_RUN_START: ${spec_count} spec(s)" >> "$EVENTS_FILE"
    fi

    # =========================================
    # PRE-RUN: Clean orphan tasks from previous runs
    # =========================================
    _clean_orphan_tasks 2>/dev/null || true

    # =========================================
    # PHASE 1: Gate + Tasks (all specs)
    # =========================================
    log_step "[1/3] Checking gates and generating tasks..."
    echo ""

    for spec_dir in "${spec_dirs[@]}"; do
        local spec_name=$(basename "$spec_dir")
        local plan_file="$spec_dir/plan.md"

        # Gate check
        log_info "[$spec_name] Checking gates..."
        if ! check_gates "$plan_file"; then
            log_error "[$spec_name] GATES FAILED — fix issues before running autopilot"
            if [[ -f "$EVENTS_FILE" ]]; then
                echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] SDD_RUN_FAILED: ${spec_name} (gate)" >> "$EVENTS_FILE"
            fi
            return 1
        fi
        log_success "[$spec_name] Gates passed"

        # Clean stale task files for this spec
        for existing_task in "$ORCHESTRATION_DIR/tasks"/*.md; do
            [[ -f "$existing_task" ]] || continue
            if grep -q "spec-ref:.*/${spec_name}/" "$existing_task" 2>/dev/null; then
                rm -f "$existing_task"
            fi
        done

        # Generate tasks
        log_info "[$spec_name] Generating tasks..."
        if ! generate_tasks_from_plan "$spec_dir"; then
            log_error "[$spec_name] Task generation failed"
            if [[ -f "$EVENTS_FILE" ]]; then
                echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] SDD_RUN_FAILED: ${spec_name} (tasks)" >> "$EVENTS_FILE"
            fi
            return 1
        fi
        echo ""
    done

    log_success "All gates passed, tasks generated"
    echo ""

    # =========================================
    # PHASE 2: Setup (worktrees or teams)
    # =========================================
    if [[ "$mode" == "teams" ]]; then
        log_step "[2/3] Teams mode - skipping worktree setup..."
        log_info "Teammates will work on feature branches within the main repo"
        echo ""
    elif [[ "$mode" == "direct" ]]; then
        log_step "[2/3] Direct mode - skipping worktree setup..."
        log_info "Agent will execute directly on a feature branch in the main repo"
        echo ""
    else
        log_step "[2/3] Setting up worktrees..."
        echo ""

        for spec_dir in "${spec_dirs[@]}"; do
            local spec_name=$(basename "$spec_dir")
            local plan_file="$spec_dir/plan.md"
            local mappings
            mappings=$(parse_worktree_mapping "$plan_file")

            if [[ -z "$mappings" ]]; then
                log_warn "[$spec_name] No Worktree Mapping table — setting up single worktree"
                if ! cmd_setup "$spec_name" --preset "fullstack"; then
                    log_error "[$spec_name] Worktree setup failed"
                    if [[ -f "$EVENTS_FILE" ]]; then
                        echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] SDD_RUN_FAILED: ${spec_name} (setup)" >> "$EVENTS_FILE"
                    fi
                    return 1
                fi
            else
                # Auto-detect: if only 1 module and mode not explicitly set, suggest direct mode
                local mapping_count=$(echo "$mappings" | wc -l | tr -d ' ')
                if [[ $mapping_count -eq 1 ]] && [[ "${EXECUTION_MODE:-}" != "worktree" ]]; then
                    log_info "[$spec_name] Single module detected — consider --direct mode for less overhead"
                fi

                while IFS='|' read -r module wt_name preset; do
                    [[ -z "$wt_name" ]] && continue

                    log_info "Setting up: $wt_name (preset: $preset)"
                    if ! cmd_setup "$wt_name" --preset "$preset"; then
                        log_error "Worktree setup failed: $wt_name"
                        if [[ -f "$EVENTS_FILE" ]]; then
                            echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] SDD_RUN_FAILED: ${spec_name} (setup: $wt_name)" >> "$EVENTS_FILE"
                        fi
                        return 1
                    fi
                done <<< "$mappings"
            fi
        done

        log_success "All worktrees created"
        echo ""
    fi

    # =========================================
    # PHASE 3: Start agents (worktrees or teams)
    # =========================================
    if [[ "$mode" == "teams" ]]; then
        log_step "[3/3] Starting Agent Team..."
        echo ""
        log_warn "NOTE: Agent Teams uses significantly more tokens than worktrees."
        log_warn "Each teammate is a separate Claude instance with real-time communication."
        echo ""
        echo "  An interactive Claude session will start as the team lead."
        echo "  The team lead will orchestrate teammates to implement the spec."
        echo ""

        # For teams mode, we handle one spec at a time (teams don't support multiple concurrent teams)
        if [[ ${#spec_dirs[@]} -gt 1 ]]; then
            log_warn "Teams mode processes one spec at a time"
        fi

        for spec_dir in "${spec_dirs[@]}"; do
            start_team_from_spec "$spec_dir"
        done
    elif [[ "$mode" == "direct" ]]; then
        log_step "[3/3] Running agent directly (no worktree)..."
        echo ""

        for spec_dir in "${spec_dirs[@]}"; do
            local spec_name=$(basename "$spec_dir")
            local task_file="$ORCHESTRATION_DIR/tasks/${spec_name}.md"

            # Create a feature branch for the direct execution
            local branch="feature/${spec_name}"
            if ! branch_exists "$branch"; then
                git checkout -b "$branch" 2>/dev/null || {
                    log_error "Failed to create branch: $branch"
                    return 1
                }
            else
                git checkout "$branch" 2>/dev/null || {
                    log_error "Failed to switch to branch: $branch"
                    return 1
                }
            fi

            log_info "Running on branch: $branch"

            # Build the prompt from the task file (reuse start_single_agent logic)
            if [[ -f "$task_file" ]]; then
                local task=$(cat "$task_file")
                log_info "Executing task: $spec_name"
                echo ""
                echo "  The agent will run directly in this repository."
                echo "  Output will be streamed to the log."
                echo ""

                local logfile=$(get_log_file "$spec_name")
                ensure_dir "$ORCHESTRATION_DIR/logs"

                (set +e; unset CLAUDECODE; nohup claude --dangerously-skip-permissions --verbose --output-format stream-json -p "Execute this task on the current branch:\n\n$task" > "$logfile" 2>&1) &
                local pid=$!
                echo $pid > "$(get_pid_file "$spec_name")"
                echo $(date '+%s') > "$(get_start_time_file "$spec_name")"

                log_success "Direct agent started (PID: $pid)"
            else
                log_error "No task file found for $spec_name"
            fi
        done

        echo ""
        log_info "Monitor with: orchestrate.sh status"
    else
        log_step "[3/3] Starting agents..."
        echo ""
        echo "  Agents will be monitored until completion."
        echo "  Press Ctrl+C to detach (agents keep running)."
        echo ""

        # Build start command args, passing --ralph if enabled (REQ-13, REQ-24)
        local start_args=()
        if $ralph_mode; then
            start_args+=(--ralph)
            if [[ -n "$ralph_max_iterations" ]]; then
                start_args+=(--max-iterations "$ralph_max_iterations")
            fi
        fi
        if $hitl_mode; then
            start_args+=(--hitl)
        fi

        cmd_start "${start_args[@]}"
    fi

    # =========================================
    # POST: Summary
    # =========================================
    echo ""
    log_header "SDD AUTOPILOT COMPLETE"
    echo ""

    # Show per-agent results
    local total=0 done_count=0 blocked_count=0 stopped_count=0
    printf "  %-25s %-15s %s\n" "AGENT" "STATUS" "COMMITS"
    log_separator

    for task_file in "$ORCHESTRATION_DIR/tasks"/*.md; do
        [[ -f "$task_file" ]] || continue
        local name=$(basename "$task_file" .md)
        local worktree_path=$(get_worktree_path "$name")
        local status=$(get_agent_status "$name")
        ((total++)) || true

        case "$status" in
            done|done_no_report) ((done_count++)) || true ;;
            blocked) ((blocked_count++)) || true ;;
            stopped) ((stopped_count++)) || true ;;
        esac

        local commits=0
        if dir_exists "$worktree_path"; then
            commits=$(cd "$worktree_path" && git log --oneline main..HEAD 2>/dev/null | wc -l | tr -d ' ')
        fi

        printf "  %-25s %-15s %s\n" "$name" "[$status]" "$commits"
    done

    echo ""

    if [[ $done_count -eq $total ]] && [[ $total -gt 0 ]]; then
        echo -e "  ${GREEN}All $total agent(s) completed successfully!${NC}"
    else
        echo -e "  ${YELLOW}Results: $done_count completed, $blocked_count blocked, $stopped_count stopped (of $total)${NC}"
    fi

    echo ""

    # =========================================
    # POST-RUN AUTOMATION
    # =========================================

    # Always run update-memory after agents complete (REQ-3)
    if [[ $done_count -gt 0 ]]; then
        log_step "Running update-memory --full..."
        cmd_update_memory --full 2>/dev/null || log_warn "update-memory failed (non-fatal)"
    fi

    # Kaizen review (PDCA Act phase — auto-run, skippable with --no-kaizen)
    if $kaizen_enabled && [[ $done_count -gt 0 ]]; then
        log_step "Running kaizen review..."
        for spec_dir in "${spec_dirs[@]}"; do
            local sname=$(basename "$spec_dir")
            local snum=${sname%%-*}
            cmd_sdd_kaizen "$snum" 2>/dev/null || log_warn "Kaizen review failed for $sname (non-fatal)"
        done
    fi

    # Auto-merge flow (REQ-5, REQ-4, REQ-6)
    if [[ $done_count -eq $total ]] && [[ $total -gt 0 ]]; then
        if $auto_merge; then
            # --auto-merge: merge + learn extract + cleanup + archive
            echo ""
            log_step "Auto-merge: merging all worktrees..."
            if FORCE=true cmd_merge; then
                log_success "Merge completed successfully"

                # Cleanup worktrees after successful merge
                FORCE=true cmd_cleanup 2>/dev/null || log_warn "Cleanup failed (non-fatal)"

                # Learn extract after successful merge (REQ-4)
                log_step "Extracting learnings..."
                cmd_learn extract 2>/dev/null || log_warn "learn extract failed (non-fatal)"

                # Production validation (Article VII)
                log_step "Running production validation..."
                local validation_failed=false
                for spec_dir in "${spec_dirs[@]}"; do
                    local sname=$(basename "$spec_dir")
                    local snum=${sname%%-*}
                    if cmd_sdd_validate "$snum"; then
                        log_success "Validation passed: $sname"
                    else
                        log_warn "Validation failed: $sname (non-blocking in auto-merge)"
                        validation_failed=true
                    fi
                done

                if $validation_failed; then
                    log_warn "Some validations failed — review validation.md files before archiving"
                fi

                # Archive specs (REQ-6)
                for spec_dir in "${spec_dirs[@]}"; do
                    local sname=$(basename "$spec_dir")
                    if [[ -d "$spec_dir" ]]; then
                        ensure_dir "$SPECS_ARCHIVE"
                        if mv "$spec_dir" "$SPECS_ARCHIVE/" 2>/dev/null; then
                            _cleanup_spec_artifacts "$sname"
                            log_success "Spec archived: $sname"
                        fi
                    fi
                done
            else
                log_error "Auto-merge failed — resolve conflicts manually"
                log_info "Worktrees preserved for inspection. Run: orchestrate.sh merge"
            fi
        else
            # Default: pause before merge (AC-6)
            echo ""
            log_separator
            echo ""
            echo "  Next steps:"
            echo "    orchestrate.sh verify-all              # Review agent output"
            echo "    orchestrate.sh merge                   # Merge all worktrees"
            echo "    orchestrate.sh sdd validate ${spec_number:-NNN}  # Verify in production"
            echo "    orchestrate.sh sdd archive ${spec_number:-NNN}   # Archive spec"
            echo ""
            echo "  Or re-run with --auto-merge for unattended merge:"
            echo "    orchestrate.sh sdd run ${spec_number:-} --auto-merge"
            echo ""
        fi
    else
        echo ""
        log_separator
        echo ""
        echo "  Next steps:"
        echo "    orchestrate.sh verify-all              # Review agent output"
        echo "    orchestrate.sh merge                   # Merge all worktrees"
        echo "    orchestrate.sh sdd validate ${spec_number:-NNN}  # Verify in production"
        echo "    orchestrate.sh update-memory --full"
        echo ""
    fi

    # Integration reminder when multiple worktrees were involved
    if [[ $total -gt 1 ]] && ! $auto_merge; then
        echo -e "  ${YELLOW}NOTE: Each agent passed its own tests in isolation.${NC}"
        echo -e "  ${YELLOW}Before merging, run a full end-to-end integration walkthrough${NC}"
        echo -e "  ${YELLOW}to catch cross-module wiring issues.${NC}"
        echo ""
    fi

    # Log event
    if [[ -f "$EVENTS_FILE" ]]; then
        local event_suffix=""
        $auto_merge && event_suffix=" (auto-merged)"
        echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] SDD_RUN_COMPLETE: $done_count/$total done${event_suffix}" >> "$EVENTS_FILE"
    fi

    # Disable autopilot mode
    export SDD_AUTOPILOT=0
}

# =============================================
# SDD HELP
# =============================================

cmd_sdd_help() {
    echo ""
    echo -e "${BOLD}SDD - Spec-Driven Development${NC}"
    echo -e "${GRAY}Inspired by GitHub Spec-Kit${NC}"
    echo ""
    echo -e "${BOLD}WORKFLOW:${NC}"
    echo "  constitution -> specify -> research -> plan -> gate -> run -> validate -> archive"
    echo "  OR: ... -> gate -> tasks -> setup -> start -> merge -> validate -> archive"
    echo ""
    echo -e "${BOLD}COMMANDS:${NC}"
    echo ""
    echo -e "  ${CYAN}sdd init${NC}                    Initialize SDD structure with templates"
    echo -e "  ${CYAN}sdd constitution${NC}            Show/create project constitution"
    echo -e "  ${CYAN}sdd specify \"description\"${NC}   Create a new spec from description"
    echo -e "  ${CYAN}sdd research <number>${NC}       Create research doc (MANDATORY)"
    echo -e "  ${CYAN}sdd plan <number>${NC}           Create implementation plan (requires research)"
    echo -e "  ${CYAN}sdd gate <number>${NC}           Check constitutional gates"
    echo -e "  ${CYAN}sdd run [number]${NC}            Autopilot with ralph loops (default)"
    echo -e "  ${CYAN}sdd run [number] --no-ralph${NC}  Autopilot without ralph loops (single-shot)"
    echo -e "  ${CYAN}sdd run [number] --auto-merge${NC} Full autopilot: ... -> merge -> archive"
    echo -e "  ${CYAN}sdd run [number] --hitl${NC}      HITL mode: pause between iterations for review"
    echo -e "  ${CYAN}sdd run [number] --no-kaizen${NC} Skip kaizen review after completion"
    echo -e "  ${CYAN}sdd tasks <number>${NC}          Generate orchestrator tasks from plan"
    echo -e "  ${CYAN}sdd status${NC}                  Show all active specs (with PDCA phase)"
    echo -e "  ${CYAN}sdd kaizen <number>${NC}         Run kaizen review (PDCA Act phase)"
    echo -e "  ${CYAN}sdd validate <number>${NC}       Production validation (post-merge)"
    echo -e "  ${CYAN}sdd validate <number> --skip${NC} Skip validation (non-production specs)"
    echo -e "  ${CYAN}sdd archive <number>${NC}        Archive completed spec (warns if not validated)"
    echo ""
    echo -e "${BOLD}EXAMPLE:${NC}"
    echo ""
    echo "  orchestrate.sh sdd init"
    echo "  orchestrate.sh sdd specify \"User authentication with OAuth\""
    echo "  # ... refine spec.md with Claude ..."
    echo "  orchestrate.sh sdd research 001"
    echo "  # ... fill research.md with Claude ..."
    echo "  orchestrate.sh sdd plan 001"
    echo "  # ... refine plan.md with Claude ..."
    echo "  orchestrate.sh sdd gate 001"
    echo ""
    echo "  # Autopilot (gate -> tasks -> setup -> start -> monitor):"
    echo "  orchestrate.sh sdd run 001    # Single spec"
    echo "  orchestrate.sh sdd run        # All planned specs"
    echo ""
    echo "  # OR manual step-by-step:"
    echo "  orchestrate.sh sdd tasks 001"
    echo "  orchestrate.sh setup auth --preset auth"
    echo "  orchestrate.sh start"
    echo "  orchestrate.sh merge"
    echo "  orchestrate.sh sdd validate 001     # Verify in production"
    echo "  orchestrate.sh sdd archive 001"
    echo ""
}

# =============================================
# INTERNAL: Default templates
# =============================================

# Create a hotfix spec from validation failure (PDCA Act phase)
_create_hotfix_spec() {
    local failed_spec_name=$1
    local validation_file=$2

    local hotfix_num
    hotfix_num=$(next_spec_number)
    local hotfix_slug="hotfix-${failed_spec_name}"
    # Truncate to 50 chars
    hotfix_slug=$(echo "$hotfix_slug" | cut -c1-50)
    local hotfix_dir="$SPECS_ACTIVE/${hotfix_num}-${hotfix_slug}"

    ensure_dir "$hotfix_dir"

    # Extract failed checks from validation file
    local failed_checks=""
    if [[ -f "$validation_file" ]]; then
        failed_checks=$(grep -A 2 "FAIL" "$validation_file" 2>/dev/null | head -20)
    fi

    cat > "$hotfix_dir/spec.md" << HEOF
# Spec: Hotfix for ${failed_spec_name}

> Spec: ${hotfix_num} | Created: $(date '+%Y-%m-%d') | Status: DRAFT
> Auto-generated from validation failure (PDCA Act phase)

## Problem Statement

Production validation for spec **${failed_spec_name}** failed. The following checks did not pass:

\`\`\`
${failed_checks:-"(see validation file for details)"}
\`\`\`

## Functional Requirements

- [ ] REQ-1: Fix all failing validation checks from ${failed_spec_name}
- [ ] REQ-2: Ensure existing tests still pass after fix
- [ ] REQ-3: Re-run production validation successfully

## Acceptance Criteria

- [ ] AC-1: Given the fixes are applied, when production validation runs, then all checks pass
- [ ] AC-2: Given existing tests, when test suite runs, then no regressions are introduced

## Out of Scope

- New features — this is a fix-only spec
- Refactoring — minimal changes to resolve failures

## Dependencies

- Original spec: ${failed_spec_name}
- Validation file: ${validation_file}
HEOF

    log_info "Auto-created hotfix spec: ${hotfix_num}-${hotfix_slug}"
    if [[ -f "$EVENTS_FILE" ]]; then
        echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] SDD_HOTFIX_CREATED: ${hotfix_num}-${hotfix_slug} (from ${failed_spec_name})" >> "$EVENTS_FILE"
    fi
}

_sdd_create_default_templates() {
    # Spec template
    cat > "$SPECS_TEMPLATES/spec.md" << 'TEOF'
# Spec: {{FEATURE_NAME}}

> Spec: {{SPEC_NUMBER}} | Created: {{DATE}} | Status: DRAFT

## Problem Statement
[What needs to be solved and why]

## User Stories
- As a [user], I want [action] so that [benefit]

## Functional Requirements
- [ ] REQ-1: [description]
- [ ] REQ-2: [description]

## Non-Functional Requirements
- [ ] Performance: [criteria]
- [ ] Security: [criteria]

## Acceptance Criteria
- [ ] AC-1: Given [context], when [action], then [result]

## Production Validation

How the validation agent should verify this works after merge:

- [ ] [What to check: files exist, imports work, tests pass, APIs respond, logs appear]
- [ ] [What commands to run: curl, grep, test runners, DB queries]
- [ ] [What output to expect: status codes, data formats, no errors]

## Out of Scope
- [What NOT to do]

## Open Questions
- [NEEDS CLARIFICATION] [question]

## Dependencies
- [External dependencies or other specs]
TEOF
    log_success "Created template: spec.md"

    # Research template (MANDATORY)
    cat > "$SPECS_TEMPLATES/research.md" << 'TEOF'
# Research: {{FEATURE_NAME}}

> Spec: {{SPEC_NUMBER}} | Created: {{DATE}}
> Spec Reference: {{SPEC_PATH}}

## Library Analysis
| Library | Version | Pros | Cons | Decision |
|---------|---------|------|------|----------|
| [lib]   | [ver]   | [+]  | [-]  | [use/skip] |

## Performance Considerations
- [Benchmarks, expected load, bottlenecks]

## Security Implications
- [Attack vectors, auth requirements, data sensitivity]

## Existing Patterns in Codebase
- [What already exists that can be reused]
- [Conventions and patterns to follow]

## Constraints & Limitations
- [Infrastructure limits, budget, timeline]
- [Team expertise gaps]

## Recommendations
[Summary of findings and recommended approach based on research]

## Sources
- [Links to docs, benchmarks, articles consulted]
TEOF
    log_success "Created template: research.md"

    # Plan template
    cat > "$SPECS_TEMPLATES/plan.md" << 'TEOF'
# Plan: {{FEATURE_NAME}}

> Spec: {{SPEC_NUMBER}} | Created: {{DATE}}
> Spec Reference: {{SPEC_PATH}}
> Research Reference: {{RESEARCH_PATH}}

## Technical Approach
[Chosen approach and rationale, grounded in research findings]

## Technology Decisions
| Decision | Choice | Rationale | Research Ref |
|----------|--------|-----------|--------------|
| [area]   | [tech] | [why]     | [section]    |

## Worktree Mapping
| Module | Worktree Name | Preset | Agents |
|--------|--------------|--------|--------|
| [module] | [name] | [preset] | [auto] |

## Architecture
[Architecture description]

## Data Model
[If applicable]

## API Contracts
[If applicable]

## Constitutional Gates
- [ ] Research-First: all decisions backed by research
- [ ] Simplicity: max 3 initial modules
- [ ] Test-First: tests defined before implementation
- [ ] Integration-First: tests with real environment

## Implementation Order
1. Phase 1: [parallel modules]
2. Phase 2: [dependent modules]

## Test Strategy
[How to test end-to-end]

## Risks
- [Risk] -> [Mitigation]
TEOF
    log_success "Created template: plan.md"

    # Task template (enhanced with spec-ref and ralph frontmatter)
    cat > "$SPECS_TEMPLATES/task.md" << 'TEOF'
# Task: {{TASK_NAME}}

> spec-ref: {{SPEC_PATH}}
> preset: {{PRESET}}
> ralph: false
> max-iterations: 20
> stall-threshold: 3
> gates:
> completion-signal: RALPH_COMPLETE

## Objective
[Clear description of what should be done]

## Requirements
- [ ] Requirement 1
- [ ] Requirement 2

## Scope

### DO
- [ ] Item 1
- [ ] Item 2

### DON'T DO
- Out of scope item

### FILES
Create:
- src/path/to/file.ts

DON'T TOUCH:
- src/protected/

## Completion Criteria
- [ ] Code implemented
- [ ] Tests passing
- [ ] DONE.md created
TEOF
    log_success "Created template: task.md"
}

_sdd_create_default_constitution() {
    cat > "$CONSTITUTION_FILE" << 'CEOF'
# Project Constitution

> Immutable principles governing the transformation of specs into code.
> Inspired by GitHub Spec-Kit SDD. Fully customizable per project.

## Article I - Research-First
No technical decisions without documented research. Investigate before you decide.

## Article II - Test-First
No implementation code before tests are written and validated.

## Article III - Simplicity
Maximum 3 modules in initial implementation. No over-engineering.

## Article IV - Direct Usage
Use framework features directly. No unnecessary wrappers or abstractions.

## Article V - Integration Testing
Tests with real environments (databases, services). Mocks only when unavoidable.

## Article VI - Spec Traceability
All code must be traceable to a requirement in the spec. No "just in case" code.

## Article VII - Production Validation
No spec is complete until validated in the real environment. Tests passing is necessary but not sufficient — verify that data flows, logs appear, and features work end-to-end post-merge.

## Amendments
[Document changes with rationale and date]
CEOF
}

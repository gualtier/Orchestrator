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
    _sdd_create_default_templates

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

    # Extract feature name from spec
    local feature_name
    feature_name=$(head -1 "$spec_dir/spec.md" | sed 's/^# Spec: //')

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

    # Extract feature name from spec
    local feature_name
    feature_name=$(head -1 "$spec_dir/spec.md" | sed 's/^# Spec: //')

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
    printf "  %-30s %-15s %s\n" "SPEC" "STATUS" "NEXT STEP"
    log_separator

    echo "$specs" | while IFS='|' read -r name status; do
        local next_step=""
        case "$status" in
            empty)          next_step="-> run: sdd specify" ;;
            specified)      next_step="-> run: sdd research ${name%%-*}" ;;
            researched)     next_step="-> run: sdd plan ${name%%-*}" ;;
            planned)        next_step="-> run: sdd tasks ${name%%-*}" ;;
            tasks-ready)    next_step="-> run: setup & start" ;;
            executing*)     next_step="-> wait for agents" ;;
            completed)      next_step="-> run: sdd archive ${name%%-*}" ;;
        esac

        printf "  %-30s %-15s %s\n" "$name" "[$status]" "$next_step"
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

    if ! confirm "Archive spec '$spec_name'?"; then
        return 0
    fi

    ensure_dir "$SPECS_ARCHIVE"
    mv "$spec_dir" "$SPECS_ARCHIVE/"

    log_success "Archived: $spec_name -> specs/archive/"

    # Log event
    if [[ -f "$EVENTS_FILE" ]]; then
        echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] SDD_ARCHIVE: ${spec_name}" >> "$EVENTS_FILE"
    fi
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
    echo "  constitution -> specify -> research -> plan -> gate -> tasks -> [orchestrator]"
    echo ""
    echo -e "${BOLD}COMMANDS:${NC}"
    echo ""
    echo -e "  ${CYAN}sdd init${NC}                    Initialize SDD structure with templates"
    echo -e "  ${CYAN}sdd constitution${NC}            Show/create project constitution"
    echo -e "  ${CYAN}sdd specify \"description\"${NC}   Create a new spec from description"
    echo -e "  ${CYAN}sdd research <number>${NC}       Create research doc (MANDATORY)"
    echo -e "  ${CYAN}sdd plan <number>${NC}           Create implementation plan (requires research)"
    echo -e "  ${CYAN}sdd gate <number>${NC}           Check constitutional gates"
    echo -e "  ${CYAN}sdd tasks <number>${NC}          Generate orchestrator tasks from plan"
    echo -e "  ${CYAN}sdd status${NC}                  Show all active specs"
    echo -e "  ${CYAN}sdd archive <number>${NC}        Archive completed spec"
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
    echo "  orchestrate.sh sdd tasks 001"
    echo "  # ... then use normal orchestrator: setup, start, wait, merge ..."
    echo "  orchestrate.sh sdd archive 001"
    echo ""
}

# =============================================
# INTERNAL: Default templates
# =============================================

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

    # Task template (enhanced with spec-ref)
    cat > "$SPECS_TEMPLATES/task.md" << 'TEOF'
# Task: {{TASK_NAME}}

> spec-ref: {{SPEC_PATH}}
> preset: {{PRESET}}

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

## Amendments
[Document changes with rationale and date]
CEOF
}

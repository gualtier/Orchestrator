#!/bin/bash
# =============================================
# COMMAND: init - Orchestrator initialization
# =============================================

cmd_init() {
    log_step "Initializing orchestrator v3.3..."

    # Validate git repository
    validate_git_repo || return 1

    # Create directory structure
    ensure_dir "$ORCHESTRATION_DIR"/{tasks,status,logs,pids,archive,checkpoints,.recovery,.backups}
    ensure_dir "$AGENTS_DIR"
    ensure_dir "$CLAUDE_DIR/scripts"

    # Create base AGENT_CLAUDE.md
    create_agent_claude_base

    # Create or reset PROJECT_MEMORY.md
    _init_project_memory

    # Configure .gitignore
    _init_gitignore

    # Create examples if they do not exist
    ensure_dir "$ORCHESTRATION_DIR/examples"
    create_example_tasks

    # Initialize files
    touch "$EVENTS_FILE"

    log_success "Structure created!"

    # Show next steps
    echo ""
    echo -e "${CYAN}Next steps:${NC}"
    echo ""
    echo "  1. Install global CLI (optional):"
    echo "     ${GREEN}$0 install-cli${NC}"
    echo ""
    echo "  2. View available agents:"
    echo "     ${GREEN}$0 agents list${NC}"
    echo ""
    echo "  3. Create worktrees with agents:"
    echo "     ${GREEN}$0 setup auth --preset auth${NC}"
    echo ""
    echo "  4. Or copy an example task:"
    echo "     ${GREEN}$0 init-sample${NC}"
    echo ""
    echo "  5. Verify installation:"
    echo "     ${GREEN}$0 doctor${NC}"
}

cmd_install_cli() {
    local cli_name=${1:-"orch"}
    local install_dir="/usr/local/bin"
    local script_path="$SCRIPT_DIR/orchestrate.sh"
    local link_path="$install_dir/$cli_name"

    log_header "INSTALL CLI"

    # Check if script exists
    if [[ ! -f "$script_path" ]]; then
        log_error "Script not found: $script_path"
        return 1
    fi

    # Check if already exists
    if [[ -L "$link_path" ]]; then
        local existing_target=$(readlink "$link_path")
        if [[ "$existing_target" == "$script_path" ]]; then
            log_success "CLI '$cli_name' is already installed and points to the correct location"
            return 0
        else
            log_warn "CLI '$cli_name' already exists but points to: $existing_target"
            if ! confirm "Do you want to overwrite?"; then
                log_info "Operation cancelled"
                return 0
            fi
            sudo rm "$link_path"
        fi
    elif [[ -f "$link_path" ]]; then
        log_error "'$link_path' already exists and is not a symlink"
        log_info "Remove it manually or choose another name"
        return 1
    fi

    # Ensure the script is executable
    chmod +x "$script_path"

    # Create symlink
    log_step "Creating symlink in $install_dir..."

    if sudo ln -sf "$script_path" "$link_path"; then
        log_success "CLI installed successfully!"
        echo ""
        log_info "You can now use:"
        echo ""
        echo "  ${GREEN}$cli_name help${NC}"
        echo "  ${GREEN}$cli_name status${NC}"
        echo "  ${GREEN}$cli_name update-check${NC}"
        echo ""
    else
        log_error "Failed to create symlink"
        log_info "Check if you have sudo permissions"
        return 1
    fi

    return 0
}

cmd_uninstall_cli() {
    local cli_name=${1:-"orch"}
    local link_path="/usr/local/bin/$cli_name"

    log_header "UNINSTALL CLI"

    if [[ ! -L "$link_path" ]]; then
        if [[ -f "$link_path" ]]; then
            log_error "'$link_path' exists but is not a symlink"
            return 1
        else
            log_warn "CLI '$cli_name' is not installed"
            return 0
        fi
    fi

    if ! confirm "Remove CLI '$cli_name'?"; then
        log_info "Operation cancelled"
        return 0
    fi

    if sudo rm "$link_path"; then
        log_success "CLI '$cli_name' removed successfully"
    else
        log_error "Failed to remove CLI"
        return 1
    fi

    return 0
}

cmd_init_sample() {
    log_step "Copying example tasks..."

    local examples_dir="$ORCHESTRATION_DIR/examples"
    local tasks_dir="$ORCHESTRATION_DIR/tasks"

    if [[ ! -d "$examples_dir" ]] || [[ -z "$(ls -A "$examples_dir" 2>/dev/null)" ]]; then
        create_example_tasks
    fi

    for example in "$examples_dir"/*.md; do
        [[ -f "$example" ]] || continue
        local name=$(basename "$example")
        if [[ ! -f "$tasks_dir/$name" ]]; then
            cp "$example" "$tasks_dir/$name"
            log_success "Copied: $name"
        else
            log_warn "Already exists: $name (skipping)"
        fi
    done

    log_success "Examples copied to $tasks_dir"
    log_info "Edit the tasks as needed"
}

# =============================================
# HELPERS
# =============================================

_init_gitignore() {
    local gitignore="$PROJECT_ROOT/.gitignore"
    local marker="# Orchestrator (auto-generated)"
    local entries=(
        ""
        "$marker"
        ".claude/orchestration/logs/"
        ".claude/orchestration/pids/"
        ".claude/orchestration/status/"
        ".claude/orchestration/archive/"
        ".claude/orchestration/checkpoints/"
        ".claude/orchestration/.recovery/"
        ".claude/orchestration/.backups/"
        ".claude/orchestration/EVENTS.md"
        ".claude/agents/"
        ".claude/PROJECT_MEMORY.md.orchestrator-backup"
    )

    # If marker already exists, do not add again
    if [[ -f "$gitignore" ]] && grep -q "$marker" "$gitignore" 2>/dev/null; then
        log_info ".gitignore already configured (keeping)"
        return 0
    fi

    log_step "Configuring .gitignore..."

    # Add entries to .gitignore
    for entry in "${entries[@]}"; do
        echo "$entry" >> "$gitignore"
    done

    log_success ".gitignore updated"
}

_init_project_memory() {
    # If does not exist, create new
    if ! file_exists "$MEMORY_FILE"; then
        log_step "Creating PROJECT_MEMORY.md..."
        create_initial_memory
        return 0
    fi

    # Check if it is the orchestrator memory (repo template)
    if grep -q "Nome.*claude-orchestrator\|Name.*claude-orchestrator" "$MEMORY_FILE" 2>/dev/null; then
        log_warn "Detected PROJECT_MEMORY.md from the orchestrator repository"
        log_info "Creating clean memory for your project..."

        # Backup of original (for reference)
        cp "$MEMORY_FILE" "$MEMORY_FILE.orchestrator-backup"

        # Create clean memory
        create_initial_memory

        log_success "New memory created!"
        log_info "Backup saved at: PROJECT_MEMORY.md.orchestrator-backup"
        return 0
    fi

    # Memory already exists and is from another project
    log_info "PROJECT_MEMORY.md already exists (keeping)"
}

# =============================================
# TEMPLATES
# =============================================

create_agent_claude_base() {
    cat > "$CLAUDE_DIR/AGENT_CLAUDE.md" << 'EOF'
# EXECUTOR AGENT

**YOU ARE NOT AN ORCHESTRATOR**

## Identity
You are an EXECUTOR AGENT with a specific task.
You have specialized expertise according to the loaded agents.

## Absolute Rules
1. **NEVER** create worktrees or other agents
2. **NEVER** run orchestrate.sh
3. **NEVER** modify PROJECT_MEMORY.md
4. **FOCUS** exclusively on your task

## Your Workflow
1. Create initial PROGRESS.md
2. Execute task step by step
3. Update PROGRESS.md frequently
4. Make descriptive commits
5. Create DONE.md when finished

## Status Files

### PROGRESS.md
```markdown
# Progress: [task]
## Status: IN PROGRESS
## Completed
- [x] Item
## Pending
- [ ] Item
## Last Update
[DATE]: [description]
```

### DONE.md (when finished)
```markdown
# Completed: [task]
## Summary
[What was done]
## Files
- path/file.ts - [change]
## How to Test
[Test instructions]
```

### BLOCKED.md (if necessary)
```markdown
# Blocked: [task]
## Problem
[Description]
## Need
[What unblocks it]
```

## Commits
```
feat(scope): description
fix(scope): description
refactor(scope): description
test(scope): description
```
EOF
}

create_initial_memory() {
    local template_file="$CLAUDE_DIR/PROJECT_MEMORY.template.md"
    local current_date=$(date '+%Y-%m-%d %H:%M')
    local start_date=$(date '+%Y-%m-%d')
    local repo_url=$(git remote get-url origin 2>/dev/null || echo "[local]")

    if file_exists "$template_file"; then
        # Copy from template and fill in project-specific values
        sed -e "s|\[PROJECT_NAME\]|$PROJECT_NAME|g" \
            -e "s|\[DATE\]|$start_date|g" \
            -e "s|\[REPO_URL\]|$repo_url|g" \
            -e "s|> \*\*Last update\*\*: TEMPLATE|> **Last update**: $current_date|" \
            "$template_file" > "$MEMORY_FILE"
    else
        # Fallback: generate inline if template is missing
        cat > "$MEMORY_FILE" << EOF
# Project Memory

> **Last update**: $current_date
> **Version**: 0.1

## Overview

### Project

- **Name**: $PROJECT_NAME
- **Description**: [Describe your project here]
- **Started**: $start_date
- **Repo**: $repo_url

### Stack

| Layer     | Technology |
|-----------|------------|
| Language  | [DEFINE]   |
| Framework | [DEFINE]   |
| Database  | [DEFINE]   |

## Architecture

[Describe your project architecture]

## Roadmap

### v0.1 - MVP

- [ ] Feature 1
- [ ] Feature 2

## Architecture Decisions

### ADR-001: [Decision Title]

- **Decision**: [What was decided]
- **Reason**: [Why it was decided]
- **Trade-off**: [Pros and cons]

## Resolved Problems

| Problem | Version | Solution |
|---------|---------|----------|
| -       | -       | -        |

## Lessons Learned

1. [Add lessons learned during development]

## Next Session

### In Progress

- [ ] [Tasks in progress]

### Future Ideas

- [Ideas to implement later]

---
> Update with: \`orch update-memory\` or \`.claude/scripts/orchestrate.sh update-memory\`
EOF
    fi
}

create_example_tasks() {
    local examples_dir="$ORCHESTRATION_DIR/examples"
    ensure_dir "$examples_dir"

    # Example: Auth
    cat > "$examples_dir/auth.md" << 'EOF'
# Task: Authentication System

## Objective
Implement authentication system with JWT.

## Requirements
- [ ] Login with email/password
- [ ] User registration
- [ ] Refresh token
- [ ] Logout

## Scope

### DO
- [ ] User model
- [ ] Auth routes (/login, /register, /logout)
- [ ] Authentication middleware
- [ ] Tests

### DO NOT DO
- OAuth/Social login (next phase)
- 2FA (next phase)

## Files
Create:
- src/auth/
- src/auth/routes.ts
- src/auth/middleware.ts
- src/auth/models/user.ts

## Completion Criteria
- [ ] Tests passing
- [ ] API documentation
- [ ] DONE.md created
EOF

    # Example: API
    cat > "$examples_dir/api-crud.md" << 'EOF'
# Task: API CRUD

## Objective
Create REST API for resource management.

## Requirements
- [ ] CRUD endpoints (Create, Read, Update, Delete)
- [ ] Input validation
- [ ] Pagination
- [ ] Error handling

## Scope

### DO
- [ ] REST routes
- [ ] Validators
- [ ] Controllers
- [ ] Tests

### DO NOT DO
- Authentication (other worktree)
- Frontend

## Files
Create:
- src/api/
- src/api/routes.ts
- src/api/controllers/
- src/api/validators/

## Completion Criteria
- [ ] Endpoints working
- [ ] Tests passing
- [ ] DONE.md created
EOF

    # Example: Frontend
    cat > "$examples_dir/frontend.md" << 'EOF'
# Task: Frontend Interface

## Objective
Create responsive user interface.

## Requirements
- [ ] Responsive layout
- [ ] Reusable components
- [ ] API integration
- [ ] Loading/error states

## Scope

### DO
- [ ] Component structure
- [ ] Main pages
- [ ] API integration
- [ ] Styles

### DO NOT DO
- E2E Tests (next phase)
- Complex animations

## Files
Create:
- src/components/
- src/pages/
- src/hooks/
- src/styles/

## Completion Criteria
- [ ] UI working
- [ ] Responsive
- [ ] DONE.md created
EOF
}

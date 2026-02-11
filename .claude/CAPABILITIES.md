# Orchestrator Capabilities v3.5

> This file is auto-updated by `orch update`. Do NOT edit manually.
> Read this file at the start of every session to know what tools are available.

## Available Features

### SDD - Spec-Driven Development

Full specification pipeline before coding. Use for medium/large features.

```
constitution -> specify -> research (MANDATORY) -> plan -> gate -> tasks -> orchestrate
```

**Skills (type directly in Claude Code):**

| Skill | Description |
|-------|-------------|
| `/sdd` | SDD hub - shows workflow, status, available commands |
| `/sdd-specify "desc"` | Create a new spec from a feature description |
| `/sdd-research 001` | Research libraries, patterns, security for a spec |
| `/sdd-plan 001` | Create technical implementation plan |
| `/sdd-gate 001` | Validate plan against constitutional gates |
| `/sdd-tasks 001` | Generate orchestrator task files from plan |
| `/sdd-status` | Show status of all active specs |
| `/sdd-archive 001` | Archive a completed spec |

### Orchestration - Multi-Agent Worktrees

Parallel execution with specialized agents in Git worktrees.

**Skills:**

| Skill | Description |
|-------|-------------|
| `/orch` | Orchestrator hub - shows commands and status |
| `/orch-setup <name> --preset <preset>` | Create worktree with agent preset |
| `/orch-start` | Start agents in all worktrees |
| `/orch-status` | Monitor agent progress |
| `/orch-merge` | Merge completed worktrees |

**Available Presets:**

| Preset | Agents | Use Case |
|--------|--------|----------|
| `auth` | backend-developer, security-auditor, typescript-pro | Authentication, JWT |
| `api` | api-designer, backend-developer, test-automator | REST/GraphQL APIs |
| `frontend` | frontend-developer, react-specialist, ui-designer | UI, React, Vue |
| `fullstack` | fullstack-developer, typescript-pro, test-automator | Complete features |
| `mobile` | mobile-developer, flutter-expert, ui-designer | Mobile apps |
| `devops` | devops-engineer, kubernetes-specialist, terraform-engineer | CI/CD, infra |
| `data` | data-engineer, data-scientist, postgres-pro | Pipelines, ETL |
| `ml` | ml-engineer, ai-engineer, mlops-engineer | Machine Learning |
| `security` | security-auditor, penetration-tester, security-engineer | Security audits |
| `review` | code-reviewer, architect-reviewer, security-auditor | Code review |
| `backend` | backend-developer, api-designer, database-administrator | General backend |
| `database` | database-administrator, postgres-pro, sql-pro | Database tasks |

### CLI Commands

```bash
orch init              # Initialize orchestrator
orch setup <n> --preset <p>  # Create worktree
orch start             # Start agents
orch status            # Check progress
orch wait              # Wait for completion
orch merge             # Merge worktrees
orch cleanup           # Remove worktrees
orch update            # Update orchestrator from remote
orch update-check      # Check for updates
orch update-memory     # Update PROJECT_MEMORY.md
orch doctor            # Verify installation
orch learn             # Extract insights from completed tasks
orch help              # Show all commands
```

### Memory Management

- `PROJECT_MEMORY.md` - Persistent project context across sessions
- `orch update-memory` - Auto-update memory after changes
- `orch update-memory --full` - Full update with version increment + changelog

### Constitution System

- `.claude/specs/constitution.md` - Editable project principles
- Gates validate plans against constitutional rules before execution
- Research is mandatory before planning (enforced by gates)

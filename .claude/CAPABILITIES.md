# Orchestrator Capabilities v3.9.1

> This file is auto-updated by `orch update`. Do NOT edit manually.
> Read this file at the start of every session to know what tools are available.

## Available Features

### SDD - Spec-Driven Development

Full specification pipeline before coding. Use for medium/large features.

```
constitution -> specify -> research (MANDATORY) -> plan -> gate -> run (autopilot)
OR: ... -> gate -> tasks -> setup -> start (manual step-by-step)
```

Supports two execution backends:
- **Worktree mode** (default): Git worktrees with isolated directories per agent
- **Teams mode**: Claude Code Agent Teams with native coordination (`--mode teams`)

**Skills (type directly in Claude Code):**

| Skill | Description |
|-------|-------------|
| `/sdd` | SDD hub - shows workflow, status, available commands |
| `/sdd-specify "desc"` | Create a new spec from a feature description |
| `/sdd-research 001` | Research libraries, patterns, security for a spec |
| `/sdd-plan 001` | Create technical implementation plan |
| `/sdd-gate 001` | Validate plan against constitutional gates |
| `/sdd-run [001]` | Autopilot: gate -> tasks -> setup -> start -> monitor. Add `--auto-merge` for full hands-off |
| `/sdd-tasks 001` | Generate orchestrator task files from plan (manual mode) |
| `/sdd-status` | Show status of all active specs |
| `/sdd-archive 001` | Archive a completed spec |

### Orchestration - Multi-Agent Execution

Parallel execution with specialized agents. Two backends available:

- **Worktree mode** (default): Git worktrees with isolated directories per agent
- **Teams mode** (v3.8): Claude Code Agent Teams with native coordination
- **Async-first** (v3.9.1): ALWAYS launch with `--no-monitor`, poll every 30s, NEVER block

**Skills:**

| Skill | Description |
|-------|-------------|
| `/orch` | Orchestrator hub - shows commands and status |
| `/orch-setup <name> --preset <preset>` | Create worktree with agent preset |
| `/orch-start` | Start agents async (`--no-monitor`), poll every 30s |
| `/orch-status` | Monitor agent progress (poll every 30s, NEVER `--watch`) |
| `/orch-errors` | Error monitoring dashboard (poll every 30s, react to failures) |
| `/orch-merge` | Merge completed worktrees + post-merge routines |
| `/orch-team-start` | Start Agent Team from SDD spec (teams mode) |
| `/orch-team-status` | Monitor Agent Team progress |

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
# Setup
orch init              # Initialize orchestrator
orch init-sample       # Initialize with example tasks
orch doctor            # Verify installation health
orch install-cli       # Create global 'orch' shortcut
orch uninstall-cli     # Remove global shortcut

# Worktrees & Agents
orch setup <n> --preset <p>  # Create worktree with agents
orch agents            # List available agents

# Execution (ASYNC — Rule #2: NEVER block)
orch start --no-monitor  # Start agents async (ALWAYS use --no-monitor)
orch stop              # Stop running agents
orch restart           # Restart agents

# SDD Autopilot (v3.7, enhanced v3.9)
orch sdd run [number]  # Autopilot: gate -> tasks -> setup -> start -> monitor
                       # No number = all planned specs
orch sdd run 001 --auto-merge   # Full hands-off: gate -> ... -> merge -> archive (v3.9)
orch sdd run 001 --mode teams   # Use Agent Teams backend instead of worktrees (v3.8)

# Agent Teams (v3.8)
orch team start <spec-number>  # Start Agent Team from SDD spec
orch team status               # Show team status (teammates, tasks, progress)
orch team stop                 # Stop running team

# Monitoring (poll every 30s — NEVER block, NEVER increase interval)
orch status            # Check progress (poll every 30s)
orch status --enhanced # Detailed view with progress bars, activity, errors
orch status --compact  # One-line-per-agent view
orch status --json     # Machine-readable output
orch errors            # Error monitoring dashboard (poll every 30s)
orch errors --agent X  # Filter errors by agent
orch errors --recent   # Show last 50 errors with details
orch errors --clear    # Clear error tracking
orch logs <name>       # Show recent log output for an agent
orch follow <name>     # Follow log output in real-time (tail -f)
# NOTE: --watch and wait are available but NEVER use them (they block)

# Verification & Merge
orch verify            # Verify a specific worktree
orch verify-all        # Verify all worktrees
orch pre-merge         # Pre-merge checks
orch review            # Code review
orch report            # Generate completion report
orch merge             # Merge worktrees to main
orch cleanup           # Remove worktrees

# Memory & Learning
orch update-memory     # Update PROJECT_MEMORY.md timestamp
orch update-memory --full  # Full update with version bump + changelog
orch show-memory       # Display current memory
orch learn extract     # Extract insights from completed DONE.md files
orch learn apply       # Review and apply learnings to CLAUDE.md

# Updates
orch update            # Update orchestrator from remote
orch update-check      # Check for updates

# Help
orch help              # Show all commands
```

### SDD Autopilot (v3.7, enhanced v3.9)

End-to-end pipeline execution after plan approval:

- `sdd run 001` — single spec autopilot (pauses before merge)
- `sdd run` — all planned specs at once
- `sdd run 001 --auto-merge` — fully autonomous: gate → tasks → setup → start → merge → archive (v3.9)
- `sdd run 001 --mode teams` — use Agent Teams backend (v3.8)
- Fail-fast on gate failure, task errors, or setup errors
- Auto `update-memory --full` and `learn extract` after agents complete (v3.9)
- `SDD_AUTOPILOT=1` env var bypasses stop hooks during autonomous execution (v3.9)

### Autonomous Pipeline (v3.9)

Hooks and self-dev awareness for fully autonomous SDD execution:

- **`hooks/lib/hook-utils.sh`**: Shared utilities — `is_self_dev()`, `is_autopilot()`, `json_ok/fail()`
- **`hooks/memory-check.sh`**: Command hook replacing prompt-based memory check (reliable, no LLM latency)
- **Self-dev detection**: Command hooks detect orchestrator repo (origin URL contains "orchestrator") and bypass client-facing guards
- **`SDD_AUTOPILOT=1`**: Set automatically during `sdd run`, hooks pass through without blocking
- **`--auto-merge`**: Full pipeline without intervention — merge, learn extract, archive all automatic
- **Backward compatible**: Without `--auto-merge`, behavior is unchanged (pauses before merge)

### Agent Teams Backend (v3.8)

Alternative execution backend using Claude Code Agent Teams:

- **Dual mode**: `--mode teams|worktree` flag on `sdd run` (default: worktree)
- **Team lead prompt**: Auto-generated from SDD artifacts (spec, research, plan)
- **Agent specialization**: Preset agent `.md` content injected into teammate spawn prompts
- **Branch-per-teammate**: File conflict mitigation without worktree isolation
- **Quality gate hooks**: `TeammateIdle` (prevents idle without commits) and `TaskCompleted` (validates work)
- **Graceful fallback**: Falls back to worktrees if `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` is not set
- **Hybrid monitoring**: Interactive team lead session + background orchestrator dashboard
- **`team start|status|stop`**: Dedicated team management commands
- **`EXECUTION_MODE` env var**: Configure default backend (worktree or teams)

### Error Monitoring (v3.6)

Active error detection during agent execution:
- Incremental byte-offset log polling (5s interval, ~5-25ms per agent)
- 3-tier severity: CRITICAL / WARNING / INFO
- Corrective action suggestions per error type
- Persistent error log at `.claude/orchestration/errors.log`
- Integrated into `status` and `wait` commands automatically

### Memory Management

- `PROJECT_MEMORY.md` - Persistent project context across sessions
- `CAPABILITIES.md` - Available features and commands (this file)
- `orch update-memory` - Auto-update memory after changes
- `orch update-memory --full` - Full update with version increment + changelog

### Constitution System

- `.claude/specs/constitution.md` - Editable project principles
- Gates validate plans against constitutional rules before execution
- Research is mandatory before planning (enforced by gates)

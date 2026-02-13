---
name: orch
description: Orchestrator hub. Shows available commands, agent status, and workflow guidance. Use when asking about orchestration or managing agents.
argument-hint: [subcommand]
allowed-tools: Bash, Read
---

# Claude Orchestrator

Multi-agent orchestration using Git Worktrees with specialized agents.

## Current Status

!`.claude/scripts/orchestrate.sh status --compact 2>&1 || echo "No active orchestration."`

## Available Skills

| Skill | Description |
|-------|-------------|
| `/orch-setup` | Create worktree with agent preset |
| `/orch-start` | Start agents |
| `/orch-status` | Monitor agent progress |
| `/orch-errors` | Error monitoring dashboard |
| `/orch-merge` | Merge and cleanup |
| `/orch-team-start` | Start Agent Team from SDD spec |
| `/orch-team-status` | Monitor Agent Team progress |
| `/sdd` | Spec-Driven Development flow |

## Workflow

**For large features — worktree mode** (default):
```
/sdd → /sdd-specify → /sdd-research → /sdd-plan → /sdd-gate → /sdd-tasks → /orch-setup → /orch-start → /orch-errors → /orch-merge
```

**For large features — teams mode** (v3.8):
```
/sdd → /sdd-specify → /sdd-research → /sdd-plan → /sdd-gate → /orch-team-start → /orch-team-status → /orch-merge
```

**For small tasks** (direct):
```
/orch-setup <name> --preset <preset> → /orch-start → /orch-merge
```

## All Commands

```bash
.claude/scripts/orchestrate.sh help
```

## Memory

!`head -10 .claude/PROJECT_MEMORY.md 2>/dev/null || echo "No project memory found."`

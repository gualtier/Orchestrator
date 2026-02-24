---
name: sdd-run
description: Autopilot mode. Runs gate, tasks, setup, start, and monitor for all planned specs (or a single one). Supports --mode teams for Agent Teams backend. Supports --auto-merge for fully autonomous execution. Pauses before merge for review.
argument-hint: spec number [--auto-merge] [--mode teams]
allowed-tools: Bash, Read
---

Run the SDD autopilot pipeline.

```bash
# Single spec (worktree mode - default)
.claude/scripts/orchestrate.sh sdd run $ARGUMENTS

# All planned specs (if no number given)
.claude/scripts/orchestrate.sh sdd run

# Fully autonomous (v3.9) - merge + archive happen automatically
.claude/scripts/orchestrate.sh sdd run 001 --auto-merge

# Agent Teams mode (v3.8)
.claude/scripts/orchestrate.sh sdd run 001 --mode teams
```

## What It Does

Chains everything automatically after the plan is approved:

1. **Gate check** — Validates constitutional gates (stops on failure)
2. **Task generation** — Creates orchestrator task files from the plan
3. **Worktree setup** — Creates all worktrees from the Worktree Mapping table (skipped in teams mode)
4. **Agent start + monitor** — Starts all agents and monitors until completion
5. **Results summary** — Shows completion status and suggests merge

With `--auto-merge` (v3.9), additional steps run automatically:

6. **Auto merge** — Merges all worktrees to main
7. **Auto post-merge** — Runs `update-memory --full` and `learn extract`
8. **Auto archive** — Archives the spec and cleans up worktrees

## Execution Backends

- **Worktree mode** (default): Git worktrees with isolated directories per agent
- **Teams mode** (`--mode teams`): Claude Code Agent Teams with native coordination, shared tasks, messaging, and delegate mode. Requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`

## Modes

- `sdd run 001` — Autopilot for a single spec (pauses before merge)
- `sdd run 001 --auto-merge` — Fully autonomous (merge + archive automatic)
- `sdd run` — Autopilot for ALL active specs that have a plan.md
- `sdd run 001 --mode teams` — Use Agent Teams backend

## Prerequisites

Each spec must have completed:
- `spec.md` (via `/sdd-specify`)
- `research.md` (via `/sdd-research`)
- `plan.md` with a Worktree Mapping table (via `/sdd-plan`)

## After Completion

Without `--auto-merge`, the command pauses before merge so you can review:

```bash
.claude/scripts/orchestrate.sh verify-all
.claude/scripts/orchestrate.sh merge
.claude/scripts/orchestrate.sh update-memory --full
```

With `--auto-merge`, all post-completion steps happen automatically.

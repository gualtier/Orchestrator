---
name: sdd-run
description: Autopilot mode. Runs gate, tasks, setup, start, and monitor for all planned specs (or a single one). Pauses before merge for review.
argument-hint: [spec number (optional, runs all if omitted)]
allowed-tools: Bash, Read
---

Run the SDD autopilot pipeline.

```bash
# Single spec
.claude/scripts/orchestrate.sh sdd run $ARGUMENTS

# All planned specs (if no number given)
.claude/scripts/orchestrate.sh sdd run
```

## What It Does

Chains everything automatically after the plan is approved:

1. **Gate check** — Validates constitutional gates (stops on failure)
2. **Task generation** — Creates orchestrator task files from the plan
3. **Worktree setup** — Creates all worktrees from the Worktree Mapping table
4. **Agent start + monitor** — Starts all agents and monitors until completion
5. **Results summary** — Shows completion status and suggests merge

## Modes

- `sdd run 001` — Autopilot for a single spec
- `sdd run` — Autopilot for ALL active specs that have a plan.md

## Prerequisites

Each spec must have completed:
- `spec.md` (via `/sdd-specify`)
- `research.md` (via `/sdd-research`)
- `plan.md` with a Worktree Mapping table (via `/sdd-plan`)

## After Completion

The command pauses before merge so you can review. Then:

```bash
.claude/scripts/orchestrate.sh verify-all
.claude/scripts/orchestrate.sh merge
.claude/scripts/orchestrate.sh update-memory --full
```

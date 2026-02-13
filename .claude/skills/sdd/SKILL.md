---
name: sdd
description: Spec-Driven Development hub. Shows SDD workflow, status, and available commands. Use when asking about SDD or starting a feature.
argument-hint: [subcommand or feature description]
allowed-tools: Bash, Read
---

# Spec-Driven Development (SDD)

Inspired by [GitHub Spec-Kit](https://github.com/github/spec-kit). Specifications are the primary artifact - code serves specifications, not the other way around.

## Current Status

!`.claude/scripts/orchestrate.sh sdd status 2>&1 || echo "SDD not initialized. Run /sdd-init first."`

## Workflow

```
/sdd-init          Initialize SDD (first time)
     ↓
/sdd-specify       Create specification from description
     ↓
/sdd-research      Investigate (MANDATORY before plan)
     ↓
/sdd-plan          Create technical plan with worktree mapping
     ↓
/sdd-gate          Check constitutional compliance
     ↓
/sdd-run           Autopilot (gate -> tasks -> setup -> start -> monitor)
     OR             (runs all planned specs, or pass a number for one)
/sdd-tasks         Generate orchestrator tasks (manual step-by-step)
     ↓
/orch-setup        Create worktrees with agents
/orch-start        Start agents
/orch-status       Monitor progress
/orch-merge        Merge completed work
     ↓
/sdd-archive       Archive completed spec
```

## Constitution

!`cat .claude/specs/constitution.md 2>/dev/null | head -30 || echo "No constitution yet. Run /sdd-init to create one."`

## Quick Start

If you have a feature to build, start with:
```
/sdd-specify "your feature description here"
```

Or run the full flow via bash:
```bash
.claude/scripts/orchestrate.sh sdd help
```

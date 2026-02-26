---
name: orch-start
description: Start agents in all worktrees or specific ones. Use proactively after worktrees are created to launch Claude Code instances with specialized prompts.
argument-hint: [agent names (optional)]
allowed-tools: Bash
---

Start agents in worktrees (ASYNC — Rule #2).

**ALWAYS launch async with `--no-monitor`**, then poll every 30s:

```bash
# Start all agents (async — returns immediately)
.claude/scripts/orchestrate.sh start --no-monitor

# Start specific agents (async)
.claude/scripts/orchestrate.sh start --no-monitor $ARGUMENTS
```

After starting, poll status and errors every 30 seconds (NEVER block, NEVER increase interval):

```bash
# Quick status check (run every 30s)
.claude/scripts/orchestrate.sh status

# Error check (run every 30s alongside status)
.claude/scripts/orchestrate.sh errors
```

**NEVER** use `wait` or `start` without `--no-monitor` — these block the orchestrator.
React immediately to failures detected in error polls.

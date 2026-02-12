---
name: orch-errors
description: Show error monitoring dashboard for all running agents. Use proactively during orchestration to detect and diagnose agent errors in real-time.
allowed-tools: Bash
---

Show the error monitoring dashboard for orchestrator agents.

## Error Dashboard

!`.claude/scripts/orchestrate.sh errors 2>&1 || echo "No errors detected or no active orchestration."`

## Options

```bash
# Watch mode (auto-refresh every 5s)
.claude/scripts/orchestrate.sh errors --watch

# Filter by agent
.claude/scripts/orchestrate.sh errors --agent <name>

# Show recent 50 errors with details
.claude/scripts/orchestrate.sh errors --recent

# Clear error tracking
.claude/scripts/orchestrate.sh errors --clear
```

## When to Use

- After `/orch-start` — check if agents are hitting errors
- During `/orch-status` — if an agent shows slow progress
- Before `/orch-merge` — verify no critical errors remain
- When an agent status shows "stalled" — diagnose why

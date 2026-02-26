---
name: orch-errors
description: Show error monitoring dashboard for all running agents. Use proactively during orchestration to detect and diagnose agent errors in real-time.
allowed-tools: Bash
---

Show the error monitoring dashboard for orchestrator agents.

## Error Dashboard

!`.claude/scripts/orchestrate.sh errors 2>&1 || echo "No errors detected or no active orchestration."`

## Monitoring Pattern (Rule #2)

Poll this every **30 seconds** alongside `/orch-status`. NEVER use `--watch` (it blocks). React immediately to CRITICAL errors.

```bash
# One-shot error check (run every 30s, non-blocking)
.claude/scripts/orchestrate.sh errors

# Filter by agent
.claude/scripts/orchestrate.sh errors --agent <name>

# Show recent 50 errors with details
.claude/scripts/orchestrate.sh errors --recent

# Clear error tracking
.claude/scripts/orchestrate.sh errors --clear
```

## When to Use

- After `/orch-start` — check every 30s if agents are hitting errors
- During monitoring loop — catch failures fast, react immediately
- Before `/orch-merge` — verify no critical errors remain
- When an agent status shows "stalled" — diagnose why

---
name: orch-status
description: Show the status of all running agents and worktrees. Use to monitor orchestration progress.
allowed-tools: Bash
---

Show current orchestration status.

## Agent Status

!`.claude/scripts/orchestrate.sh status --compact 2>&1 || echo "No active orchestration. Use /orch-setup to create worktrees."`

## Monitoring Pattern (Rule #2)

Poll this every **30 seconds** alongside `/orch-errors`. NEVER use `--watch` (it blocks).

```bash
# Quick status (run every 30s, non-blocking)
.claude/scripts/orchestrate.sh status

# Enhanced with details (includes error counts)
.claude/scripts/orchestrate.sh status --enhanced

# JSON format (for automation)
.claude/scripts/orchestrate.sh status --json
```

## Error Monitoring

If agents show errors, use `/orch-errors` for the full error dashboard with severity breakdown and suggested actions.

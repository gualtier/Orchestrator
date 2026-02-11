---
name: orch-status
description: Show the status of all running agents and worktrees. Use to monitor orchestration progress.
allowed-tools: Bash
---

Show current orchestration status.

## Agent Status

!`.claude/scripts/orchestrate.sh status --compact 2>&1 || echo "No active orchestration. Use /orch-setup to create worktrees."`

## Options

```bash
# Enhanced status with details
.claude/scripts/orchestrate.sh status --enhanced

# Live updates (every 5 seconds)
.claude/scripts/orchestrate.sh status --watch

# JSON format (for automation)
.claude/scripts/orchestrate.sh status --json
```

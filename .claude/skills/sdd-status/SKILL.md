---
name: sdd-status
description: Show the status of all active SDD specifications. Use to check spec lifecycle progress.
allowed-tools: Bash
---

Show the current status of all active specifications.

## Current Status

!`.claude/scripts/orchestrate.sh sdd status 2>&1 || echo "No active specs. Run /sdd-init first."`

## Spec Lifecycle

```
specified → researched → planned → tasks-ready → executing → completed
```

Use `/sdd-specify` to create a new spec, or check a specific spec's files directly.

---
name: sdd-archive
description: Archive a completed SDD spec to specs/archive/. Use after all tasks are merged.
disable-model-invocation: true
argument-hint: [spec number]
allowed-tools: Bash
---

Archive completed spec $ARGUMENTS to the archive directory.

```bash
FORCE=true .claude/scripts/orchestrate.sh sdd archive $ARGUMENTS
```

This moves the spec from `specs/active/` to `specs/archive/` for historical reference.

Only archive after:
- All worktrees are merged
- All tasks are completed
- Memory has been updated (`/orch update-memory --full`)

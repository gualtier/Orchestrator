---
name: orch-merge
description: Merge completed worktrees back to main branch. Runs verification before merge.
disable-model-invocation: true
argument-hint: [branch (default: main)]
allowed-tools: Bash
---

Merge completed worktrees back to the main branch.

## Pre-merge Check

First, verify all worktrees are ready:

```bash
.claude/scripts/orchestrate.sh verify-all
```

## Merge

```bash
.claude/scripts/orchestrate.sh merge $ARGUMENTS
```

## Post-merge

After merge, always:

```bash
# Clean up worktrees
.claude/scripts/orchestrate.sh cleanup

# Update memory
.claude/scripts/orchestrate.sh update-memory --full

# Archive SDD spec if applicable
# .claude/scripts/orchestrate.sh sdd archive <number>
```

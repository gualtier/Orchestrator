---
name: sdd-tasks
description: Generate orchestrator task files from an SDD plan. Use proactively after gates pass. This is the bridge between specification and execution.
argument-hint: [spec number]
allowed-tools: Bash, Read
---

Generate orchestrator tasks from the plan for spec $ARGUMENTS.

This is the CRUCIAL BRIDGE between SDD (specification) and the Orchestrator (execution).

```bash
.claude/scripts/orchestrate.sh sdd tasks $ARGUMENTS
```

This command:
1. Parses the **Worktree Mapping** table from plan.md
2. Generates one `.claude/orchestration/tasks/<name>.md` per module
3. Each task includes spec-ref, acceptance criteria, and scope
4. Displays setup commands to create worktrees

## After Task Generation

Follow the output instructions to set up worktrees and start agents:

```bash
# Example (commands shown in output):
.claude/scripts/orchestrate.sh setup auth --preset auth
.claude/scripts/orchestrate.sh setup api --preset api
.claude/scripts/orchestrate.sh start
.claude/scripts/orchestrate.sh wait
```

Or use `/orch-setup` and `/orch-start` for guided execution.

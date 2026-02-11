---
name: orch-start
description: Start agents in all worktrees or specific ones. Use proactively after worktrees are created to launch Claude Code instances with specialized prompts.
argument-hint: [agent names (optional)]
allowed-tools: Bash
---

Start agents in worktrees.

```bash
# Start all agents
.claude/scripts/orchestrate.sh start

# Start specific agents
.claude/scripts/orchestrate.sh start $ARGUMENTS
```

After starting, monitor with `/orch-status` or wait for completion:

```bash
.claude/scripts/orchestrate.sh wait
```

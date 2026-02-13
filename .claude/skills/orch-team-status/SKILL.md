---
name: orch-team-status
description: Show the status of Agent Teams including teammates, tasks, and progress. Use this to monitor teams running via the Agent Teams backend.
argument-hint: [team-name]
allowed-tools: Bash
---

Show Agent Teams status dashboard.

```bash
# Show all teams
.claude/scripts/orchestrate.sh team status

# Show specific team
.claude/scripts/orchestrate.sh team status $ARGUMENTS
```

Displays:
- Team name
- Task status (pending/in_progress/completed)
- Team members (spawned teammates)

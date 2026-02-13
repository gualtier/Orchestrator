---
name: orch-team-start
description: Start an Agent Team from an SDD spec. Use this when the user wants to execute a spec using Claude Code Agent Teams instead of Git worktrees. Requires CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1.
argument-hint: <spec-number>
allowed-tools: Bash
---

Start an Agent Team from an SDD specification.

This is an alternative to Git worktrees that uses Claude Code's native Agent Teams feature for real-time inter-agent communication.

```bash
# Start team for spec 002
.claude/scripts/orchestrate.sh team start $ARGUMENTS

# Or use sdd run with --mode teams
.claude/scripts/orchestrate.sh sdd run $ARGUMENTS --mode teams
```

**Requirements:**
- CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 must be set
- Spec must have spec.md, research.md, and plan.md

**Teams vs Worktrees:**
- Teams: Real-time communication, no setup, more tokens
- Worktrees: Filesystem isolation, proven reliability, fewer tokens

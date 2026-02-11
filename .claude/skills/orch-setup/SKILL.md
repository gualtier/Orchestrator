---
name: orch-setup
description: Create a worktree with specialized agents using a preset. Use proactively after SDD tasks are generated or when the user confirms a worktree proposal.
argument-hint: [name] --preset [preset]
allowed-tools: Bash
---

Create a worktree with specialized agents.

```bash
.claude/scripts/orchestrate.sh setup $ARGUMENTS
```

## Available Presets

| Preset     | Agents                                                    |
|------------|-----------------------------------------------------------|
| `auth`     | backend-developer, security-auditor, typescript-pro       |
| `api`      | api-designer, backend-developer, test-automator           |
| `frontend` | frontend-developer, react-specialist, ui-designer         |
| `fullstack`| fullstack-developer, typescript-pro, test-automator       |
| `mobile`   | mobile-developer, flutter-expert, ui-designer             |
| `devops`   | devops-engineer, kubernetes-specialist, terraform-engineer |
| `data`     | data-engineer, data-scientist, postgres-pro               |
| `ml`       | ml-engineer, ai-engineer, mlops-engineer                  |
| `security` | security-auditor, penetration-tester, security-engineer   |
| `review`   | code-reviewer, architect-reviewer, security-auditor       |
| `backend`  | backend-developer, api-designer, database-administrator   |
| `database` | database-administrator, postgres-pro, sql-pro             |

## Examples

```bash
# With preset
.claude/scripts/orchestrate.sh setup auth --preset auth

# With specific agents
.claude/scripts/orchestrate.sh setup myfeature --agents backend-developer,test-automator

# From specific branch
.claude/scripts/orchestrate.sh setup auth --preset auth --from develop
```

# Plan: Agent Teams Execution Backend with Hybrid Monitoring

> Spec: 002 | Created: 2026-02-13
> Spec Reference: .claude/specs/active/002-agent-teams-execution-backend-with-hybrid-monitori/spec.md
> Research Reference: .claude/specs/active/002-agent-teams-execution-backend-with-hybrid-monitori/research.md

## Technical Approach

Add Claude Code Agent Teams as an alternative execution backend alongside existing Git worktrees. The orchestrator generates a comprehensive team lead prompt from SDD artifacts and launches an interactive Claude session. A tmux-based monitoring dashboard runs alongside. Research confirms teams must be created conversationally (no CLI flag), so the orchestrator's role is prompt generation + monitoring, not programmatic control.

Key design: extract `build_agent_prompt()` from `start_single_agent()` (start.sh:179-234) as a shared function used by both backends. The team lead prompt wraps all teammate prompts with coordination instructions (delegate mode, plan approval, branch-per-teammate). (Research: "Existing Patterns in Codebase" section)

## Technology Decisions

| Decision | Choice | Rationale | Research Ref |
| -------- | ------ | --------- | ------------ |
| Team creation | Interactive Claude session | Cannot use `claude -p` — teams require ongoing session | API Surface |
| Monitoring | tmux split pane (fallback: background) | Aligns with Agent Teams' own tmux usage | Hybrid Monitoring |
| File isolation | Branch-per-teammate + prompt scoping | No filesystem isolation in teams; git branches as safety net | Security Implications |
| Hook type | Command hooks (exit code 2) | TeammateIdle/TaskCompleted only support command type | Hook Mechanics |
| Agent injection | Spawn prompt concatenation | Embed agent .md content in teammate spawn prompts | Existing Patterns |

## Worktree Mapping

| Module | Worktree Name | Preset | Agents |
| ------ | ------------- | ------ | ------ |
| Agent Teams Backend | agent-teams | backend | backend-developer, api-designer, database-administrator |

## Architecture

### New Files

1. **`.claude/scripts/lib/teams.sh`** (~180 lines) — REQ-9
   - `detect_teams_available()` — Check `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` env var
   - `build_team_lead_prompt()` — Compose lead prompt from SDD artifacts + teammate prompts
   - `build_teammate_prompt()` — Build single teammate prompt (shared with worktree backend)
   - `generate_branch_instructions()` — Per-teammate branch naming

2. **`.claude/scripts/commands/team.sh`** (~80 lines) — REQ-10
   - `cmd_team()` — Router for `team start|status|stop`
   - `cmd_team_start()` — Build lead prompt, launch interactive session + monitoring
   - `cmd_team_status()` — Read `~/.claude/teams/` config, show status
   - `cmd_team_stop()` — Send stop instruction to team lead

3. **`.claude/hooks/teammate-idle.sh`** (~25 lines) — REQ-6
   - Read `teammate_name` from stdin JSON
   - Check if teammate has commits on `feature/{name}` branch
   - Exit 2 with feedback if no commits found

4. **`.claude/hooks/task-completed.sh`** (~30 lines) — REQ-6
   - Read `task_subject` and `teammate_name` from stdin JSON
   - Validate teammate made commits
   - Exit 2 with feedback if validation fails

### Modified Files

5. **`.claude/scripts/lib/core.sh`** — REQ-1, REQ-4
   - Add `EXECUTION_MODE` config variable (default: `worktree`)
   - Source `lib/teams.sh`

6. **`.claude/scripts/commands/start.sh`** — REQ-7
   - Extract prompt builder from `start_single_agent()` (lines 179-234) into `build_agent_prompt()`
   - Both `start_single_agent()` and teams backend call the shared function

7. **`.claude/scripts/commands/sdd.sh`** — REQ-1, REQ-2
   - Add `--mode teams|worktree` flag parsing in `cmd_sdd_run()`
   - In teams mode: skip Phase 2 (worktree setup), call `cmd_team_start()` for Phase 3

8. **`.claude/scripts/orchestrate.sh`** — REQ-10
   - Add `team)` case to command router
   - Source `lib/teams.sh`

9. **`.claude/settings.json`** — REQ-6
   - Add `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS: "1"` to env
   - Add `TeammateIdle` and `TaskCompleted` hook entries

### New Skills

10. **`.claude/skills/orch-team-start/SKILL.md`** — REQ-10
11. **`.claude/skills/orch-team-status/SKILL.md`** — REQ-10
12. **`.claude/skills/orch-team-stop/SKILL.md`** — REQ-10

### Updated Documentation

13. **`.claude/CAPABILITIES.md`** — Document teams feature
14. **`.claude/skills/sdd-run/SKILL.md`** — Document `--mode teams`
15. **`.claude/skills/orch/SKILL.md`** — Add team commands to hub

## Constitutional Gates

- [x] Research-First: all decisions reference research.md findings (API Surface, Hook Mechanics, Hybrid Monitoring, Existing Patterns)
- [x] Simplicity: 1 worktree module (well under max 3)
- [x] Test-First: test strategy defined below
- [x] Integration-First: tests use real orchestrator commands against actual files

## Implementation Order

1. Phase 1: agent-teams worktree (single module, all changes)
   - lib/teams.sh (foundation)
   - lib/core.sh modifications
   - commands/start.sh refactor (extract build_agent_prompt)
   - commands/team.sh (new)
   - commands/sdd.sh modifications
   - orchestrate.sh routing
   - Hook scripts
   - settings.json
   - Skills (3 new)
   - Documentation updates

## Test Strategy

1. **Worktree regression**: Run `orchestrate.sh sdd run` without `--mode` flag — verify existing worktree flow works unchanged
2. **Fallback test**: Unset `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`, run `sdd run --mode teams` — verify warning + fallback to worktrees
3. **Prompt generation test**: Run `cmd_team_start` with a sample plan.md — verify the generated lead prompt contains:
   - SDD artifacts (spec, research, plan references)
   - Correct teammate count matching worktree mapping rows
   - Agent specialization content from preset .md files
   - Delegate mode instruction
   - Plan approval requirement
   - Branch-per-teammate instructions
   - File ownership boundaries
4. **Hook test**: Run `teammate-idle.sh` with mock JSON input — verify exit code 2 when no commits on branch
5. **Skills test**: Verify `/orch-team-start`, `/orch-team-status`, `/orch-team-stop` skills load correctly
6. **Command routing**: Verify `orchestrate.sh team start|status|stop` routes to correct functions

## Risks

- **Agent Teams API changes** — Experimental feature may change. Mitigation: minimal coupling, fallback to worktrees always available
- **File conflicts between teammates** — Shared filesystem. Mitigation: branch-per-teammate + prompt-based file scoping + plan approval mode
- **Token cost surprise** — Teams mode costs significantly more. Mitigation: document prominently, keep worktrees as default
- **Team lead ignores instructions** — Lead may not follow prompt perfectly. Mitigation: quality gate hooks as safety net, user can intervene directly

# Task: Agent Teams Backend

> spec-ref: .claude/specs/active/002-agent-teams-execution-backend-with-hybrid-monitori/spec.md
> preset: backend

## Objective
Implement the **Agent Teams Backend** module as described in the specification.

## Spec Reference
See: `.claude/specs/active/002-agent-teams-execution-backend-with-hybrid-monitori/spec.md`
Plan: `.claude/specs/active/002-agent-teams-execution-backend-with-hybrid-monitori/plan.md`

## Requirements

- [ ] REQ-1: **Dual backend flag** — Add `--mode teams|worktree` flag to `sdd run` and `start` commands. Default: `worktree`. Configurable default via `EXECUTION_MODE` environment variable.
- [ ] REQ-2: **SDD pipeline agnostic** — The specify/research/plan/gate/tasks pipeline must remain completely unchanged. The "Worktree Mapping" table in plan.md is reused as-is (rows map to teammates in teams mode).
- [ ] REQ-3: **Hybrid monitoring** — In teams mode, launch an interactive Claude session (team lead) in the foreground AND a background orchestrator monitoring dashboard that reads team config and task status.
- [ ] REQ-4: **Graceful fallback** — If `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` env var is not set to `1`, fall back to worktree mode with a clear warning message. Never error out.
- [ ] REQ-5: **File conflict mitigation** — Each teammate is instructed to work on a dedicated `feature/{name}` branch. Task prompts include explicit file ownership boundaries. Plan approval mode is enabled for all teammates.
- [ ] REQ-6: **Quality gate hooks** — Implement `TeammateIdle` hook (prevents idle without task completion) and `TaskCompleted` hook (validates work before marking done). Hooks exit with code 2 + feedback to enforce standards.
- [ ] REQ-7: **Agent specialization via spawn prompts** — Read preset agent `.md` files and inject their content into teammate spawn prompts. Reuse existing `get_preset_agents()` function. Extract shared `build_agent_prompt()` function from `start_single_agent()`.
- [ ] REQ-8: **Team lead prompt generation** — Build a comprehensive natural language prompt for the team lead that includes: SDD artifacts (spec, research, plan), task assignments, file ownership boundaries, delegate mode instruction, and plan approval requirement.
- [ ] REQ-9: **Teams library** — Create `lib/teams.sh` with functions: `detect_teams_available()`, `build_team_lead_prompt()`, `build_teammate_prompt()`, `generate_branch_instructions()`.
- [ ] REQ-10: **Team management commands** — Add `team start`, `team status`, `team stop` subcommands accessible via `orchestrate.sh team <cmd>` and corresponding skills.

## Acceptance Criteria

- [ ] AC-1: Given a completed SDD plan with worktree mapping, when I run `orchestrate.sh sdd run 002 --mode teams`, then the system generates a team lead prompt, launches an interactive Claude session, and starts a monitoring dashboard in the background.
- [ ] AC-2: Given `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` is not set, when I run `sdd run --mode teams`, then the system logs a warning and falls back to worktree mode automatically.
- [ ] AC-3: Given a plan with 3 worktree mapping rows (auth/api/frontend), when teams mode starts, then the team lead prompt instructs spawning 3 teammates with correct preset agent specializations in their spawn prompts.
- [ ] AC-4: Given a running Agent Team, when a teammate goes idle without completing its task, then the `TeammateIdle` hook exits with code 2 and sends feedback to keep working.
- [ ] AC-5: Given an existing SDD spec created before this feature, when I run it with `--mode teams`, then it works without any modifications to the spec, research, or plan files.
- [ ] AC-6: Given no `--mode` flag, when I run `orchestrate.sh sdd run 002`, then the system uses worktree mode (backward compatible default).
- [ ] AC-7: Given the monitoring dashboard is running, when I check it, then it shows teammate names, task status (pending/in_progress/completed), and error count by reading `~/.claude/teams/` and `~/.claude/tasks/` directories.

## Scope

### DO
- [ ] Implement the Agent Teams Backend module
- [ ] Follow the technical approach in plan.md
- [ ] Write tests before implementation
- [ ] Reference research.md for technology decisions

### DON'T DO
- Do NOT implement other modules

- Replacing Git worktrees entirely — worktrees remain the default and are fully preserved
- Nested teams — Agent Teams does not support teammates spawning their own teams
- Automatic retry of failed teammates — manual intervention via team lead
- Session resumption — Agent Teams does not support `/resume` with in-process teammates
- Per-teammate permission modes at spawn time — Agent Teams limitation
- Split-pane tmux integration for the monitoring dashboard (v1 uses simple background process)

### FILES
See plan.md Architecture section for file structure.

## Completion Criteria
- [ ] Agent Teams Backend module implemented
- [ ] Tests passing
- [ ] DONE.md created with spec-ref

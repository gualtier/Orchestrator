# Research: Agent Teams Execution Backend with Hybrid Monitoring

> Spec: 002 | Created: 2026-02-13
> Spec Reference: .claude/specs/active/002-agent-teams-execution-backend-with-hybrid-monitori/spec.md

## Agent Teams API Surface

### How Teams Are Created
Teams are created **conversationally** — there is no `--create-team` CLI flag. You tell Claude to create a team in natural language, and it handles spawning. This means:
- `claude -p` (print/SDK mode) exits after one response — **cannot sustain a team**
- Teams require an **interactive Claude session** (`claude` without `-p`)
- The orchestrator must launch `claude` interactively and provide the team lead prompt as the initial message

### CLI Flags for Teams
| Flag | Purpose | Values |
|------|---------|--------|
| `--teammate-mode` | Display mode for teammates | `auto` (default), `in-process`, `tmux` |
| `--dangerously-skip-permissions` | Propagates to all teammates | boolean |
| `--permission-mode` | Permission mode (propagates) | `default`, `plan`, `acceptEdits`, `dontAsk`, `bypassPermissions` |

### Environment Variables
| Variable | Purpose | Set By |
|----------|---------|--------|
| `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` | Enable feature | User (required) |
| `CLAUDE_CODE_TEAM_NAME` | Team name for teammate | Auto-set by Claude |
| `CLAUDE_CODE_PLAN_MODE_REQUIRED` | Require plan approval | Auto-set by Claude |

### Team Config Structure
- **Location**: `~/.claude/teams/{team-name}/config.json`
- **Contents**: `members` array with each teammate's `name`, `agent_id`, `agent_type`
- **Readable**: Yes, the monitoring dashboard can poll this file

### Task List Structure
- **Location**: `~/.claude/tasks/{team-name}/`
- **States**: pending, in_progress, completed
- **Dependencies**: Tasks can depend on other tasks; blocked until dependencies complete
- **Claiming**: File locking prevents race conditions
- **Note**: Cannot pre-populate from SDD task files — tasks are created by the team lead conversationally

## Hook Mechanics (TeammateIdle & TaskCompleted)

### TeammateIdle Hook
- **Fires**: When a teammate is about to go idle after finishing its turn
- **Matcher**: None (always fires on every occurrence)
- **Input JSON** (via stdin):
  ```json
  {
    "session_id": "abc123",
    "transcript_path": "/path/to/transcript.jsonl",
    "cwd": "/project/dir",
    "permission_mode": "default",
    "hook_event_name": "TeammateIdle",
    "teammate_name": "researcher",
    "team_name": "my-project"
  }
  ```
- **Decision control**: Exit code only (no JSON decision)
  - Exit 0: Allow teammate to go idle
  - Exit 2: Prevent idle, stderr fed back as feedback to teammate
- **No prompt/agent hook support**: Only `type: "command"` works

### TaskCompleted Hook
- **Fires**: When a task is being marked as completed (by any agent via TaskUpdate, or when teammate finishes turn with in-progress tasks)
- **Matcher**: None (always fires)
- **Input JSON** (via stdin):
  ```json
  {
    "session_id": "abc123",
    "transcript_path": "/path/to/transcript.jsonl",
    "cwd": "/project/dir",
    "permission_mode": "default",
    "hook_event_name": "TaskCompleted",
    "task_id": "task-001",
    "task_subject": "Implement user authentication",
    "task_description": "Add login and signup endpoints",
    "teammate_name": "implementer",
    "team_name": "my-project"
  }
  ```
- **Decision control**: Exit code only
  - Exit 0: Allow task completion
  - Exit 2: Block completion, stderr fed back as feedback

### Key Hook Insight
Both hooks get `teammate_name` and `team_name`, which lets us correlate with our SDD task files. The `task_subject` in TaskCompleted can be matched against our generated task names.

## Hybrid Monitoring Feasibility

### Option A: Background Process with Periodic File Reads
- Launch Claude interactively for the team lead
- Run a separate bash monitoring loop that reads `~/.claude/teams/{name}/config.json` and `~/.claude/tasks/{name}/`
- Output to a separate terminal or file
- **Pros**: Simple, no tmux dependency
- **Cons**: User needs two terminals or must check file

### Option B: tmux Split Pane
- Launch Claude in left pane, monitoring dashboard in right pane
- `tmux split-window -h` for side-by-side
- **Pros**: Both visible simultaneously, best UX
- **Cons**: Requires tmux, which Agent Teams already uses for split-pane mode

### Option C: Background + Notification
- Run monitoring in background, use system notifications (terminal bell, osascript on macOS) when events occur
- **Pros**: Non-intrusive
- **Cons**: Easy to miss

**Decision**: Use **Option B (tmux)** as primary, with **Option A** as fallback when tmux is unavailable. This aligns with Agent Teams' own tmux usage for split-pane mode.

## Existing Patterns in Codebase

### Reusable Functions
| Function | File | Purpose | Reuse For |
|----------|------|---------|-----------|
| `get_preset_agents()` | `lib/core.sh:143` | Map preset to agent names | Building teammate spawn prompts |
| `start_single_agent()` | `commands/start.sh:115` | Build agent prompt + launch | Extract `build_agent_prompt()` |
| `parse_worktree_mapping()` | `lib/sdd.sh:261` | Parse plan.md worktree table | Map rows to teammates |
| `generate_tasks_from_plan()` | `lib/sdd.sh:307` | Generate task .md files | Same tasks, different backend |
| `cmd_sdd_run()` | `commands/sdd.sh:576` | Autopilot pipeline | Add `--mode` dispatch |
| `check_and_notify_errors()` | `lib/error_detection.sh` | Error notifications | Adapt for teams monitoring |
| `cmd_status_enhanced()` | `commands/status.sh` | Status dashboard | Model for teams dashboard |
| `detect_teams_available()` | NEW | Check if Agent Teams available | Fallback logic |

### Prompt Construction Pattern (lines 179-234 of start.sh)
The existing prompt builder follows this structure:
1. Base instructions (CLAUDE.md or AGENT_CLAUDE_BASE.md)
2. Specialized agent content (from .md files)
3. Project context (PROJECT_MEMORY.md head)
4. SDD context (spec, research, plan — head 80 lines each)
5. Task content
6. Mandatory completion steps

For teams mode, the same structure applies but:
- No DONE.md requirement (native task completion replaces it)
- Paths reference project root (not worktree path)
- Branch instructions added instead

### Conventions to Follow
- All commands go in `commands/` directory
- All library functions go in `lib/` directory
- Use `log_header`, `log_step`, `log_info`, `log_success`, `log_warn`, `log_error` for output
- Use `ensure_dir`, `file_exists`, `dir_exists` for filesystem checks
- Source new libs in `orchestrate.sh`
- Exit traps for cleanup

## Constraints & Limitations

### Agent Teams Limitations (from docs)
1. **No session resumption** with in-process teammates
2. **Task status can lag** — teammates sometimes fail to mark tasks completed
3. **Shutdown can be slow** — teammates finish current turn before stopping
4. **One team per session** — only one team at a time per lead
5. **No nested teams** — teammates cannot create sub-teams
6. **Lead is fixed** — cannot promote teammates
7. **Permissions set at spawn** — all teammates start with lead's mode
8. **Split panes require tmux/iTerm2** — in-process mode as fallback

### Integration Constraints
1. **Cannot programmatically create teams** — must be conversational via interactive session
2. **Cannot pre-populate native task list** — tasks are created by the team lead
3. **Token cost** — each teammate is a full Claude instance (significantly more than worktrees with `claude -p`)
4. **File conflicts** — no filesystem isolation (mitigated by branch-per-teammate + prompt scoping)

## Performance Considerations

### Token Usage Comparison
| Aspect | Worktree Mode | Teams Mode |
|--------|--------------|------------|
| Context per agent | Single prompt via `claude -p` | Full Claude instance with ongoing context |
| Communication | File-based (zero token cost) | Native messaging (tokens per message) |
| Monitoring | Bash polling (zero tokens) | Team lead coordination (tokens) |
| Total cost | Lower | Significantly higher |

### Startup Time
| Phase | Worktree Mode | Teams Mode |
|-------|--------------|------------|
| Setup | Git worktree creation (~5s/agent) | Instant (no worktrees) |
| Agent launch | `claude -p` per agent (~2s/agent) | Team lead spawns teammates (~3s/teammate) |
| Total for 3 agents | ~21s | ~9s |

Teams mode has faster startup but higher ongoing cost.

## Security Implications

- **Permission propagation**: All teammates inherit lead's permissions. If lead uses `--dangerously-skip-permissions`, all teammates do too.
- **File access**: Teammates can access any file in the project (no worktree isolation). Mitigated by prompt-based file ownership boundaries.
- **Shared filesystem risk**: Two teammates could overwrite each other's work. Mitigated by branch-per-teammate strategy.

## Recommendations

1. **Teams are launched interactively** — the orchestrator generates a comprehensive lead prompt and launches `claude` (not `claude -p`). The lead handles all Agent Teams mechanics.

2. **Monitoring via tmux split** — launch the monitoring dashboard in a tmux split pane alongside the team lead session. Fall back to background process when tmux unavailable.

3. **Reuse existing prompt builder** — extract `build_agent_prompt()` from `start_single_agent()` as a shared function. Both backends use it.

4. **File conflict mitigation is prompt-based** — we rely on clear instructions in teammate prompts (file ownership + branch-per-teammate). This is the same approach Agent Teams docs recommend.

5. **TeammateIdle hook validates commits** — check if the teammate made any commits on their branch before allowing idle. Simple and effective.

6. **TaskCompleted hook validates scope** — check if the teammate modified files outside its designated scope. Requires knowing the file scope per task.

7. **Worktree mapping table reused as-is** — no changes to plan.md template. In teams mode, rows map to teammates instead of worktrees.

## Sources

- [Claude Code Agent Teams Documentation](https://code.claude.com/docs/en/agent-teams)
- [Claude Code Hooks Reference](https://code.claude.com/docs/en/hooks)
- [Claude Code Settings Reference](https://code.claude.com/docs/en/settings)
- [Claude Code CLI Reference](https://code.claude.com/docs/en/cli-reference)

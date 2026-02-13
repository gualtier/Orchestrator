# Task: Error Detection Engine + Dashboard

> spec-ref: .claude/specs/active/001-o-orquestrador-deve-monitorar-erros-dos-agentes-de/spec.md
> preset: backend

## Objective
Implement the **Error Detection Engine + Dashboard** module as described in the specification.

## Spec Reference
See: `.claude/specs/active/001-o-orquestrador-deve-monitorar-erros-dos-agentes-de/spec.md`
Plan: `.claude/specs/active/001-o-orquestrador-deve-monitorar-erros-dos-agentes-de/plan.md`

## Requirements

- [ ] REQ-1: **Error Detection via Log Polling** - Poll agent log files at configurable intervals (default: 5s) and detect new error patterns since last check using file offset tracking
- [ ] REQ-2: **Error Pattern Matching** - Match common error patterns in log content:
  - Test failures: `FAIL`, `FAILED`, `✗`, `Error:`, `AssertionError`
  - Compilation errors: `error TS`, `SyntaxError`, `Cannot find module`
  - Runtime errors: `TypeError`, `ReferenceError`, `Traceback`, `panic:`
  - Git errors: `CONFLICT`, `fatal:`, `error: failed to push`
  - Permission errors: `EACCES`, `Permission denied`
  - Agent-specific: `BLOCKED`, `Cannot proceed`, `Stuck`
- [ ] REQ-3: **Error Severity Classification** - Classify each detected error:
  - **CRITICAL**: Process crash, unrecoverable errors, test suite complete failure
  - **WARNING**: Individual test failures, non-fatal compilation warnings, retryable errors
  - **INFO**: Deprecation notices, minor warnings, informational messages
- [ ] REQ-4: **Error Context Extraction** - For each error, extract and report:
  - Agent name and worktree
  - Timestamp of occurrence
  - Error message (up to 5 lines of context)
  - File/line if available in the error
  - Error count (how many times this error appeared)
- [ ] REQ-5: **Corrective Action Suggestions** - Suggest actions based on error type:
  - Test failure → "Review test output, consider restarting agent"
  - Compilation error → "Check syntax in [file], agent may self-correct"
  - Process crash → "Restart agent with: orchestrate.sh start <name>"
  - Git conflict → "Resolve conflict manually, then restart"
  - Stalled agent → "Agent may be stuck, consider restart"
- [ ] REQ-6: **Consolidated Error Dashboard** - New command `orchestrate.sh errors` that shows:
  - Summary: total errors by severity across all agents
  - Per-agent error breakdown
  - Most recent errors (last 10)
  - Option for `--watch` mode (auto-refresh)
- [ ] REQ-7: **Real-time Notifications during Wait** - Integrate error detection into the existing `orchestrate.sh wait` command so errors are displayed as they occur during the polling loop
- [ ] REQ-8: **Error Log File** - Write detected errors to `.claude/orchestration/errors.log` as structured data (timestamp | agent | severity | message) for post-mortem analysis
- [ ] REQ-9: **Error State File per Agent** - Write `.claude/orchestration/pids/<name>.errors` with current error count and last error, consumable by `status` command

## Acceptance Criteria

- [ ] AC-1: Given 3 running agents where one has a test failure in its log, when the error monitor polls, then it detects the error within 10 seconds and displays a notification with agent name, severity (WARNING), and the failing test message
- [ ] AC-2: Given `orchestrate.sh errors` is run, then it displays a formatted dashboard with all errors grouped by agent and sorted by severity
- [ ] AC-3: Given `orchestrate.sh wait` is running, when an agent encounters a critical error, then the error is displayed inline without interrupting the wait loop
- [ ] AC-4: Given an agent process crashes, when the error monitor detects it, then it suggests "Restart agent with: orchestrate.sh start <name>"
- [ ] AC-5: Given errors are detected, then they are persisted to `.claude/orchestration/errors.log` with structured format
- [ ] AC-6: Given `orchestrate.sh status` is run, then it shows error count per agent alongside existing status info

## Scope

### DO
- [ ] Implement the Error Detection Engine + Dashboard module
- [ ] Follow the technical approach in plan.md
- [ ] Write tests before implementation
- [ ] Reference research.md for technology decisions

### DON'T DO
- Do NOT implement other modules

- Automatic retry/restart of agents (only suggest, don't execute)
- Email/Slack/webhook notifications (terminal only)
- Historical error analytics or trends across sessions
- Modification of agent behavior based on errors
- AI-powered error analysis or root cause detection

### FILES
See plan.md Architecture section for file structure.

## Completion Criteria
- [ ] Error Detection Engine + Dashboard module implemented
- [ ] Tests passing
- [ ] DONE.md created with spec-ref

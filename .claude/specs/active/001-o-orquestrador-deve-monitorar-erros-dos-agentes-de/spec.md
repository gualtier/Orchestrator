# Spec: Active Error Monitoring for Orchestrator Agents

> Spec: 001 | Created: 2026-02-11 | Status: DRAFT

## Problem Statement

O orquestrador atualmente captura logs dos agentes em `.claude/orchestration/logs/*.log` mas **nunca analisa o conteúdo** desses logs. O usuário só descobre erros quando:
- Verifica manualmente os logs (`orchestrate.sh logs <agent>`)
- O agente para inesperadamente (status muda para `stopped`)
- O agente cria um BLOCKED.md (raramente acontece)

Isso causa:
1. **Tempo desperdiçado** - agentes rodam por minutos/horas com erros sem o usuário saber
2. **Cascata de erros** - um erro inicial causa dezenas de erros derivados
3. **Falta de visibilidade** - com 3-4 agentes rodando, é impossível monitorar todos manualmente

## User Stories

- As an **orchestrator user**, I want to be **notified automatically when an agent encounters an error** so that I can intervene quickly before the agent wastes time
- As an **orchestrator user**, I want to see a **consolidated error dashboard** across all running agents so that I can understand the health of the entire operation at a glance
- As an **orchestrator user**, I want errors **classified by severity** (critical/warning/info) so that I can prioritize which errors to address first
- As an **orchestrator user**, I want **suggested corrective actions** for each error so that I know what to do without having to investigate myself
- As an **orchestrator user**, I want the error monitor to work as a **background watcher** during `orchestrate.sh wait` so that errors are reported in real-time without extra commands

## Functional Requirements

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

## Non-Functional Requirements

- [ ] Performance: Log polling must not add more than 100ms overhead per agent per cycle
- [ ] Performance: Must handle log files up to 50MB without memory issues (use tail/offset, not full read)
- [ ] Reliability: Error monitor must not crash or interfere with agent execution
- [ ] Compatibility: Must work on macOS (darwin) and Linux with standard bash 3.2+

## Acceptance Criteria

- [ ] AC-1: Given 3 running agents where one has a test failure in its log, when the error monitor polls, then it detects the error within 10 seconds and displays a notification with agent name, severity (WARNING), and the failing test message
- [ ] AC-2: Given `orchestrate.sh errors` is run, then it displays a formatted dashboard with all errors grouped by agent and sorted by severity
- [ ] AC-3: Given `orchestrate.sh wait` is running, when an agent encounters a critical error, then the error is displayed inline without interrupting the wait loop
- [ ] AC-4: Given an agent process crashes, when the error monitor detects it, then it suggests "Restart agent with: orchestrate.sh start <name>"
- [ ] AC-5: Given errors are detected, then they are persisted to `.claude/orchestration/errors.log` with structured format
- [ ] AC-6: Given `orchestrate.sh status` is run, then it shows error count per agent alongside existing status info

## Out of Scope

- Automatic retry/restart of agents (only suggest, don't execute)
- Email/Slack/webhook notifications (terminal only)
- Historical error analytics or trends across sessions
- Modification of agent behavior based on errors
- AI-powered error analysis or root cause detection

## Open Questions

- [RESOLVED] Polling interval: 5 seconds default, configurable via ORCH_ERROR_POLL_INTERVAL
- [RESOLVED] Max context lines per error: 5 lines before/after the error line

## Dependencies

- Existing log capture in `process.sh` (stdout+stderr → `.claude/orchestration/logs/*.log`)
- Existing status infrastructure in `status.sh` and `monitoring.sh`
- Existing wait loop in `start.sh`

# Plan: Active Error Monitoring for Orchestrator Agents

> Spec: 001 | Created: 2026-02-11
> Spec Reference: .claude/specs/active/001-o-orquestrador-deve-monitorar-erros-dos-agentes-de/spec.md
> Research Reference: .claude/specs/active/001-o-orquestrador-deve-monitorar-erros-dos-agentes-de/research.md

## Technical Approach

**Incremental byte-offset polling** com `tail -c +offset | grep -E patterns`:

1. A cada ciclo de poll (5s default), verifica o tamanho do log via `stat`
2. Se cresceu, lê apenas os bytes novos com `tail -c +offset`
3. Aplica `grep -E` com padrões classificados por severidade (CRITICAL/WARNING/INFO)
4. Grava resultados no cache por agente e no error log global
5. Exibe notificação inline durante wait/watch

Zero dependências externas. Bash 3.2+ puro. ~5-25ms overhead por agente por ciclo.

Rationale: Research mostrou que `grep -E` com alternation é o método mais rápido para OR matching. `tail -c +offset` permite leitura incremental sem carregar o arquivo inteiro. `stat` para check de tamanho custa ~0.5ms.

## Technology Decisions

- **Pattern matching**: `grep -E` alternation — fastest for OR matching, macOS native (ref: Library Analysis)
- **Incremental read**: `tail -c +offset` — reads only new bytes, handles 50MB+ (ref: Performance Considerations)
- **File size check**: `stat` with platform detection — ~0.5ms, reuses existing `stat_mtime` pattern (ref: Existing Patterns)
- **Error storage format**: Pipe-delimited text — human+machine readable, no jq needed (ref: Constraints)
- **Integration model**: Hook into existing poll loops — no daemon, no background process (ref: Recommendations)
- **Severity classification**: 3-tier grep (CRITICAL/WARNING/INFO) — balanced precision vs false positives (ref: Error Pattern Classification)

## Worktree Mapping

| Module | Worktree Name | Preset | Agents |
|--------|--------------|--------|--------|
| Error Detection Engine + Dashboard | error-monitor | backend | backend-developer, test-automator |

Single worktree: all changes are in `.claude/scripts/` (bash only), same codebase area.

## Architecture

```
┌─────────────────────────────────────────────┐
│           lib/error_detection.sh            │
│  (core engine - detect, classify, cache)    │
├─────────────────────────────────────────────┤
│  init_error_tracking(name)                  │
│  check_agent_errors(name)                   │
│  check_all_agents_errors()                  │
│  classify_error_severity(line)              │
│  get_error_count(name) / get_last_error()   │
│  suggest_action(severity, pattern)          │
│  show_error_notification(name,sev,msg)      │
└──────────┬──────────────────┬───────────────┘
           │                  │
    ┌──────▼──────┐   ┌──────▼──────────────┐
    │ commands/   │   │ Integration points  │
    │ errors.sh   │   │                     │
    │ (dashboard) │   │ • status.sh: counts │
    │ cmd_errors()│   │ • start.sh: init    │
    │ --watch     │   │ • core.sh: config   │
    └─────────────┘   └─────────────────────┘
```

### Files

**NEW:**

- `lib/error_detection.sh` — Core engine (REQ-1 to REQ-5, REQ-8, REQ-9)
- `commands/errors.sh` — Dashboard command (REQ-6)

**MODIFY:**

- `lib/core.sh` — Config variables (ERROR_LOG_FILE, ERROR_POLL_INTERVAL, etc.)
- `commands/start.sh` — Call `init_error_tracking()` on agent start
- `commands/status.sh` — Error counts in display + error check in wait loop (REQ-7)
- `orchestrate.sh` — Register `errors` command + source new lib

### Error Pattern Tiers

- **CRITICAL**: `panic:|FATAL|Segmentation fault|OOMKilled|ENOSPC|core dumped`
- **WARNING**: `FAIL |FAILED|Error:|error TS|TypeError|SyntaxError|CONFLICT|Permission denied`
- **INFO**: `DeprecationWarning|deprecated|WARN |WARNING`

### Storage

- Offset per agent: `.claude/orchestration/pids/<name>.offset`
- Error state per agent: `.claude/orchestration/pids/<name>.errors`
- Global error log: `.claude/orchestration/errors.log` (format: `timestamp|severity|agent|message|context`)

## Constitutional Gates

- [x] Research-First: All decisions backed by Library Analysis + Performance benchmarks
- [x] Simplicity: 2 modules (engine + dashboard), 1 worktree, max 6 files touched
- [x] Test-First: Test strategy defined below with 5 test scenarios
- [x] Integration-First: Real agent test with deliberate errors planned
- [x] Spec Traceability: Every function maps to REQ- items

## Implementation Order

1. **Phase 1** (single worktree, sequential):
   1. `lib/error_detection.sh` — core functions
   2. `commands/errors.sh` — dashboard
   3. `lib/core.sh` — config variables
   4. `orchestrate.sh` — command router
   5. `commands/start.sh` — init tracking
   6. `commands/status.sh` — display + wait integration

## Test Strategy

1. **Fake log test**: Create log with known errors, run `check_agent_errors()`, verify detection + classification
2. **Dashboard test**: Populate `errors.log` with samples, verify `orchestrate.sh errors` output
3. **Wait loop test**: Run `orchestrate.sh wait` with error-producing agent, verify inline notifications
4. **Edge cases**: Empty logs, log rotation (file shrinks), no errors, large files
5. **Integration**: Start real agent with deliberate task error, verify end-to-end detection

## Risks

- False positives from code-about-errors → Exclusion patterns (grep, +trace, error_handling)
- `stat` portability → Platform detection reusing existing `stat_mtime` pattern from monitoring.sh
- Performance on large logs → Byte-offset ensures only new content is read
- Monitor crash → All detection is read-only, wrapped in `|| true` guards

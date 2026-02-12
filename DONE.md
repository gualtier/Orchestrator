# ✅ Completed: Error Detection Engine + Dashboard

> spec-ref: .claude/specs/active/001-o-orquestrador-deve-monitorar-erros-dos-agentes-de/spec.md

## Summary

Implemented a comprehensive error monitoring system for the Claude orchestrator that:

1. **Actively monitors agent logs** using incremental byte-offset polling (5s default interval)
2. **Detects errors by pattern matching** with 3-tier severity classification (CRITICAL/WARNING/INFO)
3. **Provides a consolidated dashboard** via `orchestrate.sh errors` command
4. **Integrates with status/wait commands** to show real-time error notifications
5. **Persists errors to log file** for post-mortem analysis
6. **Suggests corrective actions** based on error type

### Key Features

- **Zero external dependencies** - Pure bash 3.2+ compatible
- **Efficient polling** - Uses `tail -c +offset` to read only new bytes (~5-25ms per agent)
- **Pattern-based classification**:
  - CRITICAL: `panic:`, `FATAL`, `Segmentation fault`, `OOMKilled`, etc.
  - WARNING: `FAIL`, `Error:`, `TypeError`, `CONFLICT`, etc.
  - INFO: `DeprecationWarning`, `WARN`, etc.
- **Watch mode** - Auto-refresh dashboard with configurable interval
- **Filter by agent** - View errors for specific agents only

## Modified Files

### Created
- `.claude/scripts/lib/error_detection.sh` - Core error detection engine (540+ lines)
  - Log polling with byte-offset tracking
  - Error pattern matching and classification
  - Error context extraction (file/line info)
  - Corrective action suggestions
  - Error log management

- `.claude/scripts/commands/errors.sh` - Dashboard command (330+ lines)
  - Summary view with severity breakdown
  - Per-agent error breakdown
  - Recent errors list
  - Watch mode with auto-refresh
  - Error clearing functionality

### Modified
- `.claude/scripts/lib/core.sh` - Added config variables:
  - `ERROR_POLL_INTERVAL` (default: 5s)
  - `ERROR_LOG_FILE`
  - `ERROR_CACHE_DIR`

- `.claude/scripts/commands/start.sh` - Calls `init_error_tracking()` on agent start

- `.claude/scripts/commands/status.sh` - Shows error counts per agent and integrates error notifications during wait/watch

- `.claude/scripts/orchestrate.sh` - Registers `errors` command and sources `error_detection.sh`

## How to Test

### 1. View Error Dashboard
```bash
.claude/scripts/orchestrate.sh errors
```

### 2. Watch Mode (auto-refresh)
```bash
.claude/scripts/orchestrate.sh errors --watch
.claude/scripts/orchestrate.sh errors --watch 10  # 10s interval
```

### 3. Filter by Agent
```bash
.claude/scripts/orchestrate.sh errors --agent api
```

### 4. View Recent Errors
```bash
.claude/scripts/orchestrate.sh errors --recent
```

### 5. Clear Error Tracking
```bash
.claude/scripts/orchestrate.sh errors --clear
```

### 6. Check Status with Errors
```bash
.claude/scripts/orchestrate.sh status
.claude/scripts/orchestrate.sh status --enhanced
```

### 7. Test Error Detection
```bash
# Create test log with errors
mkdir -p .claude/orchestration/logs
echo "Error: Test error
FAIL test_something
TypeError: undefined" > .claude/orchestration/logs/test-agent.log

# Create test task
mkdir -p .claude/orchestration/tasks
echo "test" > .claude/orchestration/tasks/test-agent.md

# View errors
.claude/scripts/orchestrate.sh errors
```

## Requirements Coverage

| Requirement | Status | Implementation |
|-------------|--------|----------------|
| REQ-1: Log Polling | ✅ | `check_agent_errors()` with byte-offset tracking |
| REQ-2: Pattern Matching | ✅ | `classify_error_severity()` with regex patterns |
| REQ-3: Severity Classification | ✅ | CRITICAL/WARNING/INFO tiers |
| REQ-4: Context Extraction | ✅ | `extract_error_location()` for file:line |
| REQ-5: Corrective Actions | ✅ | `suggest_corrective_action()` |
| REQ-6: Dashboard | ✅ | `cmd_errors_dashboard()` |
| REQ-7: Wait Integration | ✅ | `check_and_notify_errors()` in wait/watch |
| REQ-8: Error Log File | ✅ | `errors.log` with pipe-delimited format |
| REQ-9: Error State File | ✅ | `<name>.errors` per agent |

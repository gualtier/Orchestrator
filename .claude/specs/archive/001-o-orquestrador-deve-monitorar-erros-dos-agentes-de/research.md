# Research: Active Error Monitoring for Orchestrator Agents

> Spec: 001 | Created: 2026-02-11
> Spec Reference: .claude/specs/active/001-o-orquestrador-deve-monitorar-erros-dos-agentes-de/spec.md

## Library/Tool Analysis

| Tool/Approach | Pros | Cons | Decision |
|---------------|------|------|----------|
| `grep -E` (alternation) | Fastest for OR matching, macOS native, no deps | Single-pass only | **USE** - primary pattern matcher |
| `grep -F` (fixed strings) | Faster than regex for literals | No regex support | **USE** - for simple patterns |
| `awk` | Field extraction, complex logic | 3-4x slower than grep | **SKIP** - overkill for detection |
| `tail -c +offset` | Efficient incremental reads, macOS native | Need offset tracking | **USE** - core of polling system |
| `fswatch` (macOS FSEvents) | Event-based, zero CPU when idle | External dependency (brew) | **SKIP** - polling is sufficient, avoids dependency |
| `inotifywait` | Event-based on Linux | Not available on macOS | **SKIP** - not cross-platform |
| `stat -f%z` (macOS) | Get file size without reading | macOS-specific syntax | **USE** - with platform detection |

**Decision**: Pure bash with `grep -E` + `tail -c +offset` + `stat`. Zero external dependencies. Works on bash 3.2+ (macOS default).

## Performance Considerations

### Log Polling Overhead

- **`stat` call**: ~0.5ms per file (just reads inode metadata)
- **`tail -c +N | grep -E`**: ~2-5ms for 100 new lines, ~15-20ms for 1000 lines
- **Total per agent per cycle**: ~5-25ms (well under 100ms requirement)
- **4 agents @ 5s interval**: ~0.1-0.5% CPU (negligible)

### Memory Usage

- **Offset tracking**: 1 file per agent (~10 bytes each)
- **Error cache**: 1-2 files per agent (~500 bytes each)
- **No in-memory buffering**: All processing is stream-based via pipes
- **Large log handling**: `tail -c +offset` reads from offset, never loads full file

### Bottleneck Analysis

- **NOT a bottleneck**: Log scanning (grep is extremely fast)
- **NOT a bottleneck**: File I/O (only reading new bytes since last check)
- **Potential bottleneck**: Too many error patterns → mitigated by single `grep -E` call
- **Potential bottleneck**: Log rotation during read → mitigated by size comparison

## Security Implications

- **Low risk**: Read-only access to log files (no writes to agent worktrees)
- **No network access**: All monitoring is local filesystem
- **No credential exposure**: Error messages may contain paths but not secrets
- **Log injection**: Agent could theoretically write fake "errors" to manipulate the monitor → acceptable risk since agents are trusted processes
- **File permissions**: Error cache files in `.claude/orchestration/` follow existing permission model

## Existing Patterns in Codebase

### Offset Tracking Pattern (NEW - follows existing metadata pattern)

Existing: `.claude/orchestration/pids/<name>.pid`, `<name>.started`
New: `.claude/orchestration/pids/<name>.offset`, `<name>.errors`

### Grep Pattern Matching (from learning.sh)

```bash
# Existing pattern in learning.sh:29-48
local problems=$(grep -i -E "(problem|issue|challenge|blocker|error|failed)" "$done_file" | head -3)
```

Reuse this exact pattern: `grep -i -E "pattern1|pattern2" | head -N`

### Cache System (from monitoring.sh)

```bash
# Existing cache pattern in monitoring.sh:290-308
ACTIVITY_CACHE_DIR="/tmp/orch-monitor-cache"
ACTIVITY_CACHE_TTL=10
```

Follow same pattern for error cache with persistent location (not /tmp).

### Progress Counting (from monitoring.sh)

```bash
# Existing count pattern in monitoring.sh:214-257
local done_items=$(grep -c "\- \[x\]" "$progress_file" 2>/dev/null || echo 0)
```

Reuse `grep -c` with `2>/dev/null || echo 0` fallback for error counting.

### Display Integration (from status.sh)

- Enhanced mode uses `╔═══║╚═══` box drawing
- Color indicators: `●` green=ok, yellow=warning, red=error
- Compact mode uses emoji indicators on single lines
- `printf` for aligned column output

### Event Logging (from start.sh)

```bash
# Existing event pattern:
echo "[$(timestamp)] STARTING: $name [agents: $agents]" >> "$EVENTS_FILE"
```

Follow same format: `[timestamp] ERROR_DETECTED: $name [$severity] $message`

### Function Naming Convention

- `get_*()` for getters: `get_log_file`, `get_agent_status`, `get_elapsed_seconds`
- `is_*()` for boolean checks: `is_process_running`
- `show_*()` for display: `show_agent_logs`
- `cmd_*()` for commands: `cmd_status`, `cmd_wait`

### Config Variable Convention

- `ALL_CAPS` with descriptive names
- Defined in `init_config()` in core.sh
- Exported for subshells
- Relative to `$PROJECT_ROOT`

## Constraints & Limitations

- **Bash 3.2+**: macOS ships with bash 3.2, no associative arrays (use files instead)
- **No jq dependency**: Can't assume jq is installed for JSON parsing
- **`stat` portability**: macOS uses `stat -f%z`, Linux uses `stat -c%s` → need platform detection (existing `stat_mtime` in monitoring.sh already handles this)
- **No background daemon**: Must integrate into existing polling loops (wait/watch), not a separate process
- **Log format varies**: Claude CLI output is unstructured text, error patterns must be broad but precise enough to avoid false positives

## Error Pattern Classification

### CRITICAL Patterns (process likely dead or unrecoverable)

```
panic:|PANIC:|fatal:|FATAL|Segmentation fault|core dumped
killed|OOMKilled|Cannot allocate memory
ENOSPC|No space left on device
```

### WARNING Patterns (errors that may self-correct or need attention)

```
FAIL |FAILED|Error:|error:|ERROR
TypeError|ReferenceError|SyntaxError
AssertionError|AssertError|expect\(
Cannot find module|Module not found
CONFLICT|merge conflict
Permission denied|EACCES
```

### INFO Patterns (informational, usually not actionable)

```
DeprecationWarning|deprecated
WARN |WARNING|warn:
```

### False Positive Mitigation

Lines to EXCLUDE from error detection:
- Lines containing `grep` (our own error scanning)
- Lines starting with `+` (bash debug trace)
- Lines containing `error_` or `Error handling` (code about errors, not actual errors)
- Lines inside markdown code blocks

## Recommendations

### Architecture

1. **New file**: `lib/error_detection.sh` — core detection functions
2. **New command**: `commands/errors.sh` — dashboard command
3. **Modify**: `commands/status.sh` — integrate error counts into display and wait loop
4. **Modify**: `lib/core.sh` — add config variables
5. **Modify**: `commands/start.sh` — initialize error tracking on agent start

### Approach: Incremental Byte-Offset Polling

```
Poll cycle:
1. stat log file → get current size
2. Compare with stored offset
3. If size > offset → tail -c +offset | grep -E patterns
4. Classify matches by severity
5. Write to error cache + error log
6. Display notification if new errors found
7. Update offset
```

### Error Log Format (pipe-delimited, human+machine readable)

```
2026-02-11T14:30:00Z|WARNING|auth|TypeError: Cannot read property 'id'|src/auth.ts:42
2026-02-11T14:30:05Z|CRITICAL|api|FATAL: process crashed|exit_code=1
```

### Integration Points

- **Wait loop** (`cmd_status_watch`): Call `check_all_agents_errors()` each cycle before sleep
- **Enhanced status**: Add error count line after git activity section
- **Compact status**: Add error emoji (red dot if errors)
- **Agent start**: Initialize offset file to current log size

## Sources

- [grep -E vs awk performance](https://www.baeldung.com/linux/grep-sed-awk-differences)
- [tail -c offset technique](https://ss64.com/mac/tail.html)
- [ANSI escape codes for terminal notifications](https://gist.github.com/fnky/458719343aabd01cfb17a3a4f7296797)
- [Structured logging best practices](https://betterstack.com/community/guides/logging/structured-logging/)
- [fswatch macOS file monitoring](https://github.com/emcrisostomo/fswatch)
- [Bash background process management](https://www.dotlinux.net/blog/bash-background-process-management/)

# Completed: Ralph Loop Engine + CLI Integration

## Summary

Implemented the Ralph loop engine for the orchestrator, enabling agents to run in iterative self-correcting loops with backpressure gates. The implementation follows the spec and plan exactly: 1 new file (`lib/ralph.sh`) plus small modifications to 4 existing files. Zero new dependencies. Full backward compatibility — without `--ralph` flag, behavior is identical to v3.9.4.

### What was done:

1. **`lib/ralph.sh`** (~350 lines) — Core loop engine with:
   - `ralph_loop()` — main while-loop wrapping `start_agent_process()` with iteration tracking
   - `check_completion_signal()` — scans last 100 lines of agent log for configurable signal
   - `run_gates()` — executes backpressure gate commands sequentially with pass/fail tracking
   - `check_convergence()` — detects stalled agents via git diff (configurable threshold)
   - `write_iteration_context()` — builds feedback prompt for iterations 2+ with gate results and diff stats
   - `parse_ralph_config()` — reads ralph frontmatter from task files (ralph, max-iterations, stall-threshold, gates, completion-signal)
   - `cmd_cancel_ralph()` — gracefully stops running loops (single or all)
   - State query functions for monitoring integration

2. **`commands/start.sh`** — Added `--ralph` and `--max-iterations` flag parsing to `cmd_start()`. `start_single_agent()` detects ralph config and calls `ralph_loop()` for ralph-enabled agents.

3. **`commands/status.sh`** — Status dashboard shows iteration count (`iter 3/20`), gate results (`gates: 2/3`), and convergence indicator (`converging`/`stalled`) for ralph agents in all display modes (standard, enhanced, JSON).

4. **`commands/sdd.sh`** — `cmd_sdd_run()` accepts `--ralph` and `--max-iterations` flags, passes them through to `cmd_start()`. Updated help text.

5. **`orchestrate.sh`** — Sources `lib/ralph.sh` and routes `cancel-ralph` command.

6. **Task template** — Updated with ralph frontmatter fields (ralph, max-iterations, stall-threshold, gates, completion-signal).

## Modified Files

- `.claude/scripts/lib/ralph.sh` (NEW)
- `.claude/scripts/commands/start.sh`
- `.claude/scripts/commands/status.sh`
- `.claude/scripts/commands/sdd.sh`
- `.claude/scripts/orchestrate.sh`
- `.claude/specs/templates/task.md`
- `PROGRESS.md`

## How to Test

### Quick syntax check
```bash
bash -n .claude/scripts/orchestrate.sh
bash -n .claude/scripts/lib/ralph.sh
```

### Backward compatibility (zero regression)
```bash
# Should work exactly as before — no ralph mode active
.claude/scripts/orchestrate.sh help
.claude/scripts/orchestrate.sh status
.claude/scripts/orchestrate.sh cancel-ralph  # "No ralph loops are running"
```

### Ralph mode smoke test
```bash
# Create a task with ralph frontmatter:
# > ralph: true
# > max-iterations: 3
# > gates: test -f DONE.md

# Start with global ralph:
.claude/scripts/orchestrate.sh start --ralph --max-iterations 5

# Start with SDD:
.claude/scripts/orchestrate.sh sdd run 004 --ralph

# Cancel running loops:
.claude/scripts/orchestrate.sh cancel-ralph [agent-name]
```

### Frontmatter parsing test
```bash
# Run the inline test in the commit message or verify:
source .claude/scripts/lib/logging.sh
source .claude/scripts/lib/ralph.sh
parse_ralph_config /path/to/task.md false
echo "RALPH_ENABLED=$RALPH_ENABLED"
```

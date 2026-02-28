# Orchestrator Backlog

> Improvements identified during spec 011 execution cycle.
> Created: 2026-02-13 | **All items COMPLETED: 2026-02-13**

---

## High Priority

### ~~#3 Truncated context (head -80)~~ DONE
- **Fix**: Replaced `head -80` with `cat` in `start.sh` for spec, research, and plan injection.

### ~~#4 Project rules are not injected into prompt~~ DONE
- **Fix**: Added `project_rules` extraction from main CLAUDE.md — injected as "Project Rules (from main CLAUDE.md — MUST follow)" section in agent prompt.

### ~~#1 Agent log is empty~~ DONE
- **Fix**: Added `--output-format stream-json` to claude invocation in `process.sh`. Also confirmed `unset CLAUDECODE` (Bug 1 fix) is in place.

---

## Medium Priority

### ~~#5 /sdd-run is not really autopilot~~ VERIFIED
- **Result**: The `cmd_sdd_run()` code already chains gate → tasks → setup → start → monitor correctly. The original issue was caused by Bug 1 (CLAUDECODE env var killing agents), not a missing chain. With Bug 1 fixed, autopilot works end-to-end.

### ~~#7 Merge should have pre-flight check~~ DONE
- **Fix**: Added `--dry-run` flag to `merge.sh` — shows branch status, DONE.md presence, uncommitted changes, and conflict simulation for each worktree without executing.

### ~~#9 Agent timeout/watchdog missing~~ DONE
- **Fix**: Added `--timeout N` flag to `cmd_start` — after N minutes, the monitoring loop kills all running agents and logs TIMEOUT events.

---

## Low Priority

### ~~#6 No "direct" mode for single-worktree specs~~ DONE
- **Fix**: Added `--direct` flag to `sdd run` — creates a feature branch without a worktree and runs the agent directly. Also added auto-detection hint for single-module specs.

### ~~#8 Cleanup should be part of merge~~ DONE
- **Fix**: Added `--cleanup` flag to `merge` — after successful merge (0 failures), automatically runs `cmd_cleanup` with FORCE=true.

### ~~#10 No automatic retry~~ DONE
- **Fix**: Refactored `start_agent_process` with retry loop (3 attempts, 5s/10s/20s backoff). On final failure, creates BLOCKED.md with error context.

### ~~#2 PROGRESS.md does not reflect real progress~~ DONE
- **Fix**: Updated agent prompt to explicitly require creating ALL steps as checkboxes upfront, and updating after EACH completed step.

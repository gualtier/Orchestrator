# Orchestrator Backlog

> Improvements identified during spec 011 execution cycle.
> Created: 2026-02-13 | **All items COMPLETED: 2026-02-13**

---

## Alta Prioridade

### ~~#3 Contexto truncado (head -80)~~ DONE
- **Fix**: Replaced `head -80` with `cat` in `start.sh` for spec, research, and plan injection.

### ~~#4 Regras do projeto não são injetadas no prompt~~ DONE
- **Fix**: Added `project_rules` extraction from main CLAUDE.md — injected as "Project Rules (from main CLAUDE.md — MUST follow)" section in agent prompt.

### ~~#1 Log do agente está vazio~~ DONE
- **Fix**: Added `--output-format stream-json` to claude invocation in `process.sh`. Also confirmed `unset CLAUDECODE` (Bug 1 fix) is in place.

---

## Média Prioridade

### ~~#5 /sdd-run não é realmente autopilot~~ VERIFIED
- **Result**: The `cmd_sdd_run()` code already chains gate → tasks → setup → start → monitor correctly. The original issue was caused by Bug 1 (CLAUDECODE env var killing agents), not a missing chain. With Bug 1 fixed, autopilot works end-to-end.

### ~~#7 Merge deveria ter pre-flight check~~ DONE
- **Fix**: Added `--dry-run` flag to `merge.sh` — shows branch status, DONE.md presence, uncommitted changes, and conflict simulation for each worktree without executing.

### ~~#9 Agent timeout/watchdog inexistente~~ DONE
- **Fix**: Added `--timeout N` flag to `cmd_start` — after N minutes, the monitoring loop kills all running agents and logs TIMEOUT events.

---

## Baixa Prioridade

### ~~#6 Sem modo "direct" para specs single-worktree~~ DONE
- **Fix**: Added `--direct` flag to `sdd run` — creates a feature branch without a worktree and runs the agent directly. Also added auto-detection hint for single-module specs.

### ~~#8 Cleanup deveria ser parte do merge~~ DONE
- **Fix**: Added `--cleanup` flag to `merge` — after successful merge (0 failures), automatically runs `cmd_cleanup` with FORCE=true.

### ~~#10 Sem retry automático~~ DONE
- **Fix**: Refactored `start_agent_process` with retry loop (3 attempts, 5s/10s/20s backoff). On final failure, creates BLOCKED.md with error context.

### ~~#2 PROGRESS.md não reflete progresso real~~ DONE
- **Fix**: Updated agent prompt to explicitly require creating ALL steps as checkboxes upfront, and updating after EACH completed step.

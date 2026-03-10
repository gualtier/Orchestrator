# Research: Kaizen + PDCA + SDD + TDD + Ralph Loops Integration

> Spec: 005 | Created: 2026-03-10
> Spec Reference: .claude/specs/active/005-kaizen-pdca-sdd-tdd-ralph-loops-integration/spec.md

## Library Analysis

No external libraries needed. This is purely a Bash-level enhancement to existing orchestrator scripts. All work is additive to the current shell codebase.

| Component | Current State | Gap | Effort |
|-----------|--------------|-----|--------|
| Ralph loops | Fully implemented (ralph.sh, 827 lines) | No PDCA phase tracking, no kaizen review | Medium |
| SDD run | Full autopilot (sdd.sh, 1626 lines) | No HITL mode, no post-cycle Act phase | Medium |
| Metrics | EVENTS.md (append-only) + per-agent state files | No structured JSON metrics, no aggregation | Medium |
| Memory update | learning.sh (337 lines), auto-extracts patterns | No kaizen-specific review, no improvement suggestions | Low |
| Iteration caps | Already implemented (default 20, configurable) | No cost controls UI, no pause-on-cap notification beyond BLOCKED.md | Low |
| Status display | Comprehensive agent/spec status | No PDCA phase column, no metrics dashboard | Low |

## Performance Considerations

- **Kaizen review**: Post-cycle processing, not in critical path. Budget: <60s. Will read EVENTS.md + agent logs + DONE.md files. All local file I/O, no bottleneck.
- **Metrics collection**: Writing JSON to disk during Ralph iterations. One file write per iteration (~50 bytes). Negligible overhead (<10ms).
- **PDCA phase tracking**: Single string comparison in `get_spec_status()`. Zero performance impact.
- **HITL mode**: Adds a pause between iterations (user input wait). No performance concern — it's intentionally slower.

## Security Implications

- **No new attack surface**: All changes are local file operations within `.claude/` directory
- **Metrics files**: Will be gitignored (project-specific runtime data). No secrets stored.
- **HITL mode**: No network exposure — just stdin/stdout interaction during Ralph loops

## Existing Patterns in Codebase (REUSE THESE)

### 1. Ralph Loop Engine (ralph.sh)
**Already has:**
- Iteration counting (`pids/{name}.iteration`)
- Max iteration cap (`RALPH_MAX_ITERATIONS`, default 20)
- Stall detection (`pids/{name}.stall_count`)
- Gate results tracking (`pids/{name}.gates`)
- Mid-iteration polling (every 5 seconds)
- Completion detection (DONE.md + completion signal + gates pass)
- BLOCKED.md creation on max iterations or stall
- Cancel mechanism (`cmd_cancel_ralph`)

**Key insight**: Iteration caps already exist. REQ-11 is partially done — just needs better notification and config.json support.

### 2. SDD Run Pipeline (sdd.sh, lines 839-1366)
**Already has:**
- `--ralph` / `--no-ralph` flags
- `--max-iterations N` flag
- `--auto-merge` for full autopilot
- Post-execution: auto `update-memory --full`
- Three modes: worktree, teams, direct

**Key insight**: Adding `--hitl` and `--afk` flags follows existing flag parsing pattern (lines 869-886).

### 3. Event Logging (EVENTS.md)
**Already tracks:**
- `RALPH_START`, `RALPH_ITER_START`, `RALPH_ITER_END`, `RALPH_GATE_FAIL`, `RALPH_COMPLETE`, `RALPH_STALL`, `RALPH_MAX_ITER`
- `SDD_RUN_START`, `SDD_RUN_COMPLETE`, `SDD_VALIDATE_SKIP`
- Per-iteration data available for metrics extraction

**Key insight**: EVENTS.md already contains raw data for metrics. Kaizen review can parse this.

### 4. State Externalization (state.sh)
**Pattern**: `ORCHESTRATOR_STATE.md` updated on every status check.
**Reuse**: Add PDCA phase to the per-spec section of state output.

### 5. Learning Extraction (learning.sh)
**Pattern**: Reads DONE.md/PROGRESS.md, categorizes as patterns/pitfalls/effectiveness, appends to PROJECT_MEMORY.md.
**Reuse**: Kaizen review extends this with iteration analysis and improvement suggestions.

### 6. Spec Status State Machine (lib/sdd.sh, lines 97-149)
**Current states**: empty → specified → researched → planned → tasks-ready → executing → completed → validated
**Extension**: Map each to PDCA phase. No new states needed — just a phase label overlay.

### 7. Configuration Pattern
**Task-level**: Frontmatter `> key: value` in task files
**Global**: CLI flags exported as environment variables
**Hierarchy**: Global overrides task-level
**Reuse**: Add `config.json` as optional persistent config (not yet implemented, but follows existing env var pattern).

## Constraints & Limitations

1. **Pure Bash**: All implementation must be Bash. No Python, Node, or external tools. This keeps orchestrator dependency-free.
2. **No interactive input in background agents**: HITL mode can only work in the main orchestrator process, not inside worktree agents.
3. **File-based state**: All persistence is file I/O. No databases. JSON parsing limited to what `jq` (if available) or `grep`/`sed` can handle.
4. **Context compaction**: Agents may lose context. All critical state must survive via disk files (already the pattern).
5. **Autonomy first**: All new features must default to autonomous operation. HITL is opt-in. Kaizen review is auto-run (not requiring user action).

## Recommendations

### Architecture: Minimal Additions to Existing Code

1. **PDCA Phase Mapping** (REQ-1, REQ-2): Add a `get_pdca_phase()` function in `lib/sdd.sh` that maps existing spec status to PDCA phases. Modify `cmd_sdd_status` to show phase column. ~30 lines of code.

2. **Kaizen Review** (REQ-3 through REQ-7): New command `sdd kaizen <number>` in `commands/sdd.sh`. Parses EVENTS.md for the spec's execution data, reads DONE.md files, generates a structured report, auto-appends lessons to PROJECT_MEMORY.md. ~150 lines.

3. **HITL Mode** (REQ-8 through REQ-10): Add `--hitl` flag to `sdd run`. In ralph loop, when HITL is active, pause after each iteration with a prompt showing results. Implement as a simple `read -p` in the ralph loop polling. ~40 lines.

4. **Metrics Collection** (REQ-17 through REQ-19): Write JSON metrics file per spec during Ralph loop execution. Collect: iteration count, gate pass/fail per iteration, elapsed time, files changed. Parse and display in status commands. ~80 lines.

5. **Config.json** (REQ-11): Optional `.claude/orchestration/config.json` for persistent settings (max_iterations, kaizen auto-run, etc.). Loaded in `init_config()`. ~30 lines.

6. **Auto-Hotfix Spec** (REQ-16): In validation failure path, auto-create a new spec with the failure details. ~40 lines.

### Total Estimated Scope: ~370 lines of new code across 5-6 files

### File Impact Map

| File | Changes | Type |
|------|---------|------|
| `lib/sdd.sh` | Add `get_pdca_phase()`, extend `get_spec_status()` | Modify |
| `lib/ralph.sh` | Add HITL pause, metrics write per iteration | Modify |
| `commands/sdd.sh` | Add `kaizen` subcommand, `--hitl`/`--afk` flags, PDCA in status | Modify |
| `commands/status.sh` | Add metrics display | Modify |
| `lib/core.sh` | Load config.json if exists | Modify |
| `lib/learning.sh` | Extend for kaizen review output | Modify |

### Implementation Order

1. **PDCA phase mapping** (foundation, affects status display)
2. **Metrics collection** (needed by kaizen review)
3. **Kaizen review command** (uses metrics + events)
4. **HITL mode** (independent, can be parallel)
5. **Config.json support** (optional enhancement)
6. **Auto-hotfix on validation failure** (edge case, lowest priority)

## Open Questions — Resolved

| Question | Resolution |
|----------|-----------|
| Kaizen auto-run vs opt-in? | **Auto-run** after every spec completion (autonomous-first). Skip with `--no-kaizen`. |
| HITL default for new users? | **No**. AFK is default (autonomous-first). HITL is opt-in with `--hitl`. |
| Metrics committed to git? | **Gitignored** by default. Runtime data, not source. |
| JSON parsing without jq? | Use simple `printf` for writing JSON. For reading, use `grep`/`sed` patterns already used in codebase. Optionally use `jq` if available. |

## Sources

- Codebase analysis: `ralph.sh` (827 lines), `sdd.sh` (1626 lines), `learning.sh` (337 lines), `state.sh` (146 lines), `monitoring.sh` (~250 lines), `core.sh` (~150 lines)
- Kaizen/PDCA methodology: W. Edwards Deming's PDCA cycle, Toyota Production System continuous improvement principles
- Existing orchestrator documentation: `CLAUDE.md`, `CAPABILITIES.md`

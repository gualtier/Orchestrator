# Spec: Kaizen + PDCA + SDD + TDD + Ralph Loops Integration

> Spec: 005 | Created: 2026-03-10 | Status: DRAFT

## Problem Statement

The orchestrator currently has three powerful methodologies (SDD, TDD, Ralph Loops) that work together but lack a unifying improvement framework. Each spec cycle generates valuable lessons, but there is no structured mechanism to:

1. **Capture and apply learnings** automatically after each cycle (lessons rot in memory or get forgotten)
2. **Track improvement over time** (no metrics on iteration counts, pass rates, or agent effectiveness)
3. **Control costs** systematically (Ralph loops can run away without explicit caps)
4. **Graduate from supervised to autonomous** execution (no HITL/AFK mode distinction)

By mapping PDCA as the structural framework and Kaizen as the continuous improvement philosophy, we formalize what is currently ad-hoc into a repeatable, measurable improvement engine.

## User Stories

- As an **orchestrator user**, I want the system to automatically extract lessons after each completed spec so that my agents get smarter with every cycle without manual intervention
- As an **orchestrator user**, I want to see metrics on how many iterations specs took and how pass rates trend over time so that I can measure whether my process is improving
- As an **orchestrator user**, I want configurable iteration caps on Ralph loops so that runaway API costs are prevented automatically
- As an **orchestrator user**, I want a `--hitl` mode where I can watch agent output in real-time to refine prompts before switching to fully autonomous `--afk` mode
- As an **orchestrator user**, I want the PDCA cycle phases (Plan/Do/Check/Act) to be explicitly tracked in the SDD lifecycle so that I know which phase each spec is in
- As an **orchestrator user**, I want a Kaizen review to run automatically after each spec completion that suggests concrete improvements to agent prompts and workflow

## Functional Requirements

### PDCA Cycle Mapping
- [ ] REQ-1: Map SDD stages to PDCA phases explicitly: Plan (specify+research+plan), Do (tasks+setup+start with Ralph/TDD), Check (gate+validate), Act (kaizen review+memory update+archive)
- [ ] REQ-2: Track and display current PDCA phase in `sdd-status` output (e.g., `PLAN`, `DO`, `CHECK`, `ACT`)
- [ ] REQ-3: Add an "Act" phase that auto-executes after successful validation: extract lessons, update memory, suggest prompt refinements

### Kaizen Automation
- [ ] REQ-4: Implement `kaizen-review` command/skill that analyzes a completed spec's execution history
- [ ] REQ-5: Kaizen review outputs: what went well, what went wrong, suggested AGENT.md/prompt refinements, iteration analysis
- [ ] REQ-6: Auto-update `PROJECT_MEMORY.md` lessons learned section from kaizen review findings
- [ ] REQ-7: Track improvement metrics in `.claude/orchestration/metrics/` (JSON format): iterations per spec, pass/fail rates, time-to-completion

### HITL / AFK Modes
- [ ] REQ-8: Add `--hitl` flag to `sdd-run` that runs Ralph loops with real-time output streaming and pause-between-iterations for user review
- [ ] REQ-9: Add `--afk` flag to `sdd-run` as explicit fully autonomous mode (current default behavior)
- [ ] REQ-10: HITL mode pauses after each Ralph iteration showing: test results, changes made, iteration count, and prompts user to continue/adjust/stop

### Iteration Caps & Cost Controls
- [ ] REQ-11: Add configurable `max_iterations` to Ralph loop (default: 20, configurable via `.claude/orchestration/config.json` or `--max-iterations` flag)
- [ ] REQ-12: Auto-pause with notification when iteration cap is reached (not silent failure)
- [ ] REQ-13: Track cumulative iteration counts across all specs in metrics store
- [ ] REQ-14: Display iteration count and cap in `orch-status` output

### CI Green Guarantee
- [ ] REQ-15: Formalize pre-merge test verification as the PDCA "Check" phase (gate must pass before merge)
- [ ] REQ-16: If post-merge validation fails, auto-create a hotfix spec in the "Act" phase with findings from the failure

### Metrics Dashboard
- [ ] REQ-17: Implement metrics collection during Ralph loops: iteration count, test pass/fail per iteration, elapsed time, files changed
- [ ] REQ-18: Surface aggregated metrics in `sdd-status` (per-spec) and `orch-status` (global trends)
- [ ] REQ-19: Store metrics as JSON in `.claude/orchestration/metrics/<spec-number>.json`

## Non-Functional Requirements
- [ ] Performance: Kaizen review should complete in under 60 seconds (it's a post-processing step, not blocking)
- [ ] Compatibility: All changes must be backward-compatible — existing `sdd-run` without flags works exactly as today
- [ ] Simplicity: Metrics collection must not add perceptible overhead to Ralph loops (< 100ms per iteration)
- [ ] Storage: Metrics files should be gitignored (they are project-specific runtime data)

## Acceptance Criteria

- [ ] AC-1: Given a completed spec, when `kaizen-review 005` is run, then it produces a structured report with lessons learned and suggested improvements
- [ ] AC-2: Given a spec in progress, when `sdd-status` is run, then it shows the current PDCA phase (PLAN/DO/CHECK/ACT)
- [ ] AC-3: Given `sdd-run 005 --hitl`, when a Ralph iteration completes, then execution pauses and shows results for user review before continuing
- [ ] AC-4: Given a Ralph loop running with `max_iterations=5`, when iteration 5 completes without convergence, then execution pauses with a notification (not silent exit)
- [ ] AC-5: Given 3 completed specs with metrics, when `orch-status` is run, then it shows global trends (avg iterations, pass rates, improvement over time)
- [ ] AC-6: Given a post-merge validation failure, when the Act phase runs, then a hotfix spec is auto-created with the failure details
- [ ] AC-7: Given `sdd-run 005` (no flags), when executed, then behavior is identical to current implementation (backward compatible)

## Production Validation

How the validation agent should verify this works after merge:

- [ ] Verify `.claude/orchestration/metrics/` directory is created and gitignored
- [ ] Run `sdd-status` and confirm PDCA phase column appears
- [ ] Run `sdd-run --help` or check script and confirm `--hitl`, `--afk`, `--max-iterations` flags are recognized
- [ ] Create a test spec, run through full cycle, verify `kaizen-review` produces output
- [ ] Verify `PROJECT_MEMORY.md` is updated automatically after kaizen review
- [ ] Verify iteration cap triggers pause at configured limit
- [ ] Verify metrics JSON is written after Ralph loop execution
- [ ] Run existing `sdd-run` without new flags — confirm no behavioral change

## Out of Scope

- **AI model cost tracking**: We track iteration counts, not dollar amounts (costs vary by model/provider)
- **Context rot detection**: While mentioned in the vision, automated detection of output quality degradation is too complex for v1 — Ralph's fresh-context-per-iteration already mitigates this
- **AGENT.md auto-modification**: Kaizen review will *suggest* changes, not auto-apply them (human approval required for prompt changes)
- **Cross-project Kaizen**: Metrics and lessons are per-project, not aggregated across different repos
- **UI/Web dashboard**: Metrics are CLI-only for now

## Open Questions

- [NEEDS CLARIFICATION] Should the kaizen review be mandatory (auto-runs after every spec) or opt-in (`--kaizen` flag)? **Recommendation: auto-run but skippable with `--no-kaizen`**
- [NEEDS CLARIFICATION] Should HITL mode be the default for first-time users, with AFK as the "graduated" mode? **Recommendation: AFK remains default, HITL is opt-in**
- [NEEDS CLARIFICATION] Should metrics be committed to git (for team visibility) or gitignored (project-specific)? **Recommendation: gitignored by default, with `--commit-metrics` option**

## Dependencies

- Existing Ralph loop implementation (`.claude/scripts/ralph-loop.sh`)
- Existing SDD lifecycle (`sdd-run`, `sdd-validate`, `sdd-archive`)
- `PROJECT_MEMORY.md` update mechanism (`update-memory`)
- `.claude/orchestration/config.json` (may need to be created if it doesn't exist)

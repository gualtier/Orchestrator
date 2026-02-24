# Changelog


## [2026-02-24]

- chore: remove worktree artifacts from autonomous-pipeline merge (7c207a5)
- feat(autonomous-pipeline): finalize with DONE.md and PROGRESS.md (b1c98c8)
- feat(autonomous-pipeline): add tests, fix case-insensitive self-dev detection (90f7c9a)
- feat(autonomous-pipeline): add --auto-merge flag and post-run automation to sdd run (b5988b6)
- feat(autonomous-pipeline): convert memory hook to command, add shared hook utils (1ce1fca)


## [v3.8] - 2026-02-13

### Agent Teams Backend

- feat(teams): `lib/teams.sh` — Agent Teams backend library (429 lines)
- feat(teams): `commands/team.sh` — team start/status/stop commands (191 lines)
- feat(teams): dual execution mode with `--mode teams|worktree` flag on `sdd run`
- feat(teams): `EXECUTION_MODE` env var for configurable default backend
- feat(teams): graceful fallback to worktree mode when Agent Teams unavailable
- feat(teams): team lead prompt generation from SDD artifacts (spec, research, plan)
- feat(teams): agent specialization via spawn prompts (preset .md content injected)
- feat(teams): branch-per-teammate file conflict mitigation
- feat(hooks): `TeammateIdle` hook — prevents idle without commits/DONE.md (exit code 2)
- feat(hooks): `TaskCompleted` hook — validates commits and DONE.md before completion
- feat(teams): hybrid monitoring — interactive team lead + background dashboard
- feat(skills): `/orch-team-start` and `/orch-team-status` Claude Code skills
- fix(sdd): worktree mapping parser skipping data rows containing 'Module' (3de0b93)
- docs: updated all consciousness layers (CAPABILITIES, PROJECT_MEMORY, CLAUDE.md, Skills, README)

## [v3.7] - 2026-02-12

### SDD Autopilot

- feat(sdd): `sdd run` autopilot command — chains gate, tasks, setup, start, and monitor in one command
- feat(sdd): dual mode — `sdd run 001` (single spec) or `sdd run` (all planned specs)
- feat(sdd): fail-fast on gate failure, task generation error, or worktree setup failure
- feat(sdd): integration reminder when multiple agents complete in isolation
- feat(sdd): stale task cleanup before regeneration on re-runs
- feat(skills): `/sdd-run` Claude Code skill with full documentation
- docs: updated CLAUDE.md, help.sh, CAPABILITIES.md, /sdd hub with autopilot workflow
- docs: added autopilot as alternative path in all SDD flow diagrams

## [2026-02-12]

- fix(set-e): remove set -e from orchestrate.sh, fixes counter crashes and monitor/watch loops
- fix(monitoring): change .git directory check to -e for worktree .git files
- fix(stop): rewrite cmd_stop argument parsing to handle --force in any position
- fix(merge): save/restore branch on failure, abort conflicted merge before continuing
- fix(learn): guard shift on empty args, prevents crash on `orch learn` with no subcommand
- fix(process): log cd failure instead of silently masking it in agent subshell
- fix(errors): sanitize pipe chars in error messages to prevent state/log corruption
- fix(errors): normalize init format to 5 fields, add || true to counter increments
- fix(sdd): gate miscounting modules by parsing all tables instead of Worktree Mapping only
- fix(sdd): worktree mapping parser not stopping at ### subsection headings
- feat(start): auto-monitor agents until completion with --no-monitor opt-out
- fix(process): prevent set -e from killing script when one agent fails to start
- fix(process): disable set -e inheritance in nohup subshell for agent launch
- fix(process): improve health check from single sleep to 3-attempt retry loop
- fix(paths): replace all 23 relative worktree paths with absolute get_worktree_path()
- docs(v3.6): complete error monitoring integration across all consciousness layers (84dea0f)
- feat(error-monitor): implement active error monitoring for orchestrator agents (a6d1250)
- fix(agents): ensure DONE.md creation and add commit-based fallback detection (ede4ef2)
- docs(memory): update memory and changelog after hooks feature (b44b8f3)
- feat(hooks): add post-merge routine check and self-dev docs sync (7f184e6)

## [v3.6] - 2026-02-12

### Active Error Monitoring

- feat(errors): active error detection engine with incremental byte-offset log polling
- feat(errors): 3-tier severity classification (CRITICAL / WARNING / INFO)
- feat(errors): error dashboard with --watch, --agent, --recent, --clear modes
- feat(errors): corrective action suggestions per error type
- feat(errors): error counts integrated into status and wait commands
- feat(errors): /orch-errors Claude Code skill for real-time error monitoring
- docs(consciousness): update all 4 layers (CAPABILITIES, PROJECT_MEMORY, CLAUDE.md, Skills)
- docs(readme): add v3.6 error monitoring section and /orch-errors skill

## [v3.5.2] - 2026-02-11

### Claude Code Hooks

- feat(hooks): add post-merge routine check and self-dev docs sync
- feat(hooks): add Claude Code hooks for memory, context reinject, and task checks
- fix(agents): ensure DONE.md creation and add commit-based fallback detection

## [v3.5.1] - 2026-02-11

### Update System Overhaul

- feat(update): auto-detect remote and separate CAPABILITIES.md
- feat(update): expand scope to skills/specs and add what's new message

## [v3.5] - 2026-02-09

### Spec-Driven Development

- feat(sdd): full SDD pipeline (specify, research, plan, gate, tasks, archive)
- feat(sdd): constitution system with editable project principles
- feat(skills): 14 Claude Code Skills for SDD and orchestration
- docs(memory): update project memory with v3.5 completion status

## [v3.4] - 2026-02-09

### Learning & Enhanced Monitoring

- feat(monitoring): add enhanced progress monitoring with live updates
- feat(learn): add learning extraction and management system
- i18n: translate all Portuguese content to English

## [v3.1] - 2026-01-26

### Modularization

- feat(orchestrate): refactor to modular architecture v3.1
- feat(orchestrate): add verification and quality commands
- fix(orchestrate): fix Claude CLI execution in worktrees

## [v3.0] - 2026-01-26

### Initial Release

- Initial commit: Orchestrator v3.0

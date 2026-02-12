# Changelog

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

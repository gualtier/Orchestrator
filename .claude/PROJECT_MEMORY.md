# Project Memory - Claude Orchestrator

> **Last update**: 2026-02-11 14:30:00
> **Version**: 3.5.1

## Overview

### Project

- **Name**: claude-orchestrator
- **Description**: Claude agent orchestration system using Git Worktrees with specialized agents
- **Started**: 2025-01-21
- **Repo**: [local/github]

### Stack

| Layer        | Technology                      |
|--------------|---------------------------------|
| Language     | Bash                            |
| Dependencies | Git, curl, Claude CLI           |
| Agents       | VoltAgent/awesome-claude-code-subagents |

## Architecture v3.5

### Modular Structure

```
.claude/skills/                     # Claude Code Skills (NEW v3.5)
├── sdd*/SKILL.md                   # 8 SDD skills (/sdd-init, /sdd-specify, etc.)
├── orch*/SKILL.md                  # 5 orchestrator skills (/orch-setup, /orch-errors, etc.)
├── sdd/SKILL.md                    # SDD hub (/sdd)
└── orch/SKILL.md                   # Orchestrator hub (/orch)

.claude/scripts/
├── orchestrate.sh          # Entry point
├── lib/
│   ├── logging.sh          # Logging and colors
│   ├── core.sh             # Config and utilities
│   ├── validation.sh       # Input validation
│   ├── git.sh              # Git/worktree operations
│   ├── process.sh          # Process management
│   ├── agents.sh           # Agent management
│   ├── monitoring.sh       # Enhanced monitoring (v3.4)
│   ├── error_detection.sh  # Active error monitoring (v3.6)
│   ├── learning.sh         # Learning extraction (v3.4)
│   └── sdd.sh              # SDD library (NEW v3.5)
├── commands/
│   ├── init.sh             # init, init-sample
│   ├── doctor.sh           # doctor, doctor --fix
│   ├── setup.sh            # setup
│   ├── learn.sh            # learn command (v3.4)
│   ├── errors.sh           # error monitoring dashboard (v3.6)
│   ├── sdd.sh              # sdd command (NEW v3.5)
│   ├── start.sh            # start, stop, restart, logs
│   ├── status.sh           # status, status --json, wait
│   ├── verify.sh           # verify, review, pre-merge, report
│   ├── merge.sh            # merge, cleanup, memory
│   ├── update.sh           # update, update-check
│   └── help.sh             # help
├── tests/
│   ├── test_runner.sh      # Test framework
│   └── test_validation.sh  # 20 tests
└── completions/
    └── orchestrate.bash    # Shell completions
```

### Components

| Component   | File               | Responsibility                          |
|-------------|--------------------|-----------------------------------------|
| Entry Point | orchestrate.sh     | Load libs and route commands            |
| Logging     | lib/logging.sh     | Colors, timestamps, formatting          |
| Core        | lib/core.sh        | Configuration, traps, utilities         |
| Validation  | lib/validation.sh  | Validate names, presets, files          |
| Git         | lib/git.sh         | Worktrees, branches, merge              |
| Process     | lib/process.sh     | PIDs, logs, start/stop                  |
| Agents      | lib/agents.sh      | Download, cache, presets                |
| Monitoring  | lib/monitoring.sh  | Progress bars, velocity, ETA, activity  |
| Errors      | lib/error_detection.sh | Active error monitoring, log polling, classification |
| Learning    | lib/learning.sh    | Extract insights, parse DONE.md         |
| SDD         | lib/sdd.sh         | Spec numbering, templates, gates, tasks |

## Roadmap

### v1.0 - Foundation

- [x] Basic orchestration with worktrees
- [x] Persistent memory
- [x] Basic commands (setup, start, status, merge)

### v2.0 - Robustness

- [x] Pre-execution validation
- [x] Checkpoint system
- [x] Automatic recovery
- [x] Monitor dashboard

### v3.0 - Specialized Agents

- [x] VoltAgent integration
- [x] Automatic agent download
- [x] Preset system
- [x] Local agent cache

### v3.1 - Modularization

- [x] Refactor script into modules (lib/, commands/)
- [x] Input validation in all commands
- [x] Doctor command for diagnostics
- [x] Confirmation in destructive operations
- [x] JSON output (status --json)
- [x] Automated testing framework
- [x] Shell completions
- [x] Task examples (init-sample)
- [x] Verification commands (verify, pre-merge, report)

### v3.2 - Memory Management

- [x] Flags for update-memory (--bump, --changelog, --full)
- [x] Automatic version increment
- [x] Changelog generation from commits
- [x] Direct execution flow in CLAUDE.md
- [x] Mandatory update-memory routine after commits

### v3.3 - Auto-Update

- [x] `update` command to update from remote
- [x] `update-check` command to check for updates
- [x] Automatic backup before updating
- [x] Automatic rollback on failure
- [x] Post-update integrity verification

### v3.4 - Learning & Enhanced Monitoring

- [x] Learning system (`orch learn`)
- [x] Extract insights from completed tasks
- [x] Incorporate knowledge into CLAUDE.md
- [x] Enhanced status with progress bars
- [x] Activity tracking (active/idle/stalled)
- [x] Velocity and ETA calculations
- [x] Watch mode with live updates
- [x] Compact status format
- [x] `install-cli` command to create global shortcut
- [x] `uninstall-cli` command to remove shortcut

### v3.5 - Spec-Driven Development

- [x] SDD integration inspired by GitHub Spec-Kit
- [x] Constitution system (editable project principles)
- [x] `sdd specify` - auto-numbered spec creation with templates
- [x] `sdd research` - mandatory research gate before planning
- [x] `sdd plan` - technical plans with worktree mapping
- [x] `sdd gate` - constitutional gates (research, simplicity, test-first, traceability)
- [x] `sdd tasks` - bridge: generates orchestrator tasks from plan
- [x] `sdd status` - spec lifecycle tracking
- [x] `sdd archive` - completed spec archival
- [x] Spec traceability in verify command (step 6/6)
- [x] SDD context injection into agent prompts (spec-ref)
- [x] Agent SDD awareness (AGENT_CLAUDE_BASE.md)
- [x] Shell completions for sdd commands
- [x] Claude Code Skills integration (15 skills: `/sdd-*`, `/orch-*`)
- [x] Native slash commands for SDD and orchestration workflows
- [x] Autonomous skill invocation (Claude auto-chains SDD pipeline)
- [x] README with practical usage examples and memory value proposition

### v3.5.1 - Update System Overhaul

- [x] Dedicated `orchestrator` remote for updates (no longer requires `origin`)
- [x] Auto-creates `orchestrator` remote in projects where `origin` points elsewhere
- [x] `.claude/CAPABILITIES.md` - auto-updated capabilities file (replaces CLAUDE.md in update paths)
- [x] `orch update` no longer overwrites project-specific `CLAUDE.md`
- [x] CLAUDE.md references CAPABILITIES.md in Rule #1 (memory + capabilities)
- [x] Repo URL changed from `Orchestrator-` to `Orchestrator`

### v3.5.2 - Claude Code Hooks

- [x] Claude Code hooks system (`.claude/settings.json`, `.claude/hooks/`)
- [x] Context re-injection on compaction (`SessionStart` hook, matcher: `compact`)
- [x] Memory update enforcement (`Stop` prompt-based hook, checks commits vs update-memory)
- [x] Task completion check (`Stop` prompt-based hook, blocks on unfinished tasks)
- [x] `reinject-context.sh` - outputs PROJECT_MEMORY.md + CAPABILITIES.md after compaction

### v3.6 - Active Error Monitoring (CURRENT)

- [x] `lib/error_detection.sh` - Core error detection engine (540+ lines)
- [x] `commands/errors.sh` - Error monitoring dashboard (330+ lines)
- [x] Incremental byte-offset log polling (`tail -c +offset | grep -E`)
- [x] 3-tier severity classification: CRITICAL / WARNING / INFO
- [x] Error context extraction (file/line from error messages)
- [x] Corrective action suggestions per error type
- [x] `orchestrate.sh errors` command with `--watch`, `--agent`, `--recent`, `--clear`
- [x] Error counts integrated into `status` (standard + enhanced modes)
- [x] Real-time error notifications during `wait` and `status --watch`
- [x] Persistent error log (`.claude/orchestration/errors.log`, pipe-delimited)
- [x] Error state per agent (`.claude/orchestration/pids/<name>.errors`)
- [x] `/orch-errors` skill for Claude Code
- [x] Zero external dependencies, bash 3.2+ compatible

### v4.0 - Future

- [ ] Web interface for monitoring
- [ ] CI/CD integration
- [ ] Metrics and analytics
- [ ] Multi-LLM support
- [ ] Customizable presets (YAML)

## Architecture Decisions

### ADR-001: Pure Bash vs Node/Python

- **Decision**: Pure Bash
- **Reason**: Zero dependencies, works on any system with Git
- **Trade-off**: Fewer advanced features, more verbose code

### ADR-002: Git Worktrees vs Branches

- **Decision**: Worktrees
- **Reason**: True parallel execution, each agent in isolated directory
- **Trade-off**: More complex, uses more disk space

### ADR-003: Agents as Markdown

- **Decision**: .md files with instructions
- **Reason**: Simple, versionable, editable, compatible with VoltAgent
- **Trade-off**: No schema validation

### ADR-004: Modular Architecture

- **Decision**: Separate into lib/ and commands/
- **Reason**: Facilitates maintenance, testing, and extensibility
- **Trade-off**: More files to manage

### ADR-005: Native SDD over Spec-Kit CLI

- **Decision**: Build SDD concepts natively in Bash, not install spec-kit Python CLI
- **Reason**: Zero additional dependencies, deep integration with orchestrator pipeline, full customization
- **Trade-off**: Must maintain our own implementation of SDD concepts

## Resolved Problems

| Problem                       | Version | Solution                                   |
|-------------------------------|---------|---------------------------------------------|
| Non-existent `--workdir`      | 3.1     | Use cd in subshell                          |
| Missing permissions           | 3.1     | Use `--dangerously-skip-permissions`        |
| Monolithic script             | 3.1     | Modularization into lib/ and commands/      |
| No validation                 | 3.1     | Create lib/validation.sh                    |
| Destructive operations        | 3.1     | Create confirm() function                   |
| update-memory timestamp only  | 3.2     | Add --bump, --changelog, --full             |
| No flow for direct tasks      | 3.2     | Document direct execution in CLAUDE.md      |
| Symlink not resolving path    | 3.4     | Resolve symlinks with readlink loop         |
| macOS `head -n -1` invalid    | 3.5     | Use `sed '$d'` for BSD compatibility        |
| Glob trailing slash in paths  | 3.5     | Strip trailing slash in spec_dir_for()      |
| Update overwrites CLAUDE.md   | 3.5.1   | Separate CAPABILITIES.md, remove CLAUDE.md from update paths |
| Update requires `origin` remote | 3.5.1 | Auto-create `orchestrator` remote, fallback to `origin`     |
| New features invisible to orch  | 3.6   | Update ALL consciousness files: CAPABILITIES.md, PROJECT_MEMORY.md, skills, CLAUDE.md |
| Gate counts all `\|` lines      | 3.6   | Simplicity gate counts ALL table rows in plan.md, not just Worktree Mapping. Use lists instead of tables for non-module sections |

## Lessons Learned

1. **Bash compatibility**: Avoid `declare -A`, prefer `case` functions
2. **set -e in tests**: Don't use, allows tests that expect failures
3. **Redirection in for**: `for x in *.txt 2>/dev/null` is invalid
4. **Escaping in tests**: Use single quotes for literal strings
5. **Modularization**: Makes testing and maintenance much easier
6. **Memory after commits**: Always update memory content, not just timestamp!
7. **Always README**: Update README.md when adding/modifying features
8. **Symlink resolution**: When using symlinks for global CLI, must resolve with readlink to find real script directory
9. **Project-agnostic CLI**: Global CLI should detect project by current directory, not installation location
10. **Skills autonomy**: Don't set `disable-model-invocation: true` on skills meant for autonomous use - use "Use proactively" in description instead
11. **README-first**: Usage examples before changelog - new users need to see what it does before version history
12. **Post-merge checklist (MANDATORY)**: After EVERY merge, run in this exact order: (1) `update-memory --full` (with --full!), (2) `learn extract`. Never skip or use wrong flags
13. **Feature consciousness checklist**: When adding a new feature, update ALL 4 consciousness layers: (1) CAPABILITIES.md — CLI commands + feature description, (2) PROJECT_MEMORY.md — architecture tree + components table + roadmap, (3) CLAUDE.md — workflow diagrams + command references, (4) Skills — create new skill + update /orch hub. Missing any layer = orch won't know the feature exists in future sessions
14. **CAPABILITIES.md = full CLI reference**: Must list ALL commands, not just "main" ones. Undocumented commands are invisible commands. Audit with `grep "^\s*[a-z-]*)" orchestrate.sh` vs documented list

## Next Session

### Completed

- [x] Complete modularization
- [x] Automated tests
- [x] Updated documentation
- [x] update-memory with versioning and changelog
- [x] Direct execution flow documented
- [x] Update command for auto-update
- [x] SDD integration (v3.5)
- [x] 14 Claude Code Skills with autonomous invocation
- [x] README rewrite with usage examples and memory docs

### Future Ideas

- Web dashboard with WebSocket
- Execution time metrics per agent
- GitHub Actions integration
- YAML preset support

---
> Update with: `.claude/scripts/orchestrate.sh update-memory`

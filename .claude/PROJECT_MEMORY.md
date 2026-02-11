# Project Memory - Claude Orchestrator

> **Last update**: 2026-02-09 23:19:54
> **Version**: 3.5

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
├── orch*/SKILL.md                  # 4 orchestrator skills (/orch-setup, etc.)
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
│   ├── learning.sh         # Learning extraction (v3.4)
│   └── sdd.sh              # SDD library (NEW v3.5)
├── commands/
│   ├── init.sh             # init, init-sample
│   ├── doctor.sh           # doctor, doctor --fix
│   ├── setup.sh            # setup
│   ├── learn.sh            # learn command (v3.4)
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

### v3.5 - Spec-Driven Development (CURRENT)

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
- [x] Claude Code Skills integration (14 skills: `/sdd-*`, `/orch-*`)
- [x] Native slash commands for SDD and orchestration workflows

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

## Next Session

### Completed

- [x] Complete modularization
- [x] Automated tests
- [x] Updated documentation
- [x] update-memory with versioning and changelog
- [x] Direct execution flow documented
- [x] Update command for auto-update

### Future Ideas

- Web dashboard with WebSocket
- Execution time metrics per agent
- GitHub Actions integration
- YAML preset support

---
> Update with: `.claude/scripts/orchestrate.sh update-memory`

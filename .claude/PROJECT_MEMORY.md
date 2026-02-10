# Project Memory - Claude Orchestrator

> **Last update**: 2026-02-09 23:19:54
> **Version**: 3.4

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

## Architecture v3.4

### Modular Structure

```
.claude/scripts/
├── orchestrate.sh          # Entry point
├── lib/
│   ├── logging.sh          # Logging and colors
│   ├── core.sh             # Config and utilities
│   ├── validation.sh       # Input validation
│   ├── git.sh              # Git/worktree operations
│   ├── process.sh          # Process management
│   ├── agents.sh           # Agent management
│   ├── monitoring.sh       # Enhanced monitoring (NEW v3.4)
│   └── learning.sh         # Learning extraction (NEW v3.4)
├── commands/
│   ├── init.sh             # init, init-sample
│   ├── doctor.sh           # doctor, doctor --fix
│   ├── setup.sh            # setup
│   ├── learn.sh            # learn command (NEW v3.4)
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

### v3.4 - Learning & Enhanced Monitoring (CURRENT)

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

## Resolved Problems

| Problem                        | Version | Solution                                    |
|-------------------------------|---------|---------------------------------------------|
| Non-existent `--workdir`      | 3.1     | Use cd in subshell                          |
| Missing permissions           | 3.1     | Use `--dangerously-skip-permissions`        |
| Monolithic script             | 3.1     | Modularization into lib/ and commands/      |
| No validation                 | 3.1     | Create lib/validation.sh                    |
| Destructive operations        | 3.1     | Create confirm() function                   |
| update-memory timestamp only  | 3.2     | Add --bump, --changelog, --full             |
| No flow for direct tasks      | 3.2     | Document direct execution in CLAUDE.md      |

## Lessons Learned

1. **Bash compatibility**: Avoid `declare -A`, prefer `case` functions
2. **set -e in tests**: Don't use, allows tests that expect failures
3. **Redirection in for**: `for x in *.txt 2>/dev/null` is invalid
4. **Escaping in tests**: Use single quotes for literal strings
5. **Modularization**: Makes testing and maintenance much easier
6. **Memory after commits**: Always update memory content, not just timestamp!
7. **Always README**: Update README.md when adding/modifying features

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

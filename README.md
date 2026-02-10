# Claude Orchestrator v3.4

Claude agent orchestration system with **modular architecture** and **specialized agents**.

## What's New

### v3.4 - Learning & Enhanced Monitoring

- **`learn` command** - Extract insights from completed tasks
- **Learning system** - Incorporate project knowledge into CLAUDE.md
- **Enhanced status** - Rich dashboard with progress bars, velocity, ETA
- **Watch mode** - Live auto-refreshing status updates (`status --watch`)
- **Activity tracking** - Real-time indicators (active/idle/stalled)
- **Compact mode** - One-line per agent summary (`status --compact`)

### v3.3 - Auto-Update & CLI

- **`update` command** - Update orchestrator from remote
- **`update-check` command** - Check for available updates
- **`install-cli` command** - Install global shortcut (`orch`)
- **Automatic backup** - Creates backup before updating
- **Rollback** - Automatically restores if update fails
- **Smart init** - Detects and resets orchestrator memory

### v3.2 - Memory Management
- **`update-memory --bump`** - Auto-increment version
- **`update-memory --changelog`** - Generate changelog from commits
- **`update-memory --full`** - Bump + changelog

### v3.1 - Modularization
- Modular architecture (lib/ and commands/)
- `doctor` command for diagnostics
- Input validation
- JSON output (`status --json`)
- Automated tests
- Shell completions

## Installation

```bash
# Copy to your project
cp -r orchestrator-v3/.claude ~/your-project/
cp orchestrator-v3/CLAUDE.md ~/your-project/

# Make executable
chmod +x ~/your-project/.claude/scripts/*.sh

# Initialize (creates clean PROJECT_MEMORY.md for your project)
cd ~/your-project
.claude/scripts/orchestrate.sh init
.claude/scripts/orchestrate.sh doctor

# (Optional) Install global CLI
.claude/scripts/orchestrate.sh install-cli
# Now you can use: orch status, orch help, etc.
```

## Quick Start

```bash
# 1. Initialize
orch init
orch doctor

# 2. Create worktrees with agents
orch setup auth --preset auth
orch setup api --preset api

# 3. Create tasks (or copy examples)
orch init-sample

# 4. Execute
orch start
orch status
orch wait

# 5. Verify quality
orch verify-all
orch pre-merge

# 6. Finalize
orch merge
orch update-memory --full
orch cleanup
```

## Agent Presets

| Preset     | Agents                                                      | Use Case       |
|------------|-------------------------------------------------------------|----------------|
| `auth`     | backend-developer, security-auditor, typescript-pro         | Authentication |
| `api`      | api-designer, backend-developer, test-automator             | REST APIs      |
| `frontend` | frontend-developer, react-specialist, ui-designer           | Frontend       |
| `fullstack`| fullstack-developer, typescript-pro, test-automator         | Full-stack     |
| `mobile`   | mobile-developer, flutter-expert, ui-designer               | Mobile apps    |
| `devops`   | devops-engineer, kubernetes-specialist, terraform-engineer  | DevOps         |
| `data`     | data-engineer, data-scientist, postgres-pro                 | Data           |
| `ml`       | ml-engineer, ai-engineer, mlops-engineer                    | ML             |
| `security` | security-auditor, penetration-tester, security-engineer     | Security       |
| `review`   | code-reviewer, architect-reviewer, security-auditor         | Code review    |

## Commands

### Initialization

```bash
orch init                    # Create structure
orch init-sample             # Copy task examples
orch install-cli [name]      # Install global CLI (default: orch)
orch uninstall-cli [name]    # Remove global CLI
orch doctor                  # Diagnose issues
orch doctor --fix            # Auto-fix issues
```

### Agents

```bash
orch agents list               # List available
orch agents installed          # List installed
orch agents install <agent>    # Install specific agent
orch agents install-preset <p> # Install preset
```

### Execution

```bash
orch setup <name> --preset <p>     # Create worktree
orch setup <name> --agents a1,a2   # With specific agents
orch start                         # Start all
orch start <agent>                 # Start specific
orch stop <agent>                  # Stop
orch restart <agent>               # Restart
```

### Monitoring

```bash
orch status                # View status (standard)
orch status --enhanced     # Rich dashboard with activity tracking
orch status --watch        # Live auto-refresh (5s interval)
orch status --watch 10     # Custom refresh interval
orch status --compact      # One-line per agent summary
orch status --json         # JSON output for automation
orch wait                  # Wait with live updates
orch logs <agent>          # View logs
orch follow <agent>        # Follow logs
```

### Verification

```bash
orch verify <worktree>   # Verify worktree
orch verify-all          # Verify all
orch review <worktree>   # Create review
orch pre-merge           # Verify before merge
orch report              # Generate report
```

### Finalization

```bash
orch merge               # Merge changes
orch cleanup             # Clean up (with confirmation)
```

### Memory

```bash
orch show-memory                  # Show memory
orch update-memory                # Update timestamp
orch update-memory --bump         # Increment version
orch update-memory --changelog    # Generate changelog
orch update-memory --full         # Bump + changelog
```

### Learning

```bash
orch learn extract                # Extract from last 5 tasks
orch learn extract --all          # Extract from all archived tasks
orch learn extract --apply        # Extract and auto-apply
orch learn review                 # Review pending learnings
orch learn add-role <file>        # Add specialized agent role
orch learn show                   # Show current learnings
```

### Updates

```bash
orch update-check    # Check for updates
orch update          # Update from remote (with backup)
```

## Structure

```text
project/
├── CLAUDE.md                          # Architect
├── .claude/
│   ├── PROJECT_MEMORY.md              # Memory
│   ├── agents/                        # Installed agents
│   ├── scripts/
│   │   ├── orchestrate.sh             # Entry point
│   │   ├── lib/                       # Libraries
│   │   │   ├── logging.sh
│   │   │   ├── core.sh
│   │   │   ├── validation.sh
│   │   │   ├── git.sh
│   │   │   ├── process.sh
│   │   │   └── agents.sh
│   │   ├── commands/                  # Commands
│   │   │   ├── init.sh
│   │   │   ├── doctor.sh
│   │   │   ├── setup.sh
│   │   │   ├── start.sh
│   │   │   ├── status.sh
│   │   │   ├── verify.sh
│   │   │   ├── merge.sh
│   │   │   ├── update.sh
│   │   │   └── help.sh
│   │   ├── tests/
│   │   └── completions/
│   └── orchestration/
│       ├── tasks/
│       ├── examples/
│       ├── logs/
│       └── .backups/                  # Update backups
```

## Shell Completions

```bash
# Add to ~/.bashrc or ~/.zshrc
source /path/to/.claude/scripts/completions/orchestrate.bash
```

## Tests

```bash
.claude/scripts/tests/test_runner.sh
```

## Agent Source

- [VoltAgent/awesome-claude-code-subagents](https://github.com/VoltAgent/awesome-claude-code-subagents)

## License

MIT

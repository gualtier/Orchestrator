# Claude Orchestrator v3.5

Claude agent orchestration system with **Spec-Driven Development**, **modular architecture**, and **specialized agents**.

## What's New

### v3.5 - Spec-Driven Development & Claude Code Skills

- **SDD (Spec-Driven Development)** - Full spec-first workflow inspired by [GitHub Spec-Kit](https://github.com/github/spec-kit)
- **Constitution system** - Editable project principles that govern spec-to-code transformation
- **Mandatory research gate** - `sdd plan` requires `research.md` to exist
- **Constitutional gates** - Automated compliance checks (research, simplicity, test-first, traceability)
- **SDD → Orchestrator bridge** - `sdd tasks` generates orchestrator tasks from plans
- **14 Claude Code Skills** - Native `/sdd-*` and `/orch-*` slash commands
- **Autonomous architect** - Claude auto-invokes skills to drive the full SDD pipeline

### v3.4 - Learning & Enhanced Monitoring

- **`learn` command** - Extract insights from completed tasks
- **Enhanced status** - Rich dashboard with progress bars, velocity, ETA
- **Watch mode** - Live auto-refreshing status updates (`status --watch`)
- **Activity tracking** - Real-time indicators (active/idle/stalled)

### v3.3 - Auto-Update & CLI

- **`update` command** - Update orchestrator from remote
- **`install-cli` command** - Install global shortcut (`orch`)
- **Automatic backup** - Creates backup before updating

### v3.2 - Memory Management

- **`update-memory --full`** - Auto-increment version + generate changelog

### v3.1 - Modularization

- Modular architecture (lib/ and commands/)
- `doctor` command, validation, JSON output, tests, shell completions

## Installation

```bash
# Copy to your project
cp -r orchestrator-v3/.claude ~/your-project/
cp orchestrator-v3/CLAUDE.md ~/your-project/

# Make executable
chmod +x ~/your-project/.claude/scripts/*.sh

# Initialize
cd ~/your-project
.claude/scripts/orchestrate.sh init
.claude/scripts/orchestrate.sh doctor

# (Optional) Install global CLI
.claude/scripts/orchestrate.sh install-cli
# Now you can use: orch status, orch help, etc.
```

## Claude Code Skills

The orchestrator integrates natively with Claude Code through **14 skills** (slash commands):

### SDD Skills

| Skill | Description | Auto |
|-------|-------------|------|
| `/sdd` | Hub - shows status, workflow, constitution | Yes |
| `/sdd-init` | Initialize SDD structure with templates | No |
| `/sdd-specify "desc"` | Create spec from feature description | Yes |
| `/sdd-research 001` | Fill mandatory research document | Yes |
| `/sdd-plan 001` | Create technical plan with worktree mapping | Yes |
| `/sdd-gate 001` | Check constitutional gates | Yes |
| `/sdd-tasks 001` | Generate orchestrator tasks from plan | Yes |
| `/sdd-status` | Show spec lifecycle status | Yes |
| `/sdd-archive 001` | Archive completed spec | No |

### Orchestrator Skills

| Skill | Description | Auto |
|-------|-------------|------|
| `/orch` | Hub - shows agent status and workflow | Yes |
| `/orch-setup name --preset p` | Create worktree with agents | Yes |
| `/orch-start` | Start agents in worktrees | Yes |
| `/orch-status` | Monitor agent progress | Yes |
| `/orch-merge` | Merge and cleanup | No |

**Auto = Yes** means Claude can invoke the skill autonomously as part of the architect workflow. **No** means user-only (destructive/one-time actions).

## Quick Start

### SDD-First Workflow (Recommended)

For medium/large features, use Spec-Driven Development:

```bash
# 1. Initialize SDD (first time only)
orch sdd init

# 2. Create specification
orch sdd specify "User authentication with OAuth and JWT"
# ... Claude refines spec.md ...

# 3. Research (MANDATORY before planning)
orch sdd research 001
# ... Claude investigates libs, benchmarks, security ...

# 4. Plan & verify
orch sdd plan 001
orch sdd gate 001

# 5. Generate tasks & execute
orch sdd tasks 001
orch setup auth --preset auth
orch setup api --preset api
orch start
orch wait

# 6. Verify & merge
orch verify-all
orch merge
orch sdd archive 001
orch update-memory --full
```

Or use Claude Code Skills directly:

```bash
/sdd-specify "User authentication with OAuth and JWT"
```

### Direct Workflow (Small tasks)

```bash
orch setup auth --preset auth
orch start
orch wait
orch merge
orch update-memory --full
```

## SDD Pipeline

```text
Constitution → Specify → Research (MANDATORY) → Plan → Gate → Tasks
                                                                 ↓
                                              Setup → Start → Wait → Merge → Archive
```

### SDD Artifacts

```text
.claude/specs/
├── constitution.md           # Project principles (fully editable)
├── templates/                # Reusable templates (spec, research, plan, task)
├── active/                   # Active specs in development
│   └── 001-feature-name/
│       ├── spec.md           # WHAT: requirements, user stories, acceptance criteria
│       ├── research.md       # WHY: library analysis, benchmarks, security, patterns
│       ├── plan.md           # HOW: architecture, tech decisions, worktree mapping
│       └── tasks.md          # Generated bridge to orchestration/tasks/
└── archive/                  # Completed specs (history)
```

### Constitutional Gates

`orch sdd gate <number>` checks:

1. **Research-First** - research.md exists and is substantive
2. **Simplicity** - Maximum 3 initial modules
3. **Test-First** - Test strategy defined in plan
4. **Spec Traceability** - REQ- markers in spec.md

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
| `backend`  | backend-developer, api-designer, database-administrator     | General backend|
| `database` | database-administrator, postgres-pro, sql-pro               | Database       |

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

### SDD (Spec-Driven Development)

```bash
orch sdd init                # Initialize SDD structure
orch sdd constitution        # Show/create constitution
orch sdd specify "desc"      # Create new spec
orch sdd research <number>   # Create research doc (MANDATORY)
orch sdd plan <number>       # Create plan (requires research)
orch sdd gate <number>       # Check constitutional gates
orch sdd tasks <number>      # Generate orchestrator tasks
orch sdd status              # Show active specs
orch sdd archive <number>    # Archive completed spec
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
orch status                # Standard status
orch status --enhanced     # Rich dashboard
orch status --watch        # Live auto-refresh
orch status --compact      # One-line per agent
orch status --json         # JSON output
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
orch cleanup             # Clean up worktrees
```

### Memory & Learning

```bash
orch show-memory                  # Show memory
orch update-memory --full         # Bump version + changelog
orch learn extract                # Extract from last 5 tasks
orch learn extract --all          # Extract from all archived
orch learn review                 # Review pending learnings
orch learn show                   # Show current learnings
```

## Global CLI

```bash
# Install (requires sudo)
.claude/scripts/orchestrate.sh install-cli

# Works in any project directory
cd ~/projects/my-app && orch status
cd ~/projects/other-app && orch status
```

## Structure

```text
project/
├── CLAUDE.md                          # Architect instructions
├── .claude/
│   ├── PROJECT_MEMORY.md              # Project memory
│   ├── AGENT_CLAUDE_BASE.md           # Agent base instructions
│   ├── agents/                        # Installed agents (VoltAgent)
│   ├── skills/                        # Claude Code Skills
│   │   ├── sdd*/SKILL.md             # SDD skills (8)
│   │   ├── orch*/SKILL.md            # Orchestrator skills (4)
│   │   ├── sdd/SKILL.md              # SDD hub
│   │   └── orch/SKILL.md             # Orchestrator hub
│   ├── specs/                         # SDD specifications
│   │   ├── constitution.md            # Project principles
│   │   ├── templates/                 # Spec templates
│   │   ├── active/                    # Active specs
│   │   └── archive/                   # Completed specs
│   ├── scripts/
│   │   ├── orchestrate.sh             # Entry point
│   │   ├── lib/                       # Libraries (9 modules)
│   │   ├── commands/                  # Commands (11 modules)
│   │   ├── tests/                     # Test framework
│   │   └── completions/               # Shell completions
│   └── orchestration/
│       ├── tasks/                     # Task files
│       ├── examples/                  # Task examples
│       └── logs/                      # Agent logs
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

## Inspiration

- [GitHub Spec-Kit](https://github.com/github/spec-kit) - Spec-Driven Development methodology

## License

MIT

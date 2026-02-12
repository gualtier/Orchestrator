# Claude Orchestrator v3.6

Claude agent orchestration system with **Spec-Driven Development**, **active error monitoring**, and **specialized agents**.

## How It Works in Practice

You just describe what you want. Claude handles the rest autonomously.

### Example 1: Large Feature

```text
You:   I need a payment system with Stripe, webhooks, and subscriptions

Claude: Starting SDD flow for this feature.

        → /sdd-specify creates spec with requirements and acceptance criteria
        → /sdd-research investigates Stripe SDK, webhook security, pricing patterns
        → /sdd-plan designs architecture with 3 modules:
            | Module   | Worktree | Preset  |
            | Payments | payments | api     |
            | Webhooks | webhooks | backend |
            | Billing  | billing  | fullstack |
        → /sdd-gate checks constitutional compliance (all pass)
        → /sdd-tasks generates task files for each module
        → /orch-setup creates 3 isolated worktrees
        → /orch-start launches 9 specialized agents in parallel

        ... agents work independently ...

        → /orch-errors detects issues in real-time:
            ⚠ webhooks: TypeError in handler.ts:42
              → Check null handling in webhook payload parser

        → /orch-status shows progress:
            payments: ██████████ 100% ✅
            webhooks: ████████░░  80% 🔄 (1 warning)
            billing:  ██████░░░░  60% 🔄

        All worktrees complete. Run /orch-merge when ready.

You:   /orch-merge
```

### Example 2: Small Task (No SDD Needed)

```text
You:   Add a health check endpoint to the API

Claude: Small task (1 file), implementing directly.
        → Creates GET /health endpoint
        → Adds test
        → Commits and updates memory
```

### Example 3: Check Status Anytime

```text
You:   /sdd-status

Claude: ACTIVE SPECS:
          001-payment-system  [executing]  → 2/3 worktrees merged
          002-user-dashboard  [planned]    → tasks pending

You:   /orch-status

Claude: WORKTREES:
          payments  ✅ merged
          webhooks  ✅ merged
          billing   🔄 in progress (2 agents working)
```

### Example 4: Fully Autonomous

```text
You:   Users need to export their data as CSV and PDF

Claude: → Specifies, researches, plans, generates tasks
        → Sets up worktree with backend agents
        → Starts agents, monitors progress
        → Notifies you when done and ready to merge
```

Claude decides when to use SDD (multi-module features) vs direct execution (small tasks). You only intervene for destructive actions like `/orch-merge` and `/sdd-archive`.

## What's New

### v3.6 - Active Error Monitoring

- **Error detection engine** - Incremental byte-offset log polling catches errors as they happen (~5-25ms per agent)
- **3-tier severity classification** - CRITICAL / WARNING / INFO with color-coded display
- **Corrective action suggestions** - Each error type includes actionable fix recommendations
- **Error dashboard** - `orch errors` with `--watch`, `--agent`, `--recent`, `--clear` modes
- **Integrated monitoring** - Error counts in `status`, real-time notifications during `wait` and `--watch`
- **`/orch-errors` skill** - Claude Code slash command for error dashboard access
- **15 Claude Code Skills** - Now includes error monitoring alongside SDD and orchestration

### v3.5 - Spec-Driven Development & Claude Code Skills

- **SDD (Spec-Driven Development)** - Full spec-first workflow inspired by [GitHub Spec-Kit](https://github.com/github/spec-kit)
- **Constitution system** - Editable project principles that govern spec-to-code transformation
- **Mandatory research gate** - `sdd plan` requires `research.md` to exist
- **Constitutional gates** - Automated compliance checks (research, simplicity, test-first, traceability)
- **SDD → Orchestrator bridge** - `sdd tasks` generates orchestrator tasks from plans
- **Claude Code Skills** - Native `/sdd-*` and `/orch-*` slash commands
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

The orchestrator integrates natively with Claude Code through **15 skills** (slash commands):

### SDD Skills

| Skill | Description | Auto |
| ----- | ----------- | ---- |
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
| ----- | ----------- | ---- |
| `/orch` | Hub - shows agent status and workflow | Yes |
| `/orch-setup name --preset p` | Create worktree with agents | Yes |
| `/orch-start` | Start agents in worktrees | Yes |
| `/orch-status` | Monitor agent progress | Yes |
| `/orch-errors` | Error monitoring dashboard | Yes |
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
orch errors                # Error monitoring dashboard
orch errors --watch        # Live error monitoring (auto-refresh)
orch errors --agent <name> # Filter errors by agent
orch errors --recent       # Show last 50 errors with details
orch errors --clear        # Clear error tracking
orch wait                  # Wait with live updates + error notifications
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

Claude Code sessions are stateless - every new conversation starts from zero. Memory fixes this.

`PROJECT_MEMORY.md` gives Claude instant context about your project: architecture, resolved problems, lessons learned, conventions, and what happened in previous sessions. Without it, Claude rediscovers your project every time, repeats solved mistakes, and asks the same questions.

```text
Session 1: Claude discovers macOS `head -n` behaves differently than Linux
           → update-memory records this as a resolved problem

Session 2: Claude reads memory, already knows about the macOS quirk
           → writes compatible code from the start
```

The `learn` command goes further - it extracts patterns and insights from completed tasks and feeds them back into memory automatically.

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

## Hooks

The orchestrator uses [Claude Code hooks](https://code.claude.com/docs/en/hooks-guide) to automate workflow enforcement. Configured in `.claude/settings.json`:

| Hook | Event | What it does |
| ---- | ----- | ------------ |
| Re-inject context | `SessionStart` (compact) | Re-injects `PROJECT_MEMORY.md` + `CAPABILITIES.md` after context compaction so Rule #1 survives long sessions |
| Memory & merge check | `Stop` (prompt) | Blocks if: (1) commits made without `update-memory`, or (2) merge done without `update-memory --full` and `learn extract` |
| Task completion check | `Stop` (prompt) | Blocks if there are clearly unfinished tasks |
| Self-dev docs sync | `Stop` (command) | **Source repo only**: blocks if scripts/skills changed without updating CAPABILITIES.md, version bumped without changelog, or commands changed without README update |

The prompt-based hooks use a lightweight model (Haiku) to evaluate conditions with judgment rather than rigid rules. The self-dev docs sync hook only activates in the orchestrator source repository (detected by git origin URL) and is silent in client projects.

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
│   │   ├── orch*/SKILL.md            # Orchestrator skills (5)
│   │   ├── sdd/SKILL.md              # SDD hub
│   │   └── orch/SKILL.md             # Orchestrator hub
│   ├── specs/                         # SDD specifications
│   │   ├── constitution.md            # Project principles
│   │   ├── templates/                 # Spec templates
│   │   ├── active/                    # Active specs
│   │   └── archive/                   # Completed specs
│   ├── scripts/
│   │   ├── orchestrate.sh             # Entry point
│   │   ├── lib/                       # Libraries (10 modules)
│   │   ├── commands/                  # Commands (12 modules)
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

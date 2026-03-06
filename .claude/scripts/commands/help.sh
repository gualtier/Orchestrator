#!/bin/bash
# =============================================
# COMMAND: help
# =============================================

cmd_help() {
    cat << 'EOF'

CLAUDE AGENT ORCHESTRATOR v3.10.1
   SDD + TDD + Ralph Loops

Usage: orchestrate.sh <command> [arguments]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

AGENTS:
  agents list               List available agents
  agents install <agent>    Install agent
  agents install-preset <p> Install agent preset
  agents installed          View installed agents

INITIALIZATION:
  init                      Create structure
  init-sample               Copy example tasks
  install-cli [name]        Install global command (default: orch)
  uninstall-cli [name]      Remove global command
  doctor                    Diagnose problems
  doctor --fix              Fix problems automatically

EXECUTION:
  setup <name> [options]    Create worktree with agents
    --preset <preset>       Use agent preset
    --agents <a1,a2,a3>     Specify agents
    --from <branch>         Source branch

  start [agents] [options]  Start agents (async by default)
    --no-monitor            Don't block (RECOMMENDED — async-first)
    --ralph                 Force ralph loops on all agents
    --no-ralph              Force single-shot mode (no loops)
    --max-iterations N      Override max iterations for ralph loops
    --timeout N             Stop after N minutes
  stop <agent> [--force]    Stop agent (cancels ralph loop if active)
  restart <agent>           Restart agent
  cancel-ralph [agent]      Cancel ralph loop (single agent or all)

MONITORING:
  status                    Show status (standard text format)
  status --enhanced|-e      Show status with progress bars, activity, errors
  status --compact|-c       Compact format (one line per agent)
  status --json             Show status (JSON format)
  errors                    Error monitoring dashboard
  errors --agent <name>     Filter errors by agent
  errors --recent           Show last 50 errors with details
  errors --clear            Clear error tracking
  logs <agent> [n]          Show last n log lines
  follow <agent>            Follow logs in real time

AGENT TEAMS (v3.8):
  team start <spec-number>  Start Agent Team from SDD spec
  team status               Show team progress (teammates, tasks)
  team stop                 Stop running team

VERIFICATION AND QUALITY:
  verify <worktree>         Verify worktree (runs tests as gate)
  verify-all                Verify all worktrees (runs tests as gate)
                            Options: --skip-tests
  review <worktree>         Create review worktree
  pre-merge                 Check before merge
  report                    Generate consolidated report

FINALIZATION:
  merge [branch]            Merge (default: main)
  cleanup                   Clean up worktrees (archives artifacts)

MEMORY:
  show-memory               View project memory
  update-memory [options]   Update project memory
    --bump                  Increment version (X.Y → X.Y+1)
    --changelog             Generate changelog from recent commits
    --commits <n>           Number of commits in changelog (default: 5)
    --full                  Equivalent to --bump --changelog

LEARNING:
  learn extract [options]   Extract insights from completed tasks
    --last N                Extract from last N tasks (default: 5)
    --all                   Extract from all archived tasks
    --apply                 Apply automatically without review
  learn review              Review pending learnings
  learn add-role <file>     Add agent role to CLAUDE.md
    --name "Name"           Name for the external role
  learn show                Show current learnings section

SDD (SPEC-DRIVEN DEVELOPMENT):
  sdd init                  Initialize SDD structure with templates
  sdd constitution          Show/create project constitution
  sdd specify "desc"        Create a new spec from description
  sdd research <number>     Create research doc (MANDATORY before plan)
  sdd plan <number>         Create implementation plan (requires research)
  sdd gate <number>         Check constitutional gates
  sdd run [number]          Autopilot: gate→tasks→setup→start→monitor
    --auto-merge            Full hands-off (merge + archive automatic)
    --mode teams            Use Agent Teams backend
    --no-ralph              Single-shot mode (no iterative loops)
  sdd tasks <number>        Generate orchestrator tasks from plan
  sdd status                Show all active specs
  sdd archive <number>      Archive completed spec
  sdd help                  Show SDD help

UPDATE:
  update                    Update orchestrator from remote
  update-check              Check if updates are available

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

AGENT PRESETS:
  auth      → backend-developer, security-auditor, typescript-pro
  api       → api-designer, backend-developer, test-automator
  frontend  → frontend-developer, react-specialist, ui-designer
  fullstack → fullstack-developer, typescript-pro, test-automator
  mobile    → mobile-developer, flutter-expert, ui-designer
  devops    → devops-engineer, kubernetes-specialist, terraform-engineer
  data      → data-engineer, data-scientist, postgres-pro
  ml        → ml-engineer, ai-engineer, mlops-engineer
  security  → security-auditor, penetration-tester, security-engineer
  review    → code-reviewer, architect-reviewer, security-auditor
  backend   → backend-developer, api-designer, database-administrator
  database  → database-administrator, postgres-pro, sql-pro

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

TRI-METHODOLOGY (all on by default):
  SDD    → What to build (spec → research → plan → gate)
  TDD    → Prove it works (agents write tests FIRST, then implement)
  Ralph  → Iterate until done (self-correcting loops with test gates)

  Flow: SDD defines requirements → agents write failing tests (TDD) →
        implement to pass → ralph loop re-runs tests as gates →
        self-correct on failure → converge to completion

RALPH LOOPS:
  Agents run in iterative self-correcting loops by default.
  Each iteration: prompt → execute → check completion → run gates.
  If gates fail, feedback is injected and agent tries again.

  Per-task config in task frontmatter:
    > ralph: true|false       Enable/disable per task
    > max-iterations: 20      Max loop iterations
    > stall-threshold: 3      Stop after N stalled iterations
    > gates: npm test, lint   Quality checks (auto-detected if empty)
    > completion-signal: RALPH_COMPLETE

TDD (TEST-DRIVEN DEVELOPMENT):
  Agents write failing tests before implementation by default.
  Test runner auto-detected as ralph gate when no gates configured.
  Supported: npm test, vitest, jest, pytest, go test, cargo test, make test

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

EXAMPLE (RECOMMENDED — SDD + TDD + Ralph):

  # 1. Initialize and create spec
  ./orchestrate.sh sdd init
  ./orchestrate.sh sdd specify "User authentication with OAuth"

  # 2. Research (MANDATORY) and plan
  ./orchestrate.sh sdd research 001
  ./orchestrate.sh sdd plan 001
  ./orchestrate.sh sdd gate 001

  # 3. Autopilot (agents write tests first, ralph loops self-correct)
  ./orchestrate.sh sdd run 001              # Manual merge after
  ./orchestrate.sh sdd run 001 --auto-merge # Fully autonomous

  # 4. Monitor (async — poll every 30s)
  ./orchestrate.sh status
  ./orchestrate.sh errors

  # 5. Finalize
  ./orchestrate.sh merge
  ./orchestrate.sh update-memory --full

EXAMPLE (DIRECT MODE — Small tasks):

  ./orchestrate.sh init
  ./orchestrate.sh setup auth --preset auth
  ./orchestrate.sh start --no-monitor
  # poll: status + errors every 30s
  ./orchestrate.sh merge
  ./orchestrate.sh update-memory --full

EOF
}

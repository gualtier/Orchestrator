#!/bin/bash
# =============================================
# COMMAND: help
# =============================================

cmd_help() {
    cat << 'EOF'

CLAUDE AGENT ORCHESTRATOR v3.1
   With Specialized Agents

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

  start [agents]            Start agents
  stop <agent> [--force]    Stop agent
  restart <agent>           Restart agent

MONITORING:
  status                    Show status (standard text format)
  status --enhanced|-e      Show status with advanced details
  status --watch|-w [N]     Live update (interval N seconds)
  status --compact|-c       Compact format (one line per agent)
  status --json             Show status (JSON format)
  wait [interval]           Wait for completion (with watch mode)
  logs <agent> [n]          Show last n log lines
  follow <agent>            Follow logs in real time

VERIFICATION AND QUALITY:
  verify <worktree>         Verify worktree
  verify-all                Verify all worktrees
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
  sdd run [number]          Autopilot: gate -> tasks -> setup -> start -> monitor
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

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

EXAMPLE (SDD-FIRST WORKFLOW - Recommended):

  # 1. Initialize
  ./orchestrate.sh sdd init

  # 2. Create spec
  ./orchestrate.sh sdd specify "User authentication with OAuth"
  # ... refine spec.md with Claude ...

  # 3. Research (MANDATORY)
  ./orchestrate.sh sdd research 001
  # ... fill research.md with Claude ...

  # 4. Plan & verify
  ./orchestrate.sh sdd plan 001
  # ... refine plan.md with Claude ...
  ./orchestrate.sh sdd gate 001

  # 5a. Autopilot (gate -> tasks -> setup -> start -> monitor):
  ./orchestrate.sh sdd run 001    # Single spec
  ./orchestrate.sh sdd run        # All planned specs

  # 5b. OR manual step-by-step:
  ./orchestrate.sh sdd tasks 001
  ./orchestrate.sh setup auth --preset auth
  ./orchestrate.sh start
  ./orchestrate.sh wait

  # 6. Verify & merge
  ./orchestrate.sh verify-all
  ./orchestrate.sh merge
  ./orchestrate.sh sdd archive 001
  ./orchestrate.sh update-memory --full

EXAMPLE (DIRECT MODE - Small tasks):

  ./orchestrate.sh init
  ./orchestrate.sh setup auth --preset auth
  ./orchestrate.sh start
  ./orchestrate.sh wait
  ./orchestrate.sh merge
  ./orchestrate.sh update-memory --full

EOF
}

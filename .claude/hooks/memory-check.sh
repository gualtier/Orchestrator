#!/bin/bash
# =============================================
# Memory/Merge Stop Hook (command-based)
# Replaces the prompt-based memory check hook
# Hook type: Stop (command) - outputs JSON {"ok": true/false, "reason": "..."}
#
# Checks after commits/merges whether update-memory was run.
# Bypasses when:
#   - SDD_AUTOPILOT=1 (autonomous pipeline handles post-run steps)
#   - Self-dev (origin URL contains "orchestrator")
#   - stop_hook_active is set in the conversation
# =============================================

# Source shared utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/hook-utils.sh"

# === Fast bypass: autopilot mode ===
if is_autopilot; then
  json_ok
  exit 0
fi

# === Fast bypass: self-dev ===
if is_self_dev; then
  json_ok
  exit 0
fi

# === Read conversation context from stdin ===
# Stop hooks receive JSON with conversation context on stdin
INPUT=$(cat)

# Check for stop_hook_active flag
if echo "$INPUT" | grep -q '"stop_hook_active"' 2>/dev/null; then
  if echo "$INPUT" | grep -q '"stop_hook_active"[[:space:]]*:[[:space:]]*true' 2>/dev/null; then
    json_ok
    exit 0
  fi
fi

# === Check recent git activity ===
# Look at the last few commits to see if update-memory was run after changes

# Check if there were recent commits (last 5 minutes)
recent_commit_time=$(git -C "$HOOK_PROJECT_DIR" log -1 --format="%ct" 2>/dev/null || echo "0")
current_time=$(date +%s)
time_diff=$(( current_time - recent_commit_time ))

# If no recent commits (more than 5 min ago), no action needed
if [[ $time_diff -gt 300 ]]; then
  json_ok
  exit 0
fi

# Check if update-memory or PROJECT_MEMORY.md was touched recently
memory_commit_time=$(git -C "$HOOK_PROJECT_DIR" log -1 --format="%ct" -- ".claude/PROJECT_MEMORY.md" 2>/dev/null || echo "0")

# Check if there are commits after the last memory update
commits_after_memory=0
if [[ $memory_commit_time -gt 0 ]]; then
  commits_after_memory=$(git -C "$HOOK_PROJECT_DIR" log --oneline --after="@${memory_commit_time}" 2>/dev/null | wc -l | tr -d ' ')
  # Subtract 1 because the memory commit itself counts
  commits_after_memory=$(( commits_after_memory > 0 ? commits_after_memory - 1 : 0 ))
fi

# Check if PROJECT_MEMORY.md was modified in the working tree (manual edit in progress)
memory_modified=false
if git -C "$HOOK_PROJECT_DIR" diff --name-only 2>/dev/null | grep -q 'PROJECT_MEMORY.md'; then
  memory_modified=true
fi
if git -C "$HOOK_PROJECT_DIR" diff --cached --name-only 2>/dev/null | grep -q 'PROJECT_MEMORY.md'; then
  memory_modified=true
fi

# If memory was recently updated or is being edited, all good
if [[ $commits_after_memory -eq 0 ]] || [[ "$memory_modified" == "true" ]]; then
  json_ok
  exit 0
fi

# Check if a merge happened recently without post-merge steps
merge_in_log=false
if git -C "$HOOK_PROJECT_DIR" log -5 --oneline 2>/dev/null | grep -qi "merge\|Merge"; then
  merge_in_log=true
fi

if [[ "$merge_in_log" == "true" ]]; then
  # After merge, both update-memory --full and learn extract should run
  json_fail "Merge detected but update-memory --full was not run. Run: orchestrate.sh update-memory --full && orchestrate.sh learn extract"
  exit 0
fi

# Regular commits without update-memory
if [[ $commits_after_memory -gt 0 ]]; then
  json_fail "Commits were made without running update-memory. Run: orchestrate.sh update-memory"
  exit 0
fi

json_ok

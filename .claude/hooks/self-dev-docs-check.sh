#!/bin/bash
# Self-dev documentation sync check
# Only triggers when developing the orchestrator SOURCE CODE itself
# Hook type: Stop (command) - outputs JSON {"ok": true/false, "reason": "..."}
#
# Checks:
#   1. Scripts/skills/hooks modified → CAPABILITIES.md needs update
#   2. Version bumped → CHANGELOG needs update
#   3. Commands/skills committed → README.md may be stale
#   4. PROJECT_MEMORY.md version ≠ orchestrate.sh version → update.sh will show wrong version

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"

# Source shared utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/hook-utils.sh"

# Skip silently if not self-dev
if ! is_self_dev; then
  json_ok
  exit 0
fi

issues=()

# === Check 1: Scripts/skills/hooks modified → CAPABILITIES.md ===
# Covers both uncommitted and staged changes
has_script_changes() {
  local count=0
  count=$(( count + $(git -C "$PROJECT_DIR" diff --name-only 2>/dev/null | grep -cE '^\.claude/(scripts|skills|hooks)/') ))
  count=$(( count + $(git -C "$PROJECT_DIR" diff --cached --name-only 2>/dev/null | grep -cE '^\.claude/(scripts|skills|hooks)/') ))
  [[ "$count" -gt 0 ]]
}

has_caps_changes() {
  git -C "$PROJECT_DIR" diff --name-only 2>/dev/null | grep -q 'CAPABILITIES.md' && return 0
  git -C "$PROJECT_DIR" diff --cached --name-only 2>/dev/null | grep -q 'CAPABILITIES.md' && return 0
  return 1
}

if has_script_changes && ! has_caps_changes; then
  issues+=("Scripts/skills/hooks were modified but CAPABILITIES.md was not updated")
fi

# === Check 2: Version bumped in memory → CHANGELOG needed ===
version_bumped=false
if git -C "$PROJECT_DIR" diff -- ".claude/PROJECT_MEMORY.md" 2>/dev/null | grep -qE '^\+.*Vers'; then
  version_bumped=true
fi
if git -C "$PROJECT_DIR" diff --cached -- ".claude/PROJECT_MEMORY.md" 2>/dev/null | grep -qE '^\+.*Vers'; then
  version_bumped=true
fi

if $version_bumped; then
  has_changelog=false
  git -C "$PROJECT_DIR" diff --name-only 2>/dev/null | grep -q 'CHANGELOG' && has_changelog=true
  git -C "$PROJECT_DIR" diff --cached --name-only 2>/dev/null | grep -q 'CHANGELOG' && has_changelog=true
  if ! $has_changelog; then
    issues+=("Version was bumped but CHANGELOG was not updated. Run: orch update-memory --changelog")
  fi
fi

# === Check 3: Commands/skills committed more recently than README ===
last_cmd_ts=$(git -C "$PROJECT_DIR" log -1 --format="%ct" -- ".claude/scripts/commands/" ".claude/skills/" 2>/dev/null || echo "0")
last_readme_ts=$(git -C "$PROJECT_DIR" log -1 --format="%ct" -- "README.md" 2>/dev/null || echo "0")

if [[ "${last_cmd_ts:-0}" -gt "${last_readme_ts:-0}" ]]; then
  # Only flag if the difference is from recent commits (last 5)
  recent=$(git -C "$PROJECT_DIR" log -5 --format="%H" -- ".claude/scripts/commands/" ".claude/skills/" 2>/dev/null | head -1)
  if [[ -n "$recent" ]]; then
    issues+=("README.md may be stale (commands/skills were updated more recently)")
  fi
fi

# === Check 4: PROJECT_MEMORY.md version vs orchestrate.sh header version ===
memory_version=$(grep -oE 'Version.*: [0-9]+\.[0-9]+' "$PROJECT_DIR/.claude/PROJECT_MEMORY.md" 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -1)
script_version=$(grep -oE 'v[0-9]+\.[0-9]+' "$PROJECT_DIR/.claude/scripts/orchestrate.sh" 2>/dev/null | head -1 | tr -d 'v')

if [[ -n "$memory_version" ]] && [[ -n "$script_version" ]] && [[ "$memory_version" != "$script_version" ]]; then
  issues+=("orchestrate.sh header says v${script_version} but PROJECT_MEMORY.md says v${memory_version}. Update the version in orchestrate.sh and the WHAT'S NEW section in update.sh")
fi

# === Output ===
if [[ ${#issues[@]} -gt 0 ]]; then
  reason=$(printf '%s; ' "${issues[@]}")
  reason="${reason%; }"
  json_fail "[Self-dev] ${reason}"
else
  json_ok
fi

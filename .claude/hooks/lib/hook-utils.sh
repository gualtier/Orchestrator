#!/bin/bash
# =============================================
# Shared Hook Utilities
# Sourced by all command hooks for consistent detection
# =============================================

# Project directory (set by Claude Code hooks)
HOOK_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"

# === Self-dev detection ===
# The orchestrator source repo has "orchestrator" in its origin URL.
# Client projects that USE the orchestrator do not.
is_self_dev() {
  local origin_url
  origin_url=$(git -C "$HOOK_PROJECT_DIR" remote get-url origin 2>/dev/null)
  # Case-insensitive match (origin URL may have "Orchestrator" or "orchestrator")
  local lower_url
  lower_url=$(echo "$origin_url" | tr '[:upper:]' '[:lower:]')
  [[ "$lower_url" == *"orchestrator"* ]]
}

# === Autopilot detection ===
# When SDD_AUTOPILOT=1 is set, hooks should pass through without blocking.
# This env var is set by cmd_sdd_run in the autopilot pipeline.
is_autopilot() {
  [[ "${SDD_AUTOPILOT:-}" == "1" ]]
}

# === JSON output helpers ===
json_ok() {
  echo '{"ok": true}'
}

json_fail() {
  local reason="$1"
  # Escape quotes for JSON
  reason="${reason//\"/\\\"}"
  echo "{\"ok\": false, \"reason\": \"${reason}\"}"
}

#!/bin/bash
# Re-inject project memory and capabilities after context compaction
# Ensures Rule #1 context survives long sessions

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"

echo "## Re-injected after context compaction"
echo ""

if [[ -f "$PROJECT_DIR/.claude/PROJECT_MEMORY.md" ]]; then
  cat "$PROJECT_DIR/.claude/PROJECT_MEMORY.md"
  echo ""
fi

if [[ -f "$PROJECT_DIR/.claude/CAPABILITIES.md" ]]; then
  cat "$PROJECT_DIR/.claude/CAPABILITIES.md"
  echo ""
fi

echo "---"
echo "IMPORTANT: Always run 'update-memory' after making commits."

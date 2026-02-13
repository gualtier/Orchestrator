#!/bin/bash
# =============================================
# TeammateIdle Hook
# Prevents teammates from going idle without completing their task
# Exit code 2 = prevent idle with feedback
# Exit code 0 = allow idle
# =============================================

# Read input JSON from stdin
INPUT=$(cat)

# Parse fields from JSON
TEAMMATE_NAME=$(echo "$INPUT" | grep -o '"teammate_name"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"\([^"]*\)"$/\1/')
TEAM_NAME=$(echo "$INPUT" | grep -o '"team_name"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"\([^"]*\)"$/\1/')
CWD=$(echo "$INPUT" | grep -o '"cwd"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"\([^"]*\)"$/\1/')

# Default to allow idle if we can't parse
if [[ -z "$TEAMMATE_NAME" ]]; then
    exit 0
fi

# Change to project directory
if [[ -n "$CWD" ]]; then
    cd "$CWD" 2>/dev/null || exit 0
fi

# Check if teammate has a feature branch with commits
BRANCH_NAME="feature/${TEAMMATE_NAME}"
HAS_COMMITS=false

if git rev-parse --verify "$BRANCH_NAME" >/dev/null 2>&1; then
    # Check if branch has commits ahead of main
    COMMIT_COUNT=$(git log --oneline main.."$BRANCH_NAME" 2>/dev/null | wc -l | tr -d ' ')
    if [[ $COMMIT_COUNT -gt 0 ]]; then
        HAS_COMMITS=true
    fi
fi

# Check if DONE.md exists in the project
HAS_DONE=false
if [[ -f "DONE.md" ]]; then
    HAS_DONE=true
fi

# Check if there are uncommitted changes
HAS_UNCOMMITTED=false
if [[ -n $(git status --porcelain 2>/dev/null) ]]; then
    HAS_UNCOMMITTED=true
fi

# Decision logic
if [[ "$HAS_DONE" == "true" ]]; then
    # Task is complete, allow idle
    exit 0
fi

if [[ "$HAS_COMMITS" == "false" ]]; then
    # No commits yet - don't allow idle
    echo "You haven't made any commits yet. Please continue working on your assigned task and make commits before finishing. Create your feature branch with: git checkout -b feature/${TEAMMATE_NAME}" >&2
    exit 2
fi

if [[ "$HAS_UNCOMMITTED" == "true" ]]; then
    # Has uncommitted changes - don't allow idle
    echo "You have uncommitted changes. Please commit your work before finishing." >&2
    exit 2
fi

# Check if DONE.md is missing but has commits
if [[ "$HAS_DONE" == "false" ]] && [[ "$HAS_COMMITS" == "true" ]]; then
    echo "You've made commits but haven't created DONE.md yet. Please create DONE.md with a summary of your work, modified files, and testing instructions before finishing." >&2
    exit 2
fi

# All checks passed, allow idle
exit 0

#!/bin/bash
# =============================================
# TaskCompleted Hook
# Validates work before allowing task to be marked as completed
# Exit code 2 = prevent completion with feedback
# Exit code 0 = allow completion
# =============================================

# Read input JSON from stdin
INPUT=$(cat)

# Parse fields from JSON
TASK_ID=$(echo "$INPUT" | grep -o '"task_id"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"\([^"]*\)"$/\1/')
TASK_SUBJECT=$(echo "$INPUT" | grep -o '"task_subject"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"\([^"]*\)"$/\1/')
TEAMMATE_NAME=$(echo "$INPUT" | grep -o '"teammate_name"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"\([^"]*\)"$/\1/')
TEAM_NAME=$(echo "$INPUT" | grep -o '"team_name"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"\([^"]*\)"$/\1/')
CWD=$(echo "$INPUT" | grep -o '"cwd"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"\([^"]*\)"$/\1/')

# Default to allow completion if we can't parse
if [[ -z "$TEAMMATE_NAME" ]] && [[ -z "$TASK_ID" ]]; then
    exit 0
fi

# Change to project directory
if [[ -n "$CWD" ]]; then
    cd "$CWD" 2>/dev/null || exit 0
fi

# Validation checks
ERRORS=()

# Check 1: Has commits on feature branch
if [[ -n "$TEAMMATE_NAME" ]]; then
    BRANCH_NAME="feature/${TEAMMATE_NAME}"
    if git rev-parse --verify "$BRANCH_NAME" >/dev/null 2>&1; then
        COMMIT_COUNT=$(git log --oneline main.."$BRANCH_NAME" 2>/dev/null | wc -l | tr -d ' ')
        if [[ $COMMIT_COUNT -eq 0 ]]; then
            ERRORS+=("No commits found on branch $BRANCH_NAME")
        fi
    else
        # Check current branch if feature branch doesn't exist
        CURRENT_BRANCH=$(git branch --show-current 2>/dev/null)
        if [[ "$CURRENT_BRANCH" != "main" ]] && [[ "$CURRENT_BRANCH" != "master" ]]; then
            COMMIT_COUNT=$(git log --oneline main.."$CURRENT_BRANCH" 2>/dev/null | wc -l | tr -d ' ')
            if [[ $COMMIT_COUNT -eq 0 ]]; then
                ERRORS+=("No commits found on current branch")
            fi
        else
            ERRORS+=("Work should be on a feature branch, not main/master")
        fi
    fi
fi

# Check 2: No uncommitted changes
if [[ -n $(git status --porcelain 2>/dev/null) ]]; then
    ERRORS+=("Uncommitted changes detected - please commit all work")
fi

# Check 3: DONE.md exists
if [[ ! -f "DONE.md" ]]; then
    ERRORS+=("DONE.md not found - create it with: summary, modified files, and test instructions")
fi

# Check 4: DONE.md has required sections
if [[ -f "DONE.md" ]]; then
    if ! grep -qi "summary\|completed\|what was done" "DONE.md"; then
        ERRORS+=("DONE.md missing summary section")
    fi
    if ! grep -qi "modified\|changed\|files" "DONE.md"; then
        ERRORS+=("DONE.md missing modified files list")
    fi
fi

# Return results
if [[ ${#ERRORS[@]} -gt 0 ]]; then
    echo "Task completion validation failed:" >&2
    for error in "${ERRORS[@]}"; do
        echo "  - $error" >&2
    done
    echo "" >&2
    echo "Please address these issues before marking the task as complete." >&2
    exit 2
fi

# All checks passed
exit 0

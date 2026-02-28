#!/bin/bash
# =============================================
# GIT - Git and Worktree Operations
# =============================================

# =============================================
# REPOSITORY INFORMATION
# =============================================

is_git_clean() {
    git diff --quiet HEAD 2>/dev/null && git diff --cached --quiet HEAD 2>/dev/null
}

current_branch() {
    git branch --show-current 2>/dev/null || echo "main"
}

default_branch() {
    git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main"
}

branch_exists() {
    local branch=$1
    git show-ref --verify --quiet "refs/heads/$branch" 2>/dev/null
}

# =============================================
# WORKTREE OPERATIONS
# =============================================

# List orchestrator worktrees
list_worktrees() {
    local prefix="${PROJECT_NAME}-"

    git worktree list 2>/dev/null | while read -r line; do
        local path=$(echo "$line" | awk '{print $1}')
        local name=$(basename "$path")

        # Filter only orchestrator worktrees
        if [[ "$name" == "$prefix"* ]]; then
            echo "${name#$prefix}"
        fi
    done
}

# Check if worktree exists
worktree_exists() {
    local name=$1
    local worktree_path=$(get_worktree_path "$name")
    dir_exists "$worktree_path"
}

# Create worktree
create_git_worktree() {
    local name=$1
    local from_branch=${2:-$(current_branch)}
    local worktree_path=$(get_worktree_path "$name")
    local branch="feature/$name"

    # Validate name
    validate_name "$name" "worktree" || return 1

    # Check if already exists
    if worktree_exists "$name"; then
        log_warn "Worktree already exists: $name"
        return 0
    fi

    # Check source branch
    if ! branch_exists "$from_branch"; then
        log_error "Source branch does not exist: $from_branch"
        return 1
    fi

    log_info "Creating worktree: $name (from $from_branch)"

    # Mark for cleanup in case of error
    CLEANUP_NEEDED=true
    CLEANUP_WORKTREE="$worktree_path"

    # Create branch and worktree
    if branch_exists "$branch"; then
        log_info "Branch $branch already exists, using existing"
        git worktree add "$worktree_path" "$branch" || {
            log_error "Failed to create worktree"
            return 1
        }
    else
        git worktree add -b "$branch" "$worktree_path" "$from_branch" || {
            log_error "Failed to create worktree"
            return 1
        }
    fi

    # Clear cleanup flag
    CLEANUP_NEEDED=false
    CLEANUP_WORKTREE=""

    log_success "Worktree created: $worktree_path"
    return 0
}

# Remove worktree
remove_git_worktree() {
    local name=$1
    local force=${2:-false}
    local worktree_path=$(get_worktree_path "$name")

    if ! worktree_exists "$name"; then
        log_warn "Worktree does not exist: $name"
        return 0
    fi

    # Check for uncommitted changes
    if [[ "$force" != "true" ]]; then
        local uncommitted=$(cd "$worktree_path" && git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
        if [[ $uncommitted -gt 0 ]]; then
            log_warn "Worktree has $uncommitted uncommitted file(s)"
            if ! confirm "Remove anyway? Changes will be lost."; then
                return 1
            fi
        fi
    fi

    log_info "Removing worktree: $name"

    git worktree remove "$worktree_path" --force 2>/dev/null || {
        log_error "Failed to remove worktree"
        return 1
    }

    log_success "Worktree removed: $name"
    return 0
}

# =============================================
# MERGE OPERATIONS
# =============================================

# Simulate merge to check for conflicts
simulate_merge() {
    local branch=$1
    local target=${2:-main}

    if ! branch_exists "$branch"; then
        log_error "Branch does not exist: $branch"
        return 1
    fi

    # Create temporary branch
    local temp_branch="merge-test-$(date +%s)"
    git checkout -b "$temp_branch" "$target" 2>/dev/null || return 1

    # Try merge
    if git merge --no-commit --no-ff "$branch" 2>/dev/null; then
        git merge --abort 2>/dev/null || true
        git checkout - 2>/dev/null
        git branch -D "$temp_branch" 2>/dev/null
        return 0
    else
        git merge --abort 2>/dev/null || true
        git checkout - 2>/dev/null
        git branch -D "$temp_branch" 2>/dev/null
        return 1
    fi
}

# Merge a branch
merge_branch() {
    local branch=$1
    local target=${2:-main}
    local message=${3:-"Merge $branch into $target"}

    if ! branch_exists "$branch"; then
        log_error "Branch does not exist: $branch"
        return 1
    fi

    log_info "Merging $branch into $target..."

    git checkout "$target" 2>/dev/null || {
        log_error "Failed to switch to $target"
        return 1
    }

    if git merge "$branch" -m "$message"; then
        log_success "Merge completed: $branch"
        return 0
    else
        log_error "Merge conflict for $branch"
        return 1
    fi
}

# =============================================
# COMMIT INFORMATION
# =============================================

# Count commits since branch
count_commits_since() {
    local branch=${1:-main}
    git rev-list --count HEAD ^"$branch" 2>/dev/null || echo 0
}

# List modified files since branch
files_changed_since() {
    local branch=${1:-main}
    git diff --name-only "$branch" 2>/dev/null
}

# Last commit
last_commit() {
    git log --oneline -1 2>/dev/null || echo "none"
}

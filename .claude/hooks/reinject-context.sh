#!/bin/bash
# Re-inject project memory, capabilities, AND live execution state after context compaction.
# Ensures both static knowledge (Rule #1) and dynamic state survive long sessions.

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
ORCH_DIR="$PROJECT_DIR/.claude/orchestration"
SPECS_ACTIVE="$PROJECT_DIR/.claude/specs/active"

echo "## Re-injected after context compaction"
echo ""

# --- 1. Static knowledge (existing behavior) ---
if [[ -f "$PROJECT_DIR/.claude/PROJECT_MEMORY.md" ]]; then
  cat "$PROJECT_DIR/.claude/PROJECT_MEMORY.md"
  echo ""
fi

if [[ -f "$PROJECT_DIR/.claude/CAPABILITIES.md" ]]; then
  cat "$PROJECT_DIR/.claude/CAPABILITIES.md"
  echo ""
fi

# --- 2. Live execution state (new: dynamic snapshot) ---
echo "## Live Execution State"
echo ""

# 2a. Active agents and their status
has_agents=false
for task_file in "$ORCH_DIR/tasks"/*.md; do
  [[ -f "$task_file" ]] || continue
  has_agents=true
  break
done

if $has_agents; then
  echo "### Active Agents"
  echo ""
  echo "| Agent | Process | Status | Progress | Elapsed |"
  echo "|-------|---------|--------|----------|---------|"

  for task_file in "$ORCH_DIR/tasks"/*.md; do
    [[ -f "$task_file" ]] || continue
    name=$(basename "$task_file" .md)
    pid_file="$ORCH_DIR/pids/${name}.pid"
    started_file="$ORCH_DIR/pids/${name}.started"
    worktree_path="$PROJECT_DIR/.worktrees/$name"

    # Process status
    proc="stopped"
    if [[ -f "$pid_file" ]]; then
      pid=$(cat "$pid_file")
      if kill -0 "$pid" 2>/dev/null; then
        proc="running (PID $pid)"
      fi
    fi

    # Agent status from worktree markers
    status="pending"
    if [[ -f "$worktree_path/DONE.md" ]]; then
      status="done"
    elif [[ -f "$worktree_path/BLOCKED.md" ]]; then
      status="blocked"
    elif [[ "$proc" == *"running"* ]]; then
      status="running"
    elif [[ -f "$pid_file" ]]; then
      status="stopped"
    fi

    # Progress from PROGRESS.md
    progress="—"
    if [[ -f "$worktree_path/PROGRESS.md" ]]; then
      total=$(grep -c '^\s*- \[' "$worktree_path/PROGRESS.md" 2>/dev/null || echo 0)
      checked=$(grep -c '^\s*- \[x\]' "$worktree_path/PROGRESS.md" 2>/dev/null || echo 0)
      if [[ $total -gt 0 ]]; then
        pct=$((checked * 100 / total))
        progress="${pct}% (${checked}/${total})"
      fi
    fi

    # Elapsed time
    elapsed="—"
    if [[ -f "$started_file" ]]; then
      start_ts=$(cat "$started_file")
      now_ts=$(date +%s)
      diff=$((now_ts - start_ts))
      mins=$((diff / 60))
      secs=$((diff % 60))
      elapsed="${mins}m ${secs}s"
    fi

    echo "| $name | $proc | $status | $progress | $elapsed |"
  done
  echo ""

  # 2b. Error summary
  errors_file="$ORCH_DIR/errors.log"
  if [[ -f "$errors_file" ]] && [[ -s "$errors_file" ]]; then
    critical=$(grep -c '|CRITICAL|' "$errors_file" 2>/dev/null || echo 0)
    warnings=$(grep -c '|WARNING|' "$errors_file" 2>/dev/null || echo 0)
    if [[ $critical -gt 0 ]] || [[ $warnings -gt 0 ]]; then
      echo "### Errors Detected"
      echo ""
      echo "- Critical: $critical"
      echo "- Warnings: $warnings"
      echo ""
      echo "Recent errors:"
      echo '```'
      tail -5 "$errors_file"
      echo '```'
      echo ""
    fi
  fi
fi

# 2c. Active SDD specs
if [[ -d "$SPECS_ACTIVE" ]]; then
  has_specs=false
  for spec_dir in "$SPECS_ACTIVE"/*/; do
    [[ -d "$spec_dir" ]] || continue
    has_specs=true
    break
  done

  if $has_specs; then
    echo "### Active SDD Specs"
    echo ""
    echo "| Spec | Phase |"
    echo "|------|-------|"
    for spec_dir in "$SPECS_ACTIVE"/*/; do
      [[ -d "$spec_dir" ]] || continue
      spec_name=$(basename "$spec_dir")
      if [[ -f "$spec_dir/plan.md" ]]; then
        phase="planned"
      elif [[ -f "$spec_dir/research.md" ]]; then
        phase="researched"
      elif [[ -f "$spec_dir/spec.md" ]]; then
        phase="specified"
      else
        phase="empty"
      fi
      # Check if tasks were generated
      spec_num=${spec_name%%-*}
      task_count=0
      done_count=0
      for tf in "$ORCH_DIR/tasks"/*.md; do
        [[ -f "$tf" ]] || continue
        if grep -q "spec-ref:.*${spec_num}" "$tf" 2>/dev/null; then
          ((task_count++))
          tn=$(basename "$tf" .md)
          wp="$PROJECT_DIR/.worktrees/$tn"
          [[ -f "$wp/DONE.md" ]] && ((done_count++))
        fi
      done
      if [[ $task_count -gt 0 ]] && [[ $done_count -eq $task_count ]]; then
        phase="completed ($done_count/$task_count)"
      elif [[ $task_count -gt 0 ]]; then
        phase="executing ($done_count/$task_count done)"
      elif [[ -f "$spec_dir/tasks.md" ]]; then
        phase="tasks-ready"
      fi
      echo "| $spec_name | $phase |"
    done
    echo ""
  fi
fi

# 2d. Recent events (last 5)
events_file="$ORCH_DIR/EVENTS.md"
if [[ -f "$events_file" ]] && [[ -s "$events_file" ]]; then
  echo "### Recent Events"
  echo ""
  echo '```'
  tail -5 "$events_file"
  echo '```'
  echo ""
fi

echo "---"
echo "IMPORTANT: Always run 'update-memory' after making commits."
echo "IMPORTANT: If agents are running, resume monitoring with: .claude/scripts/orchestrate.sh status"

#!/bin/bash
# =============================================
# STATE - Continuous orchestrator state externalization
# Survives context compaction by persisting to disk.
# =============================================

STATE_FILE_PATH="${ORCHESTRATION_DIR}/ORCHESTRATOR_STATE.md"

# Write current orchestrator state to disk.
# Called at key lifecycle moments so reinject-context.sh always has fresh data.
write_orchestrator_state() {
    local action="${1:-unknown}"
    local detail="${2:-}"

    ensure_dir "$ORCHESTRATION_DIR"

    local now
    now=$(timestamp)

    {
        echo "# Orchestrator State"
        echo "> Last saved: $now"
        echo "> Trigger: $action"
        echo ""

        # --- Current action ---
        echo "## Current Action"
        if [[ -n "$detail" ]]; then
            echo "$detail"
        else
            echo "$action"
        fi
        echo ""

        # --- Agent summary ---
        local has_agents=false
        for tf in "$ORCHESTRATION_DIR/tasks"/*.md; do
            [[ -f "$tf" ]] && { has_agents=true; break; }
        done

        if $has_agents; then
            echo "## Agents"
            echo "| Agent | Status | Progress | Elapsed |"
            echo "|-------|--------|----------|---------|"

            local total=0 done_count=0 running_count=0 blocked_count=0
            for tf in "$ORCHESTRATION_DIR/tasks"/*.md; do
                [[ -f "$tf" ]] || continue
                local name
                name=$(basename "$tf" .md)
                ((total++)) || true

                local agent_state
                agent_state=$(get_agent_status "$name" 2>/dev/null || echo "unknown")

                case "$agent_state" in
                    done|done_no_report|done_dirty) ((done_count++)) || true ;;
                    running) ((running_count++)) || true ;;
                    blocked) ((blocked_count++)) || true ;;
                esac

                # Progress
                local progress="--"
                local wt
                wt=$(get_worktree_path "$name")
                if [[ -f "$wt/PROGRESS.md" ]]; then
                    local t c
                    t=$(grep -c '^\s*- \[' "$wt/PROGRESS.md" 2>/dev/null || echo 0)
                    c=$(grep -c '^\s*- \[x\]' "$wt/PROGRESS.md" 2>/dev/null || echo 0)
                    [[ $t -gt 0 ]] && progress="${c}/${t} ($((c * 100 / t))%)"
                fi

                # Elapsed
                local elapsed="--"
                local started_file="$ORCHESTRATION_DIR/pids/${name}.started"
                if [[ -f "$started_file" ]]; then
                    local start_ts now_ts diff
                    start_ts=$(cat "$started_file")
                    now_ts=$(date +%s)
                    diff=$((now_ts - start_ts))
                    elapsed="$((diff / 60))m $((diff % 60))s"
                fi

                echo "| $name | $agent_state | $progress | $elapsed |"
            done

            echo ""
            echo "**Summary**: $total total, $running_count running, $done_count done, $blocked_count blocked"
            echo ""
        fi

        # --- Active SDD specs ---
        if [[ -d "$SPECS_ACTIVE" ]]; then
            local has_specs=false
            for sd in "$SPECS_ACTIVE"/*/; do
                [[ -d "$sd" ]] && { has_specs=true; break; }
            done

            if $has_specs; then
                echo "## Active Specs"
                for sd in "$SPECS_ACTIVE"/*/; do
                    [[ -d "$sd" ]] || continue
                    local sname
                    sname=$(basename "$sd")
                    local phase="specified"
                    [[ -f "$sd/research.md" ]] && phase="researched"
                    [[ -f "$sd/plan.md" ]] && phase="planned"
                    [[ -f "$sd/tasks.md" ]] && phase="tasks-ready"
                    echo "- $sname ($phase)"
                done
                echo ""
            fi
        fi

        # --- Pending decisions / next steps ---
        echo "## Next Steps"
        if $has_agents; then
            local all_done=true
            for tf in "$ORCHESTRATION_DIR/tasks"/*.md; do
                [[ -f "$tf" ]] || continue
                local n
                n=$(basename "$tf" .md)
                local as
                as=$(get_agent_status "$n" 2>/dev/null || echo "unknown")
                case "$as" in
                    done|done_no_report|done_dirty) ;;
                    *) all_done=false ;;
                esac
            done

            if $all_done; then
                echo "- All agents done. Run: \`orchestrate.sh merge\`"
            else
                echo "- Agents still running. Continue monitoring: \`orchestrate.sh status\`"
                if [[ $blocked_count -gt 0 ]]; then
                    echo "- $blocked_count agent(s) blocked. Check: \`orchestrate.sh errors\`"
                fi
            fi
        else
            echo "- No active agents"
        fi
        echo ""

    } > "$STATE_FILE_PATH"
}

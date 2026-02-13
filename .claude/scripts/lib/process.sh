#!/bin/bash
# =============================================
# PROCESS - Process Management
# =============================================

# =============================================
# PID MANAGEMENT
# =============================================

get_pid_file() {
    local name=$1
    echo "$ORCHESTRATION_DIR/pids/$name.pid"
}

get_start_time_file() {
    local name=$1
    echo "$ORCHESTRATION_DIR/pids/$name.started"
}

get_log_file() {
    local name=$1
    echo "$ORCHESTRATION_DIR/logs/$name.log"
}

# Check if process is running
is_process_running() {
    local name=$1
    local pidfile=$(get_pid_file "$name")

    if file_exists "$pidfile"; then
        local pid=$(cat "$pidfile")
        if kill -0 "$pid" 2>/dev/null; then
            return 0
        fi
    fi
    return 1
}

# Get process PID
get_process_pid() {
    local name=$1
    local pidfile=$(get_pid_file "$name")

    if file_exists "$pidfile"; then
        cat "$pidfile"
    else
        echo ""
    fi
}

# Get execution time
get_process_runtime() {
    local name=$1
    local start_time_file=$(get_start_time_file "$name")

    if file_exists "$start_time_file"; then
        local start_ts=$(cat "$start_time_file")
        local now_ts=$(date '+%s')
        local diff=$((now_ts - start_ts))
        local mins=$((diff / 60))
        local secs=$((diff % 60))
        echo "${mins}m ${secs}s"
    else
        echo "desconhecido"
    fi
}

# =============================================
# START/STOP AGENTS
# =============================================

start_agent_process() {
    local name=$1
    local worktree_path=$2
    local prompt=$3
    local max_retries=${4:-3}
    local pidfile=$(get_pid_file "$name")
    local logfile=$(get_log_file "$name")
    local start_time_file=$(get_start_time_file "$name")

    # Check if already running
    if is_process_running "$name"; then
        local pid=$(get_process_pid "$name")
        log_warn "Agente $name já está rodando (PID: $pid)"
        return 0
    fi

    # Ensure directories exist
    ensure_dir "$ORCHESTRATION_DIR/pids"
    ensure_dir "$ORCHESTRATION_DIR/logs"

    # Retry loop with exponential backoff
    local retry=0
    local backoff_delays=(5 10 20)

    while [[ $retry -lt $max_retries ]]; do
        if [[ $retry -gt 0 ]]; then
            local delay=${backoff_delays[$((retry - 1))]:-20}
            log_warn "Retry $retry/$max_retries for $name (waiting ${delay}s)..."
            sleep "$delay"
        fi

        log_info "Iniciando agente: $name${retry:+ (attempt $((retry + 1))/$max_retries)}"

        (set +e; unset CLAUDECODE; cd "$worktree_path" || { echo "ERROR: Failed to cd to $worktree_path" > "$logfile"; exit 1; }; nohup claude --dangerously-skip-permissions --verbose --output-format stream-json -p "$prompt" > "$logfile" 2>&1) &

        local pid=$!

        # Save PID and timestamp
        echo $pid > "$pidfile"
        echo $(date '+%s') > "$start_time_file"

        # Wait to confirm process is alive
        sleep 3
        if kill -0 "$pid" 2>/dev/null; then
            log_success "Agente $name iniciado (PID: $pid)"
            return 0
        fi

        # Process died — check log for hints
        log_warn "Agent $name died immediately (attempt $((retry + 1)))"
        if [[ -s "$logfile" ]]; then
            log_info "Last log lines:"
            tail -5 "$logfile" 2>/dev/null | while IFS= read -r line; do
                echo "    $line"
            done
        fi

        rm -f "$pidfile" "$start_time_file"
        ((retry++)) || true
    done

    log_error "Falha ao iniciar agente $name após $max_retries tentativas"

    # Create BLOCKED.md to signal failure
    local blocked_file="$worktree_path/BLOCKED.md"
    cat > "$blocked_file" << BLOCKEOF
# BLOCKED: $name

Agent failed to start after $max_retries attempts.

## Last Log
$(tail -20 "$logfile" 2>/dev/null || echo "No log available")

## Timestamp
$(date '+%Y-%m-%d %H:%M:%S')
BLOCKEOF
    log_info "Created BLOCKED.md for $name"

    return 1
}

stop_agent_process() {
    local name=$1
    local force=${2:-false}
    local pidfile=$(get_pid_file "$name")
    local start_time_file=$(get_start_time_file "$name")

    if ! is_process_running "$name"; then
        log_warn "Agente $name não está rodando"
        rm -f "$pidfile" "$start_time_file"
        return 0
    fi

    local pid=$(get_process_pid "$name")
    log_info "Parando agente $name (PID: $pid)..."

    # Try SIGTERM first
    kill "$pid" 2>/dev/null

    # Wait up to 10 seconds
    local count=0
    while kill -0 "$pid" 2>/dev/null && [[ $count -lt 10 ]]; do
        sleep 1
        ((count++))
    done

    # Se ainda rodando e force, usar SIGKILL
    if kill -0 "$pid" 2>/dev/null; then
        if [[ "$force" == "true" ]]; then
            log_warn "Forçando término com SIGKILL..."
            kill -9 "$pid" 2>/dev/null
            sleep 1
        else
            log_error "Processo não terminou. Use --force para forçar."
            return 1
        fi
    fi

    rm -f "$pidfile" "$start_time_file"
    log_success "Agente $name parado"
    return 0
}

# =============================================
# LOGS
# =============================================

show_agent_logs() {
    local name=$1
    local lines=${2:-50}
    local logfile=$(get_log_file "$name")

    if file_exists "$logfile"; then
        tail -"$lines" "$logfile"
    else
        log_error "Log não encontrado: $logfile"
        return 1
    fi
}

follow_agent_logs() {
    local name=$1
    local logfile=$(get_log_file "$name")

    if file_exists "$logfile"; then
        tail -f "$logfile"
    else
        log_error "Log não encontrado: $logfile"
        return 1
    fi
}

# Log rotation
rotate_logs() {
    local max_size=${1:-10485760}  # 10MB default
    local max_files=${2:-5}

    for logfile in "$ORCHESTRATION_DIR/logs"/*.log; do
        [[ -f "$logfile" ]] || continue

        local size=$(stat -f%z "$logfile" 2>/dev/null || stat -c%s "$logfile" 2>/dev/null)
        if [[ $size -gt $max_size ]]; then
            # Rotacionar
            for i in $(seq $((max_files - 1)) -1 1); do
                [[ -f "${logfile}.$i" ]] && mv "${logfile}.$i" "${logfile}.$((i + 1))"
            done
            mv "$logfile" "${logfile}.1"
            touch "$logfile"
            log_info "Log rotacionado: $(basename "$logfile")"
        fi
    done
}

# =============================================
# STATUS
# =============================================

get_agent_status() {
    local name=$1
    local worktree_path=$(get_worktree_path "$name")

    # Check status files
    if file_exists "$worktree_path/DONE.md"; then
        echo "done"
    elif file_exists "$worktree_path/BLOCKED.md"; then
        echo "blocked"
    elif ! is_process_running "$name"; then
        # Process stopped — check if agent made commits or has uncommitted changes
        local commits=0
        local uncommitted=0
        if dir_exists "$worktree_path"; then
            commits=$(cd "$worktree_path" && git log --oneline main..HEAD 2>/dev/null | wc -l | tr -d ' ')
            uncommitted=$(cd "$worktree_path" && git status --porcelain 2>/dev/null | \
                grep -v -E '^(\?\?| M|M ) \.claude/(AGENTS_USED|CLAUDE\.md)' | \
                grep -v -E '^(\?\?| M|M ) uv\.lock$' | \
                wc -l | tr -d ' ')
        fi
        if [[ $commits -gt 0 ]]; then
            if [[ $uncommitted -gt 0 ]]; then
                echo "done_dirty"
            else
                echo "done_no_report"
            fi
        elif [[ $uncommitted -gt 0 ]]; then
            echo "stopped_dirty"
        elif file_exists "$worktree_path/PROGRESS.md"; then
            echo "stopped"
        else
            echo "pending"
        fi
    elif file_exists "$worktree_path/PROGRESS.md"; then
        echo "running"
    else
        echo "pending"
    fi
}

get_agent_progress() {
    local name=$1
    local worktree_path=$(get_worktree_path "$name")
    local progress_file="$worktree_path/PROGRESS.md"

    if file_exists "$progress_file"; then
        local done_items=$(grep -c "\- \[x\]" "$progress_file" 2>/dev/null || echo 0)
        local total_items=$(grep -c "\- \[" "$progress_file" 2>/dev/null || echo 0)

        if [[ $total_items -gt 0 ]]; then
            echo "$((done_items * 100 / total_items))"
        else
            echo "0"
        fi
    else
        echo "0"
    fi
}

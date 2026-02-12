#!/bin/bash
# =============================================
# COMMAND: start/stop/restart - Controle de agentes
# =============================================

cmd_start() {
    local names=("$@")

    # Se nenhum nome especificado, iniciar todos
    if [[ ${#names[@]} -eq 0 ]]; then
        for task_file in "$ORCHESTRATION_DIR/tasks"/*.md; do
            [[ -f "$task_file" ]] || continue
            names+=("$(basename "$task_file" .md)")
        done
    fi

    if [[ ${#names[@]} -eq 0 ]]; then
        log_error "Nenhuma tarefa encontrada em $ORCHESTRATION_DIR/tasks/"
        return 1
    fi

    log_step "Iniciando ${#names[@]} agente(s)..."

    for name in "${names[@]}"; do
        start_single_agent "$name"
        sleep 2
    done
}

start_single_agent() {
    local name=$1
    local worktree_path="../${PROJECT_NAME}-$name"
    local task_file="$ORCHESTRATION_DIR/tasks/$name.md"

    # Validations
    validate_name "$name" "agente" || return 1

    if ! dir_exists "$worktree_path"; then
        log_error "Worktree não encontrada: $name"
        log_info "Crie com: $0 setup $name --preset <preset>"
        return 1
    fi

    if ! file_exists "$task_file"; then
        log_error "Tarefa não encontrada: $task_file"
        return 1
    fi

    validate_task_file "$task_file" || return 1

    # Ler agentes especializados
    local specialized_agents=""
    if file_exists "$worktree_path/.claude/AGENTS_USED"; then
        specialized_agents=$(cat "$worktree_path/.claude/AGENTS_USED")
    fi

    # Ler tarefa
    local task=$(cat "$task_file")

    # Ler contexto do projeto
    local project_context=""
    if file_exists "$MEMORY_FILE"; then
        project_context=$(head -50 "$MEMORY_FILE")
    fi

    # Extrair contexto SDD se a task tiver spec-ref
    local sdd_context=""
    if grep -q "spec-ref:" "$task_file" 2>/dev/null; then
        local spec_ref=$(grep "spec-ref:" "$task_file" | head -1 | sed 's/.*spec-ref: *//')
        local spec_path="$PROJECT_ROOT/$spec_ref"
        local spec_dir=$(dirname "$spec_path")

        if [[ -f "$spec_path" ]]; then
            sdd_context+="
### Specification
$(head -80 "$spec_path")
"
        fi
        if [[ -f "$spec_dir/research.md" ]]; then
            sdd_context+="
### Research Findings
$(head -80 "$spec_dir/research.md")
"
        fi
        if [[ -f "$spec_dir/plan.md" ]]; then
            sdd_context+="
### Implementation Plan
$(head -80 "$spec_dir/plan.md")
"
        fi
    fi

    # Construir prompt
    local full_prompt="# CONTEXTO

Você é um agente executor com expertise em: $specialized_agents

⚠️ CRITICAL REQUIREMENT: When you finish your task, you MUST create a DONE.md file in the root of this worktree. This is NOT optional. The orchestrator depends on DONE.md to detect completion. Without it, your work will be considered incomplete even if you made commits.

## Base Instructions
$(cat "$worktree_path/.claude/CLAUDE.md" 2>/dev/null || cat "$CLAUDE_DIR/AGENT_CLAUDE.md" 2>/dev/null || echo "")

## Expertise Especializada
"

    # Add agent content
    for agent in $specialized_agents; do
        local agent_file="$worktree_path/.claude/agents/$agent.md"
        if file_exists "$agent_file"; then
            full_prompt+="
### $agent
$(cat "$agent_file")
"
        fi
    done

    full_prompt+="
## Contexto do Projeto
$project_context
"

    # Inject SDD context if available
    if [[ -n "$sdd_context" ]]; then
        full_prompt+="
## SDD Context (Spec-Driven Development)
The following specification, research, and plan documents guide this task:
$sdd_context
"
    fi

    full_prompt+="
## SUA TAREFA
$task

---
MANDATORY STEPS (follow in order):
1. Read the task above carefully
2. Create PROGRESS.md immediately
3. Execute step by step
4. Make frequent commits: git commit -m 'feat($name): desc'
5. LAST STEP (MANDATORY): Create DONE.md in the root directory with these sections:
   - # ✅ Completed: [task name]
   - ## Summary (what was done)
   - ## Modified Files (list of changed files)
   - ## How to Test (testing instructions)

⛔ WITHOUT DONE.md YOUR WORK IS CONSIDERED INCOMPLETE. This is the LAST thing you must do before finishing.

START NOW!"

    # Registrar evento
    echo "[$(timestamp)] STARTING: $name [agents: $specialized_agents]" >> "$EVENTS_FILE"

    # Initialize error tracking for this agent
    init_error_tracking "$name"

    # Start process
    start_agent_process "$name" "$worktree_path" "$full_prompt"
}

cmd_stop() {
    local name=$1
    local force=${2:-false}

    if [[ -z "$name" ]]; then
        log_error "Uso: $0 stop <agente> [--force]"
        return 1
    fi

    if [[ "$name" == "--force" ]] || [[ "$2" == "--force" ]]; then
        force=true
        [[ "$name" == "--force" ]] && name=$2
    fi

    stop_agent_process "$name" "$force"

    # Registrar evento
    echo "[$(timestamp)] STOPPED: $name" >> "$EVENTS_FILE"
}

cmd_restart() {
    local name=$1

    if [[ -z "$name" ]]; then
        log_error "Uso: $0 restart <agente>"
        return 1
    fi

    cmd_stop "$name" true
    sleep 2
    start_single_agent "$name"
}

cmd_logs() {
    local name=$1
    local lines=${2:-50}

    if [[ -z "$name" ]]; then
        log_error "Uso: $0 logs <agente> [linhas]"
        return 1
    fi

    show_agent_logs "$name" "$lines"
}

cmd_follow() {
    local name=$1

    if [[ -z "$name" ]]; then
        log_error "Uso: $0 follow <agente>"
        return 1
    fi

    follow_agent_logs "$name"
}

#!/bin/bash
# =============================================
# BASH COMPLETIONS - orchestrate.sh
# =============================================

_orchestrate() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    # Comandos principais
    local commands="init init-sample install-cli uninstall-cli doctor agents setup start stop restart status wait logs follow verify verify-all review pre-merge report merge cleanup show-memory update-memory learn sdd update update-check help"

    # Presets
    local presets="auth api frontend fullstack mobile devops data ml security review backend database"

    # Subcomandos de agents
    local agents_subcmds="list installed install install-preset"

    # Subcomandos de sdd
    local sdd_subcmds="init constitution specify research plan tasks status gate archive help"

    # Subcomandos de learn
    local learn_subcmds="extract review add-role show"

    case "$prev" in
        orchestrate.sh|./orchestrate.sh)
            COMPREPLY=( $(compgen -W "$commands" -- "$cur") )
            return 0
            ;;
        agents)
            COMPREPLY=( $(compgen -W "$agents_subcmds" -- "$cur") )
            return 0
            ;;
        sdd)
            COMPREPLY=( $(compgen -W "$sdd_subcmds" -- "$cur") )
            return 0
            ;;
        learn)
            COMPREPLY=( $(compgen -W "$learn_subcmds" -- "$cur") )
            return 0
            ;;
        research|plan|tasks|gate|archive)
            # Completar com números de spec existentes
            local spec_numbers=""
            if [[ -d ".claude/specs/active" ]]; then
                spec_numbers=$(ls -d .claude/specs/active/*/ 2>/dev/null | xargs -I{} basename {} | sed 's/-.*//')
            fi
            COMPREPLY=( $(compgen -W "$spec_numbers" -- "$cur") )
            return 0
            ;;
        --preset|install-preset)
            COMPREPLY=( $(compgen -W "$presets" -- "$cur") )
            return 0
            ;;
        setup|start|stop|restart|logs|follow|verify|review)
            # Listar worktrees existentes
            local worktrees=""
            if [[ -d ".claude/orchestration/tasks" ]]; then
                worktrees=$(ls .claude/orchestration/tasks/*.md 2>/dev/null | xargs -I{} basename {} .md)
            fi
            COMPREPLY=( $(compgen -W "$worktrees" -- "$cur") )
            return 0
            ;;
        --agents)
            # Listar agentes instalados
            local agents=""
            if [[ -d ".claude/agents" ]]; then
                agents=$(ls .claude/agents/*.md 2>/dev/null | xargs -I{} basename {} .md)
            fi
            COMPREPLY=( $(compgen -W "$agents" -- "$cur") )
            return 0
            ;;
        --from|merge)
            # Listar branches
            local branches=$(git branch 2>/dev/null | sed 's/^\*//;s/^ *//')
            COMPREPLY=( $(compgen -W "$branches" -- "$cur") )
            return 0
            ;;
    esac

    # Opções para setup
    if [[ "${COMP_WORDS[1]}" == "setup" ]]; then
        case "$cur" in
            -*)
                COMPREPLY=( $(compgen -W "--preset --agents --from" -- "$cur") )
                return 0
                ;;
        esac
    fi

    # Opções para status
    if [[ "${COMP_WORDS[1]}" == "status" ]]; then
        case "$cur" in
            -*)
                COMPREPLY=( $(compgen -W "--json" -- "$cur") )
                return 0
                ;;
        esac
    fi

    # Opções para doctor
    if [[ "${COMP_WORDS[1]}" == "doctor" ]]; then
        case "$cur" in
            -*)
                COMPREPLY=( $(compgen -W "--fix" -- "$cur") )
                return 0
                ;;
        esac
    fi

    # Opções para stop
    if [[ "${COMP_WORDS[1]}" == "stop" ]]; then
        case "$cur" in
            -*)
                COMPREPLY=( $(compgen -W "--force" -- "$cur") )
                return 0
                ;;
        esac
    fi

    # Opções para learn extract
    if [[ "${COMP_WORDS[1]}" == "learn" ]] && [[ "${COMP_WORDS[2]}" == "extract" ]]; then
        case "$cur" in
            -*)
                COMPREPLY=( $(compgen -W "--last --all --apply" -- "$cur") )
                return 0
                ;;
        esac
    fi

    # Opções para update-memory
    if [[ "${COMP_WORDS[1]}" == "update-memory" ]]; then
        case "$cur" in
            -*)
                COMPREPLY=( $(compgen -W "--bump --changelog --commits --full" -- "$cur") )
                return 0
                ;;
        esac
    fi
}

# Registrar completion
complete -F _orchestrate orchestrate.sh
complete -F _orchestrate ./orchestrate.sh
complete -F _orchestrate .claude/scripts/orchestrate.sh
complete -F _orchestrate orch

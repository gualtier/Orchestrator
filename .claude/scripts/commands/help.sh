#!/bin/bash
# =============================================
# COMMAND: help
# =============================================

cmd_help() {
    cat << 'EOF'

ORQUESTRADOR DE AGENTES CLAUDE v3.1
   Com Agentes Especializados

Uso: orchestrate.sh <comando> [argumentos]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

AGENTES:
  agents list               Listar agentes disponíveis
  agents install <agente>   Instalar agente
  agents install-preset <p> Instalar preset de agentes
  agents installed          Ver agentes instalados

INICIALIZAÇÃO:
  init                      Criar estrutura
  init-sample               Copiar exemplos de tarefas
  install-cli [nome]        Instalar comando global (default: orch)
  uninstall-cli [nome]      Remover comando global
  doctor                    Diagnosticar problemas
  doctor --fix              Corrigir problemas automaticamente

EXECUÇÃO:
  setup <nome> [opções]     Criar worktree com agentes
    --preset <preset>       Usar preset de agentes
    --agents <a1,a2,a3>     Especificar agentes
    --from <branch>         Branch de origem

  start [agentes]           Iniciar agentes
  stop <agente> [--force]   Parar agente
  restart <agente>          Reiniciar agente

MONITORAMENTO:
  status                    Ver status (formato texto padrão)
  status --enhanced|-e      Ver status com detalhes avançados
  status --watch|-w [N]     Atualização ao vivo (intervalo N segundos)
  status --compact|-c       Formato compacto (uma linha por agente)
  status --json             Ver status (formato JSON)
  wait [intervalo]          Aguardar conclusão (com modo watch)
  logs <agente> [n]         Ver últimas n linhas de log
  follow <agente>           Seguir logs em tempo real

VERIFICAÇÃO E QUALIDADE:
  verify <worktree>         Verificar worktree
  verify-all                Verificar todas as worktrees
  review <worktree>         Criar worktree de review
  pre-merge                 Verificar antes do merge
  report                    Gerar relatório consolidado

FINALIZAÇÃO:
  merge [branch]            Fazer merge (default: main)
  cleanup                   Limpar worktrees (arquiva artefatos)

MEMÓRIA:
  show-memory               Ver memória do projeto
  update-memory [opções]    Atualizar memória do projeto
    --bump                  Incrementar versão (X.Y → X.Y+1)
    --changelog             Gerar changelog dos commits recentes
    --commits <n>           Número de commits no changelog (default: 5)
    --full                  Equivalente a --bump --changelog

LEARNING:
  learn extract [opções]    Extrair insights de tarefas completas
    --last N                Extrair das últimas N tarefas (default: 5)
    --all                   Extrair de todas as tarefas arquivadas
    --apply                 Aplicar automaticamente sem revisão
  learn review              Revisar learnings pendentes
  learn add-role <arquivo>  Adicionar papel de agente ao CLAUDE.md
    --name "Nome"           Nome para o papel externo
  learn show                Mostrar seção de learnings atual

SDD (SPEC-DRIVEN DEVELOPMENT):
  sdd init                  Initialize SDD structure with templates
  sdd constitution          Show/create project constitution
  sdd specify "desc"        Create a new spec from description
  sdd research <number>     Create research doc (MANDATORY before plan)
  sdd plan <number>         Create implementation plan (requires research)
  sdd gate <number>         Check constitutional gates
  sdd run [number]          Autopilot: gate -> tasks -> setup -> start -> monitor
  sdd tasks <number>        Generate orchestrator tasks from plan
  sdd status                Show all active specs
  sdd archive <number>      Archive completed spec
  sdd help                  Show SDD help

ATUALIZAÇÃO:
  update                    Atualizar orquestrador do remote
  update-check              Verificar se há atualizações disponíveis

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

PRESETS DE AGENTES:
  auth      → backend-developer, security-auditor, typescript-pro
  api       → api-designer, backend-developer, test-automator
  frontend  → frontend-developer, react-specialist, ui-designer
  fullstack → fullstack-developer, typescript-pro, test-automator
  mobile    → mobile-developer, flutter-expert, ui-designer
  devops    → devops-engineer, kubernetes-specialist, terraform-engineer
  data      → data-engineer, data-scientist, postgres-pro
  ml        → ml-engineer, ai-engineer, mlops-engineer
  security  → security-auditor, penetration-tester, security-engineer
  review    → code-reviewer, architect-reviewer, security-auditor

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

EXAMPLE (SDD-FIRST WORKFLOW - Recommended):

  # 1. Initialize
  ./orchestrate.sh sdd init

  # 2. Create spec
  ./orchestrate.sh sdd specify "User authentication with OAuth"
  # ... refine spec.md with Claude ...

  # 3. Research (MANDATORY)
  ./orchestrate.sh sdd research 001
  # ... fill research.md with Claude ...

  # 4. Plan & verify
  ./orchestrate.sh sdd plan 001
  # ... refine plan.md with Claude ...
  ./orchestrate.sh sdd gate 001

  # 5a. Autopilot (gate -> tasks -> setup -> start -> monitor):
  ./orchestrate.sh sdd run 001    # Single spec
  ./orchestrate.sh sdd run        # All planned specs

  # 5b. OR manual step-by-step:
  ./orchestrate.sh sdd tasks 001
  ./orchestrate.sh setup auth --preset auth
  ./orchestrate.sh start
  ./orchestrate.sh wait

  # 6. Verify & merge
  ./orchestrate.sh verify-all
  ./orchestrate.sh merge
  ./orchestrate.sh sdd archive 001
  ./orchestrate.sh update-memory --full

EXAMPLE (DIRECT MODE - Small tasks):

  ./orchestrate.sh init
  ./orchestrate.sh setup auth --preset auth
  ./orchestrate.sh start
  ./orchestrate.sh wait
  ./orchestrate.sh merge
  ./orchestrate.sh update-memory --full

EOF
}

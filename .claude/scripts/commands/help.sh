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

EXEMPLO COMPLETO:

  # 1. Inicializar
  ./orchestrate.sh init
  ./orchestrate.sh doctor

  # 2. Create worktrees
  ./orchestrate.sh setup auth --preset auth
  ./orchestrate.sh setup api --preset api

  # 3. Create tasks
  ./orchestrate.sh init-sample

  # 4. Start
  ./orchestrate.sh start

  # 5. Monitorar
  ./orchestrate.sh status
  ./orchestrate.sh wait

  # 6. Check quality
  ./orchestrate.sh verify-all
  ./orchestrate.sh pre-merge
  ./orchestrate.sh report

  # 7. Finalizar
  ./orchestrate.sh merge
  ./orchestrate.sh update-memory --full
  ./orchestrate.sh cleanup

EOF
}

# Orchestrator Backlog

> Improvements identified during spec 011 execution cycle.
> Created: 2026-02-13

---

## Alta Prioridade

### #3 Contexto truncado (head -80)
- **Arquivo**: `start.sh:161-176`
- **Problema**: spec, research e plan são cortados com `head -80`. Specs com >80 linhas ficam incompletas para o agente.
- **Impacto**: Agente recebe spec incompleta — decisões baseadas em dados parciais
- **Fix**: Usar `cat` completo ou pelo menos `head -200`. O contexto é o insumo mais importante do agente.

### #4 Regras do projeto não são injetadas no prompt
- **Arquivo**: `start.sh` (prompt generation)
- **Problema**: O CLAUDE.md do worktree não inclui as regras do projeto principal. Agente viola regras (ex: Regra #3 hardcoded LARGE_CAP_SYMBOLS).
- **Impacto**: Violações de regras do projeto
- **Fix**: Injetar as regras do CLAUDE.md principal explicitamente no prompt do agente, ou garantir que o worktree herda o CLAUDE.md original.

### #1 Log do agente está vazio
- **Arquivo**: `lib/process.sh:94`
- **Problema**: `claude --dangerously-skip-permissions -p "..." > logfile 2>&1` não captura output útil. Logs ficam com 0 bytes.
- **Impacto**: Impossível debugar agentes falhos
- **Fix**: Usar `claude ... --output-format json 2>&1 | tee logfile` ou capturar via `script` command.

---

## Média Prioridade

### #5 /sdd-run não é realmente autopilot
- **Arquivo**: `commands/sdd.sh` (cmd_sdd_run)
- **Problema**: O skill diz "chains everything automatically" mas na prática os passos devem ser rodados manualmente.
- **Impacto**: Overhead manual em cada spec
- **Fix**: Garantir que `orchestrate.sh sdd run N` executa gate → tasks → setup → start → monitor numa chamada.

### #7 Merge deveria ter pre-flight check
- **Arquivo**: `commands/merge.sh`
- **Problema**: O merge falhou 2x antes de funcionar. Sem modo dry-run.
- **Impacto**: Previne falhas no merge
- **Fix**: Adicionar `orchestrate.sh merge --dry-run` que lista o que será mergeado, conflitos potenciais, e arquivos sujos.

### #9 Agent timeout/watchdog inexistente
- **Arquivo**: `lib/process.sh` (start_agent_process)
- **Problema**: Se o agente travar (loop infinito, API hang), fica rodando para sempre.
- **Impacto**: Previne processos orphaned
- **Fix**: Adicionar `--timeout 30m` no start que mata o processo automaticamente.

---

## Baixa Prioridade

### #6 Sem modo "direct" para specs single-worktree
- **Problema**: Para specs com 1 worktree/1 script, criar worktree + agente + merge + cleanup é overhead significativo.
- **Fix**: Se Worktree Mapping tem apenas 1 linha, oferecer `--direct` mode que executa no branch atual sem worktree.

### #8 Cleanup deveria ser parte do merge
- **Problema**: Após merge bem-sucedido, worktree e branch ficam orphaned. Cleanup é comando separado.
- **Fix**: `merge --cleanup` que após merge limpa automaticamente o worktree e branch da spec.

### #10 Sem retry automático
- **Arquivo**: `lib/process.sh` (start_agent_process)
- **Problema**: Se o agente falha ao iniciar, não há retry. Operador precisa investigar e restartar manualmente.
- **Fix**: Retry com backoff (3 tentativas, 5s/10s/20s). Se falha 3x, logar o erro e marcar como BLOCKED.

### #2 PROGRESS.md não reflete progresso real
- **Problema**: Ficou em 28% do minuto 1 ao 12, apesar do agente estar commitando ativamente.
- **Fix**: Usar commits como proxy de progresso, ou enfatizar no prompt do agente "atualize PROGRESS.md a cada fase concluída".

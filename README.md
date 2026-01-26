# Claude Orchestrator v3.3

Sistema de orquestração de agentes Claude com **arquitetura modular** e **agentes especializados**.

## Novidades

### v3.3 - Auto-Update & CLI

- **Comando `update`** - Atualiza orquestrador do remote
- **Comando `update-check`** - Verifica atualizações disponíveis
- **Comando `install-cli`** - Instala atalho global (`orch`)
- **Backup automático** - Cria backup antes de atualizar
- **Rollback** - Restaura automaticamente se falhar
- **Init inteligente** - Detecta e reseta memória do orquestrador

### v3.2 - Gestão de Memória
- **`update-memory --bump`** - Incrementa versão automaticamente
- **`update-memory --changelog`** - Gera changelog dos commits
- **`update-memory --full`** - Bump + changelog

### v3.1 - Modularização
- Arquitetura modular (lib/ e commands/)
- Comando `doctor` para diagnóstico
- Validação de entrada
- Output JSON (`status --json`)
- Testes automatizados
- Shell completions

## Instalação

```bash
# Copiar para seu projeto
cp -r orchestrator-v3/.claude ~/seu-projeto/
cp orchestrator-v3/CLAUDE.md ~/seu-projeto/

# Tornar executável
chmod +x ~/seu-projeto/.claude/scripts/*.sh

# Inicializar (cria PROJECT_MEMORY.md limpo para seu projeto)
cd ~/seu-projeto
.claude/scripts/orchestrate.sh init
.claude/scripts/orchestrate.sh doctor

# (Opcional) Instalar CLI global
.claude/scripts/orchestrate.sh install-cli
# Agora você pode usar: orch status, orch help, etc.
```

## Quick Start

```bash
# 1. Inicializar
orch init
orch doctor

# 2. Criar worktrees com agentes
orch setup auth --preset auth
orch setup api --preset api

# 3. Criar tarefas (ou copiar exemplos)
orch init-sample

# 4. Executar
orch start
orch status
orch wait

# 5. Verificar qualidade
orch verify-all
orch pre-merge

# 6. Finalizar
orch merge
orch update-memory --full
orch cleanup
```

## Presets de Agentes

| Preset | Agentes | Uso |
|--------|---------|-----|
| `auth` | backend-developer, security-auditor, typescript-pro | Autenticação |
| `api` | api-designer, backend-developer, test-automator | APIs REST |
| `frontend` | frontend-developer, react-specialist, ui-designer | Frontend |
| `fullstack` | fullstack-developer, typescript-pro, test-automator | Full-stack |
| `mobile` | mobile-developer, flutter-expert, ui-designer | Apps mobile |
| `devops` | devops-engineer, kubernetes-specialist, terraform-engineer | DevOps |
| `data` | data-engineer, data-scientist, postgres-pro | Data |
| `ml` | ml-engineer, ai-engineer, mlops-engineer | ML |
| `security` | security-auditor, penetration-tester, security-engineer | Segurança |
| `review` | code-reviewer, architect-reviewer, security-auditor | Review |

## Comandos

### Inicialização

```bash
orch init                    # Criar estrutura
orch init-sample             # Copiar exemplos de tarefas
orch install-cli [nome]      # Instalar CLI global (default: orch)
orch uninstall-cli [nome]    # Remover CLI global
orch doctor                  # Diagnosticar problemas
orch doctor --fix            # Corrigir automaticamente
```

### Agentes

```bash
orch agents list               # Listar disponíveis
orch agents installed          # Listar instalados
orch agents install <agente>   # Instalar específico
orch agents install-preset <p> # Instalar preset
```

### Execução

```bash
orch setup <nome> --preset <p>     # Criar worktree
orch setup <nome> --agents a1,a2   # Com agentes específicos
orch start                         # Iniciar todos
orch start <agente>                # Iniciar específico
orch stop <agente>                 # Parar
orch restart <agente>              # Reiniciar
```

### Monitoramento

```bash
orch status            # Ver status (texto)
orch status --json     # Ver status (JSON)
orch wait              # Aguardar conclusão
orch logs <agente>     # Ver logs
orch follow <agente>   # Seguir logs
```

### Verificação

```bash
orch verify <worktree>   # Verificar worktree
orch verify-all          # Verificar todas
orch review <worktree>   # Criar review
orch pre-merge           # Verificar antes do merge
orch report              # Gerar relatório
```

### Finalização

```bash
orch merge               # Fazer merge
orch cleanup             # Limpar (com confirmação)
```

### Memória

```bash
orch show-memory                  # Ver memória
orch update-memory                # Atualizar timestamp
orch update-memory --bump         # Incrementar versão
orch update-memory --changelog    # Gerar changelog
orch update-memory --full         # Bump + changelog
```

### Atualização

```bash
orch update-check    # Verificar se há atualizações
orch update          # Atualizar do remote (com backup)
```

## Estrutura

```
projeto/
├── CLAUDE.md                          # Arquiteto
├── .claude/
│   ├── PROJECT_MEMORY.md              # Memória
│   ├── agents/                        # Agentes instalados
│   ├── scripts/
│   │   ├── orchestrate.sh             # Entry point
│   │   ├── lib/                       # Bibliotecas
│   │   │   ├── logging.sh
│   │   │   ├── core.sh
│   │   │   ├── validation.sh
│   │   │   ├── git.sh
│   │   │   ├── process.sh
│   │   │   └── agents.sh
│   │   ├── commands/                  # Comandos
│   │   │   ├── init.sh
│   │   │   ├── doctor.sh
│   │   │   ├── setup.sh
│   │   │   ├── start.sh
│   │   │   ├── status.sh
│   │   │   ├── verify.sh
│   │   │   ├── merge.sh
│   │   │   ├── update.sh
│   │   │   └── help.sh
│   │   ├── tests/
│   │   └── completions/
│   └── orchestration/
│       ├── tasks/
│       ├── examples/
│       ├── logs/
│       └── .backups/                  # Backups do update
```

## Shell Completions

```bash
# Adicionar ao ~/.bashrc ou ~/.zshrc
source /path/to/.claude/scripts/completions/orchestrate.bash
```

## Testes

```bash
.claude/scripts/tests/test_runner.sh
```

## Fonte dos Agentes

- [VoltAgent/awesome-claude-code-subagents](https://github.com/VoltAgent/awesome-claude-code-subagents)

## Licença

MIT

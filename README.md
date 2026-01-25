# Claude Orchestrator v3.1

Sistema de orquestração de agentes Claude com **arquitetura modular** e **agentes especializados**.

## Novidades da v3.1

- **Arquitetura Modular** - Script refatorado em lib/ e commands/
- **Comando `doctor`** - Diagnóstico completo do sistema
- **Validação de Entrada** - Nomes e parâmetros validados
- **Confirmações** - Operações destrutivas pedem confirmação
- **Output JSON** - `status --json` para automação
- **Testes Automatizados** - Framework de testes incluído
- **Shell Completions** - Bash completions disponíveis
- **Exemplos de Tarefas** - `init-sample` copia exemplos

## Instalação

```bash
# Copiar para seu projeto
cp -r orchestrator-v3/.claude ~/seu-projeto/
cp orchestrator-v3/CLAUDE.md ~/seu-projeto/

# Tornar executável
chmod +x ~/seu-projeto/.claude/scripts/*.sh
chmod +x ~/seu-projeto/.claude/scripts/tests/*.sh

# Inicializar
cd ~/seu-projeto
.claude/scripts/orchestrate.sh init
.claude/scripts/orchestrate.sh doctor
```

## Quick Start

```bash
# 1. Inicializar e diagnosticar
.claude/scripts/orchestrate.sh init
.claude/scripts/orchestrate.sh doctor

# 2. Criar worktrees com agentes
.claude/scripts/orchestrate.sh setup auth --preset auth
.claude/scripts/orchestrate.sh setup api --preset api

# 3. Criar tarefas (ou copiar exemplos)
.claude/scripts/orchestrate.sh init-sample

# 4. Executar
.claude/scripts/orchestrate.sh start
.claude/scripts/orchestrate.sh status
.claude/scripts/orchestrate.sh wait

# 5. Verificar qualidade
.claude/scripts/orchestrate.sh verify-all
.claude/scripts/orchestrate.sh pre-merge
.claude/scripts/orchestrate.sh report

# 6. Finalizar
.claude/scripts/orchestrate.sh merge
.claude/scripts/orchestrate.sh cleanup
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
│   │   │   └── help.sh
│   │   ├── tests/                     # Testes
│   │   │   ├── test_runner.sh
│   │   │   └── test_validation.sh
│   │   └── completions/               # Shell completions
│   │       └── orchestrate.bash
│   └── orchestration/
│       ├── tasks/                     # Tarefas
│       ├── examples/                  # Exemplos
│       ├── logs/                      # Logs
│       └── archive/                   # Histórico
```

## Comandos

### Inicialização

```bash
orchestrate.sh init              # Criar estrutura
orchestrate.sh init-sample       # Copiar exemplos de tarefas
orchestrate.sh doctor            # Diagnosticar problemas
orchestrate.sh doctor --fix      # Corrigir automaticamente
```

### Agentes

```bash
orchestrate.sh agents list               # Listar disponíveis
orchestrate.sh agents installed          # Listar instalados
orchestrate.sh agents install <agente>   # Instalar específico
orchestrate.sh agents install-preset <p> # Instalar preset
```

### Execução

```bash
orchestrate.sh setup <nome> --preset <p>     # Criar worktree
orchestrate.sh setup <nome> --agents a1,a2   # Com agentes específicos
orchestrate.sh start                         # Iniciar todos
orchestrate.sh start <agente>                # Iniciar específico
orchestrate.sh stop <agente>                 # Parar
orchestrate.sh restart <agente>              # Reiniciar
```

### Monitoramento

```bash
orchestrate.sh status            # Ver status (texto)
orchestrate.sh status --json     # Ver status (JSON)
orchestrate.sh wait              # Aguardar conclusão
orchestrate.sh logs <agente>     # Ver logs
orchestrate.sh follow <agente>   # Seguir logs
```

### Verificação e Qualidade

```bash
orchestrate.sh verify <worktree>   # Verificar worktree
orchestrate.sh verify-all          # Verificar todas
orchestrate.sh review <worktree>   # Criar review
orchestrate.sh pre-merge           # Verificar antes do merge
orchestrate.sh report              # Gerar relatório
```

### Finalização

```bash
orchestrate.sh merge             # Fazer merge
orchestrate.sh cleanup           # Limpar (com confirmação)
orchestrate.sh show-memory       # Ver memória
orchestrate.sh update-memory     # Atualizar memória
```

## Shell Completions

```bash
# Adicionar ao ~/.bashrc ou ~/.zshrc
source /path/to/.claude/scripts/completions/orchestrate.bash
```

## Testes

```bash
# Rodar todos os testes
.claude/scripts/tests/test_runner.sh

# Rodar testes específicos
.claude/scripts/tests/test_runner.sh validation
```

## Fonte dos Agentes

Agentes são baixados de:
- [VoltAgent/awesome-claude-code-subagents](https://github.com/VoltAgent/awesome-claude-code-subagents)

## Licença

MIT

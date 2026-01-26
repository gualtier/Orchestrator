# Project Memory - Claude Orchestrator

> **Última atualização**: 2026-01-26 10:00
> **Versão**: 3.2

## Visão Geral

### Projeto

- **Nome**: claude-orchestrator
- **Descrição**: Sistema de orquestração de agentes Claude usando Git Worktrees com agentes especializados
- **Início**: 2025-01-21
- **Repo**: [local/github]

### Stack

| Camada | Tecnologia |
|--------|------------|
| Linguagem | Bash |
| Dependências | Git, curl, Claude CLI |
| Agentes | VoltAgent/awesome-claude-code-subagents |

## Arquitetura v3.1

### Estrutura Modular

```
.claude/scripts/
├── orchestrate.sh          # Entry point (68 linhas)
├── lib/
│   ├── logging.sh          # Log e cores
│   ├── core.sh             # Config e utilitários
│   ├── validation.sh       # Validação de entrada
│   ├── git.sh              # Operações git/worktree
│   ├── process.sh          # Gestão de processos
│   └── agents.sh           # Gestão de agentes
├── commands/
│   ├── init.sh             # init, init-sample
│   ├── doctor.sh           # doctor, doctor --fix
│   ├── setup.sh            # setup
│   ├── start.sh            # start, stop, restart, logs
│   ├── status.sh           # status, status --json, wait
│   ├── verify.sh           # verify, review, pre-merge, report
│   ├── merge.sh            # merge, cleanup, memory
│   └── help.sh             # help
├── tests/
│   ├── test_runner.sh      # Framework de testes
│   └── test_validation.sh  # 20 testes
└── completions/
    └── orchestrate.bash    # Shell completions
```

### Componentes

| Componente | Arquivo | Responsabilidade |
|------------|---------|------------------|
| Entry Point | orchestrate.sh | Carregar libs e rotear comandos |
| Logging | lib/logging.sh | Cores, timestamps, formatação |
| Core | lib/core.sh | Configuração, traps, utilitários |
| Validation | lib/validation.sh | Validar nomes, presets, arquivos |
| Git | lib/git.sh | Worktrees, branches, merge |
| Process | lib/process.sh | PIDs, logs, start/stop |
| Agents | lib/agents.sh | Download, cache, presets |

## Roadmap

### v1.0 - Base

- [x] Orquestração básica com worktrees
- [x] Memória persistente
- [x] Comandos básicos (setup, start, status, merge)

### v2.0 - Robustez

- [x] Validação pré-execução
- [x] Sistema de checkpoints
- [x] Recovery automático
- [x] Monitor dashboard

### v3.0 - Agentes Especializados

- [x] Integração com VoltAgent
- [x] Download automático de agentes
- [x] Sistema de presets
- [x] Cache local de agentes

### v3.1 - Modularização (ATUAL)

- [x] Refatorar script em módulos (lib/, commands/)
- [x] Validação de entrada em todos os comandos
- [x] Comando doctor para diagnóstico
- [x] Confirmação em operações destrutivas
- [x] Output JSON (status --json)
- [x] Framework de testes automatizados
- [x] Shell completions
- [x] Exemplos de tarefas (init-sample)
- [x] Comandos de verificação (verify, pre-merge, report)

### v4.0 - Futuro

- [ ] Interface web para monitoramento
- [ ] Integração com CI/CD
- [ ] Métricas e analytics
- [ ] Suporte a múltiplos LLMs
- [ ] Presets customizáveis (YAML)

## Decisões de Arquitetura

### ADR-001: Bash puro vs Node/Python

- **Decisão**: Bash puro
- **Motivo**: Zero dependências, funciona em qualquer sistema com Git
- **Trade-off**: Menos features avançadas, código mais verboso

### ADR-002: Git Worktrees vs Branches

- **Decisão**: Worktrees
- **Motivo**: Execução paralela real, cada agente em diretório isolado
- **Trade-off**: Mais complexo, usa mais disco

### ADR-003: Agentes como Markdown

- **Decisão**: Arquivos .md com instruções
- **Motivo**: Simples, versionável, editável, compatível com VoltAgent
- **Trade-off**: Sem validação de schema

### ADR-004: Arquitetura Modular

- **Decisão**: Separar em lib/ e commands/
- **Motivo**: Facilita manutenção, testes e extensibilidade
- **Trade-off**: Mais arquivos para gerenciar

## Problemas Resolvidos

| Problema | Versão | Solução |
|----------|--------|---------|
| `--workdir` inexistente | 3.1 | Usar cd no subshell |
| Falta de permissões | 3.1 | Usar `--dangerously-skip-permissions` |
| Script monolítico | 3.1 | Modularização em lib/ e commands/ |
| Sem validação | 3.1 | Criar lib/validation.sh |
| Operações destrutivas | 3.1 | Criar função confirm() |

## Lições Aprendidas

1. **Compatibilidade bash**: Evitar `declare -A`, preferir funções `case`
2. **set -e em testes**: Não usar, permite testes que esperam falhas
3. **Redireção em for**: `for x in *.txt 2>/dev/null` é inválido
4. **Escape em testes**: Usar aspas simples para strings literais
5. **Modularização**: Facilita muito testes e manutenção

## Próxima Sessão

### Concluído

- [x] Modularização completa
- [x] Testes automatizados
- [x] Documentação atualizada

### Ideias Futuras

- Dashboard web com WebSocket
- Métricas de tempo de execução por agente
- Integração com GitHub Actions
- Suporte a presets em YAML

---
> Atualize com: `.claude/scripts/orchestrate.sh update-memory`

# 🧠 Project Memory - Claude Orchestrator

> **Última atualização**: 2025-01-21 17:50
> **Versão**: 3.0

## 📋 Visão Geral

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

## 🏗️ Arquitetura

### Estrutura do Projeto
```
claude-orchestrator/
├── CLAUDE.md                    # Instruções do Arquiteto
├── README.md                    # Documentação
├── .claude/
│   ├── PROJECT_MEMORY.md        # Este arquivo
│   ├── AGENT_CLAUDE_BASE.md     # Template para agentes executores
│   ├── agents/                  # Agentes baixados (cache)
│   ├── scripts/
│   │   ├── orchestrate.sh       # Script principal (989 linhas)
│   │   └── agents.sh            # Gerenciador de agentes (417 linhas)
│   └── orchestration/
│       ├── tasks/               # Tarefas dos agentes
│       ├── logs/                # Logs de execução
│       ├── pids/                # PIDs dos processos
│       └── archive/             # Histórico
└── .vscode/
    ├── settings.json
    └── tasks.json
```

### Componentes Principais

| Componente | Arquivo | Responsabilidade |
|------------|---------|------------------|
| Orquestrador | orchestrate.sh | Gerenciar worktrees, agentes, execução |
| Gerenciador de Agentes | agents.sh | Baixar/listar agentes do VoltAgent |
| Arquiteto | CLAUDE.md | Instruções para o Claude orquestrador |
| Executor | AGENT_CLAUDE_BASE.md | Template para agentes nas worktrees |

### Presets de Agentes
| Preset | Agentes | Uso |
|--------|---------|-----|
| auth | backend-developer, security-auditor, typescript-pro | Autenticação |
| api | api-designer, backend-developer, test-automator | APIs |
| frontend | frontend-developer, react-specialist, ui-designer | UI |
| devops | devops-engineer, kubernetes-specialist, terraform-engineer | Infra |
| ... | ... | ... |

## 🗺️ Roadmap

### ✅ v1.0 - Base
- [x] Orquestração básica com worktrees
- [x] Memória persistente
- [x] Comandos básicos (setup, start, status, merge)

### ✅ v2.0 - Robustez
- [x] Validação pré-execução
- [x] Sistema de checkpoints
- [x] Recovery automático
- [x] Monitor dashboard
- [x] Diagnóstico de problemas

### ✅ v3.0 - Agentes Especializados
- [x] Integração com VoltAgent
- [x] Download automático de agentes
- [x] Sistema de presets
- [x] Cache local de agentes

### 🔄 v3.1 - Melhorias (EM PROGRESSO)
- [ ] Testes automatizados
- [ ] Documentação completa
- [ ] Presets customizáveis
- [ ] Suporte a mais fontes de agentes

### 📅 v4.0 - Futuro
- [ ] Interface web para monitoramento
- [ ] Integração com CI/CD
- [ ] Métricas e analytics
- [ ] Suporte a múltiplos LLMs

## 📊 Decisões de Arquitetura (ADRs)

### ADR-001: Bash puro vs Node/Python
- **Decisão**: Bash puro
- **Motivo**: Zero dependências, funciona em qualquer sistema com Git
- **Trade-off**: Menos features avançadas, código mais verboso

### ADR-002: Git Worktrees vs Branches
- **Decisão**: Worktrees
- **Motivo**: Permite execução paralela real, cada agente em diretório isolado
- **Trade-off**: Mais complexo para gerenciar, usa mais disco

### ADR-003: Agentes como Markdown
- **Decisão**: Arquivos .md com instruções
- **Motivo**: Simples, versionável, editável, compatível com VoltAgent
- **Trade-off**: Sem validação de schema

### ADR-004: Download automático vs manual
- **Decisão**: Automático com cache
- **Motivo**: Melhor UX, menos fricção
- **Trade-off**: Requer internet na primeira vez

## 🐛 Problemas Conhecidos

| Problema | Status | Workaround |
|----------|--------|------------|
| `declare -A` incompatível com bash < 4 | ✅ Resolvido | Usar funções case |
| `set -u` causa erro com variáveis | ✅ Resolvido | Usar `set -eo pipefail` |
| Alguns agentes VoltAgent não existem | ⚠️ Parcial | Verificar se arquivo não está vazio |

## 💡 Lições Aprendidas

1. **Compatibilidade bash**: Evitar `declare -A`, preferir funções `case`
2. **set -u é perigoso**: Usar com cuidado ou evitar
3. **Curl pode falhar silenciosamente**: Sempre verificar se arquivo não está vazio
4. **Agentes precisam de contexto**: Passar informações do projeto no prompt

## 🎯 Próxima Sessão

### Prioridades
1. Adicionar testes para os scripts
2. Melhorar tratamento de erros
3. Documentar todos os comandos

### Ideias
- Comando `orchestrate.sh doctor` para diagnosticar problemas
- Suporte a presets customizados em arquivo YAML
- Dashboard em tempo real (ncurses ou web)

---
> 💡 Atualize com: `.claude/scripts/orchestrate.sh update-memory`

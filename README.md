# 🤖 Claude Orchestrator v3.0

Sistema de orquestração com **agentes especializados** do VoltAgent/awesome-claude-code-subagents.

## ✨ Novidades da v3

- 🤖 **Agentes Especializados** - 70+ agentes de domínio específico
- 📦 **Presets** - Conjuntos prontos (auth, api, frontend, etc.)
- 🎯 **Expertise Contextual** - Cada worktree tem agentes relevantes
- 🔄 **Compatível com v2** - Todas as features anteriores mantidas

## 📦 Instalação

```bash
# Copiar para seu projeto
cp -r orchestrator-v3/* ~/seu-projeto/
cp -r orchestrator-v3/.* ~/seu-projeto/

# Tornar executável
chmod +x ~/seu-projeto/.claude/scripts/*.sh

# Inicializar
cd ~/seu-projeto
.claude/scripts/orchestrate.sh init
```

## 🚀 Quick Start

```bash
# 1. Inicializar
.claude/scripts/orchestrate.sh init

# 2. Ver agentes disponíveis
.claude/scripts/agents.sh list

# 3. Instalar agentes necessários
.claude/scripts/agents.sh install-preset auth
.claude/scripts/agents.sh install-preset api

# 4. Criar worktrees com agentes
.claude/scripts/orchestrate.sh setup auth --preset auth
.claude/scripts/orchestrate.sh setup api --preset api

# 5. Criar tarefas em .claude/orchestration/tasks/

# 6. Executar
.claude/scripts/orchestrate.sh start
.claude/scripts/orchestrate.sh wait
.claude/scripts/orchestrate.sh merge
.claude/scripts/orchestrate.sh cleanup
```

## 🤖 Presets de Agentes

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

## 📁 Estrutura

```
projeto/
├── CLAUDE.md                          # Arquiteto
├── .claude/
│   ├── PROJECT_MEMORY.md              # Memória
│   ├── AGENT_CLAUDE_BASE.md           # Template para agentes
│   ├── agents/                        # Agentes instalados
│   │   ├── typescript-pro.md
│   │   ├── react-specialist.md
│   │   └── ...
│   ├── scripts/
│   │   ├── orchestrate.sh             # Script principal
│   │   └── agents.sh                  # Gerenciador de agentes
│   └── orchestration/
│       ├── tasks/                     # Tarefas
│       ├── logs/                      # Logs
│       └── ...
└── .vscode/
    └── ...
```

## 🎮 Comandos

### Agentes
```bash
.claude/scripts/agents.sh list               # Listar disponíveis
.claude/scripts/agents.sh installed          # Listar instalados
.claude/scripts/agents.sh install <agente>   # Instalar específico
.claude/scripts/agents.sh install-preset <p> # Instalar preset
```

### Orquestração
```bash
.claude/scripts/orchestrate.sh init                          # Inicializar
.claude/scripts/orchestrate.sh setup <nome> --preset <p>     # Criar worktree
.claude/scripts/orchestrate.sh setup <nome> --agents a1,a2   # Com agentes específicos
.claude/scripts/orchestrate.sh start                         # Iniciar todos
.claude/scripts/orchestrate.sh status                        # Ver status
.claude/scripts/orchestrate.sh wait                          # Aguardar
.claude/scripts/orchestrate.sh merge                         # Fazer merge
.claude/scripts/orchestrate.sh cleanup                       # Limpar
```

## 💡 Como Funciona

1. **Arquiteto** analisa a tarefa e escolhe agentes
2. **Agentes são instalados** do repositório VoltAgent
3. **Worktrees são criados** com agentes copiados para `.claude/agents/`
4. **Agente executor** consulta os arquivos `.md` para expertise
5. **Código é escrito** seguindo melhores práticas do domínio

## 🔗 Fonte dos Agentes

Agentes são baixados de:
- [VoltAgent/awesome-claude-code-subagents](https://github.com/VoltAgent/awesome-claude-code-subagents)

## 📄 Licença

MIT

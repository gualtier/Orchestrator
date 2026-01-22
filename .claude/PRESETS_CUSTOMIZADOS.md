# 🛠️ Presets Customizados para Este Projeto

Como este projeto é em **Bash**, os presets padrão (focados em TypeScript/Python) não são ideais.

## Agentes Recomendados para Este Projeto

### Para scripts bash:
- `cli-developer` - Expertise em CLI e scripts
- `devops-engineer` - Boas práticas de shell
- `code-reviewer` - Review de código

### Para documentação:
- `documentation-engineer` - Docs técnicos
- `technical-writer` - README, guias

### Para testes:
- `qa-expert` - Estratégias de teste
- `test-automator` - Automação

## Presets Sugeridos

### `bash-dev`
```bash
.claude/scripts/orchestrate.sh setup feature --agents cli-developer,devops-engineer,code-reviewer
```

### `docs`
```bash
.claude/scripts/orchestrate.sh setup docs --agents documentation-engineer,technical-writer
```

### `tests`
```bash
.claude/scripts/orchestrate.sh setup tests --agents qa-expert,test-automator,cli-developer
```

## Exemplo de Uso

```bash
# Desenvolver nova feature
.claude/scripts/orchestrate.sh setup nova-feature --agents cli-developer,devops-engineer

# Criar documentação
.claude/scripts/orchestrate.sh setup documentacao --agents documentation-engineer,technical-writer

# Adicionar testes
.claude/scripts/orchestrate.sh setup testes --agents qa-expert,test-automator
```

# 🛠️ Custom Presets for This Project

Since this project is in **Bash**, the default presets (focused on TypeScript/Python) are not ideal.

## Recommended Agents for This Project

### For bash scripts:
- `cli-developer` - CLI and scripting expertise
- `devops-engineer` - Shell best practices
- `code-reviewer` - Code review

### For documentation:
- `documentation-engineer` - Technical docs
- `technical-writer` - README, guides

### For testing:
- `qa-expert` - Testing strategies
- `test-automator` - Automation

## Suggested Presets

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

## Usage Example

```bash
# Develop new feature
.claude/scripts/orchestrate.sh setup new-feature --agents cli-developer,devops-engineer

# Create documentation
.claude/scripts/orchestrate.sh setup documentation --agents documentation-engineer,technical-writer

# Add tests
.claude/scripts/orchestrate.sh setup tests --agents qa-expert,test-automator
```

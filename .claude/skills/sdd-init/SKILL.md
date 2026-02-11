---
name: sdd-init
description: Initialize Spec-Driven Development structure with templates and constitution. Use when starting SDD in a new project.
disable-model-invocation: true
allowed-tools: Bash
---

Initialize the SDD (Spec-Driven Development) structure for this project.

This creates:
- `.claude/specs/` directory structure
- Default templates (spec.md, research.md, plan.md, task.md)
- Project constitution with editable principles

```bash
.claude/scripts/orchestrate.sh sdd init
```

After initialization, use `/sdd-specify` to create your first specification.

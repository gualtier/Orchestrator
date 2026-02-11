---
name: sdd-gate
description: Check constitutional gates against an SDD plan. Validates research, simplicity, test-first, and traceability compliance.
argument-hint: [spec number]
allowed-tools: Bash, Read
---

Check constitutional gates for spec $ARGUMENTS.

```bash
.claude/scripts/orchestrate.sh sdd gate $ARGUMENTS
```

The gates verify:
1. **Research-First**: research.md exists and is substantive
2. **Simplicity**: Maximum 3 initial modules (warns at 4-5, fails at 6+)
3. **Test-First**: Test strategy defined in the plan
4. **Spec Traceability**: REQ- markers in spec.md

If gates pass with warnings, review them and decide whether to proceed or refine.
If gates fail, fix the issues before generating tasks.

## Next Step
After gates pass, run `/sdd-tasks <number>` to generate orchestrator tasks from the plan.

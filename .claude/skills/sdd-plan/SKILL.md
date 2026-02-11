---
name: sdd-plan
description: Create a technical implementation plan for an SDD spec. Use proactively after research is complete. Requires research.md to exist. Defines architecture, worktree mapping, and test strategy.
argument-hint: [spec number]
allowed-tools: Bash, Read, Edit, Write, Glob, Grep
---

Create the implementation plan for spec $ARGUMENTS. This requires research.md to exist.

## Steps

1. Create the plan scaffold:

```bash
.claude/scripts/orchestrate.sh sdd plan $ARGUMENTS
```

2. Read the spec and research to inform the plan:

```bash
cat .claude/specs/active/$ARGUMENTS-*/spec.md
cat .claude/specs/active/$ARGUMENTS-*/research.md
cat .claude/specs/constitution.md
```

3. Help the user fill in the plan.md with:

   - **Technical Approach**: Chosen approach grounded in research findings
   - **Technology Decisions**: Table linking each decision to research evidence
   - **Worktree Mapping**: CRITICAL - defines which modules map to which worktrees and presets:

     ```markdown
     | Module | Worktree Name | Preset |
     |--------|--------------|--------|
     | Auth   | auth         | auth   |
     | API    | api          | api    |
     ```

   - **Architecture**: System design, component relationships
   - **Constitutional Gates**: Verify compliance with project constitution
   - **Implementation Order**: Phases for parallel and sequential work
   - **Test Strategy**: How to validate end-to-end
   - **Risks**: With mitigations

4. The Worktree Mapping table is the bridge between SDD and the orchestrator. Each row becomes a task file and worktree.

## Next Step
Run `/sdd-gate <number>` to verify constitutional compliance, then `/sdd-tasks <number>` to generate orchestrator tasks.

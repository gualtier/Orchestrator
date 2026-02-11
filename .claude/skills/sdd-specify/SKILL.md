---
name: sdd-specify
description: Create a new SDD specification with auto-numbering from a feature description. Use proactively when the user describes a feature or requirement that needs multiple modules.
argument-hint: [feature description]
allowed-tools: Bash, Read, Edit, Write
---

Create a new specification using Spec-Driven Development.

## Steps

1. Run the specify command to create the spec scaffold:

```bash
.claude/scripts/orchestrate.sh sdd specify "$ARGUMENTS"
```

2. After creation, read the generated `spec.md` file and help the user refine it:
   - Clarify the **Problem Statement**
   - Define concrete **User Stories**
   - Add measurable **Functional Requirements** with REQ- markers
   - Set clear **Acceptance Criteria** with Given/When/Then format
   - Identify **Out of Scope** items
   - Flag **Open Questions** that need resolution

3. The spec should be complete enough that an engineer could implement it without asking questions.

## Next Step
After the spec is refined, run `/sdd-research <number>` to investigate technical decisions.

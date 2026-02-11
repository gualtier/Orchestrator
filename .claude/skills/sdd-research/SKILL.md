---
name: sdd-research
description: Create and fill the mandatory research document for an SDD spec. Use proactively after a spec is created to investigate libraries, patterns, security, and performance before planning.
argument-hint: [spec number]
allowed-tools: Bash, Read, Edit, Write, Glob, Grep, WebSearch, WebFetch
---

Create the research document for spec $ARGUMENTS. Research is MANDATORY before planning.

## Steps

1. Create the research scaffold:

```bash
.claude/scripts/orchestrate.sh sdd research $ARGUMENTS
```

2. Read the spec to understand what needs investigation:

```bash
cat .claude/specs/active/$ARGUMENTS-*/spec.md
```

3. Conduct thorough research and fill the research.md with findings:

   - **Library Analysis**: Compare options with pros/cons/decision table
   - **Performance Considerations**: Benchmarks, expected load, bottlenecks
   - **Security Implications**: Attack vectors, auth requirements, data sensitivity
   - **Existing Patterns in Codebase**: What can be reused, conventions to follow
   - **Constraints & Limitations**: Infrastructure, budget, expertise gaps
   - **Recommendations**: Summary with recommended approach grounded in findings
   - **Sources**: Links to docs, benchmarks, articles consulted

4. Use web search to find current best practices, benchmarks, and library comparisons.

5. Grep the codebase to identify existing patterns that should be reused.

## Next Step
After research is complete, run `/sdd-plan <number>` to create the technical implementation plan.

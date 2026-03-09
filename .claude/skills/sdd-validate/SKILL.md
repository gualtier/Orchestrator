---
name: sdd-validate
description: Production validation for a completed SDD spec. Launches an autonomous agent that verifies acceptance criteria by running real commands. Use after merge, before archive.
argument-hint: spec number [--skip]
allowed-tools: Bash, Read
---

Run autonomous production validation for a completed spec.

```bash
.claude/scripts/orchestrate.sh sdd validate $ARGUMENTS
```

## What It Does

Launches a **Claude agent** that autonomously verifies the feature works post-merge:

1. Reads the spec's Acceptance Criteria and Production Validation sections
2. Runs real commands to verify each criterion (tests, imports, file checks, API calls)
3. Records evidence (command output, file contents, test results)
4. Creates `validation.md` with PASS/FAIL for each check
5. Returns exit code 0 if all pass, 1 if any fail

## Integration with Auto-Merge

With `--auto-merge`, validation runs automatically between merge and archive:

```
gate → tasks → setup → start → monitor → merge → **validate** → archive
```

If validation fails, archiving still proceeds but a warning is logged.

## Skip Mode

For specs that don't need production validation (refactoring, internal tooling):

```bash
.claude/scripts/orchestrate.sh sdd validate $ARGUMENTS --skip
```

## Writing Good Validation Criteria

In your spec's `## Production Validation` section, write checks the agent can execute:

```markdown
## Production Validation

How the validation agent should verify this works after merge:

- [ ] Run `npm test` — all tests pass including new ones
- [ ] Verify `src/features/auth/` directory exists with login.ts, register.ts
- [ ] Import the new module: `node -e "require('./src/features/auth')"`
- [ ] Check no TypeScript errors: `npx tsc --noEmit`
```

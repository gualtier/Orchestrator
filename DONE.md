# ✅ Completed: Autonomous SDD Pipeline

> spec-ref: .claude/specs/active/003-autonomous-sdd-pipeline-make-sdd-run-fully-endtoen/spec.md

## Summary

Implemented the Autonomous SDD Pipeline module making `sdd run` a fully hands-off autopilot experience. Three key changes:

1. **Converted memory/merge stop hook from prompt to command hook** — The prompt-based hook couldn't detect env vars or self-dev. The new `memory-check.sh` command hook checks `SDD_AUTOPILOT=1` and `is_self_dev()` reliably, eliminating LLM evaluation latency (~2-5s per stop event).

2. **Added `--auto-merge` flag and post-run automation** — When `sdd run 003 --auto-merge` is used, the full pipeline runs without intervention: gate → tasks → setup → start → monitor → update-memory → merge → learn extract → archive. Default behavior (no flag) still pauses before merge.

3. **Extracted shared hook utilities** — `hooks/lib/hook-utils.sh` provides `is_self_dev()`, `is_autopilot()`, `json_ok()`, and `json_fail()` for all command hooks, with case-insensitive self-dev detection and bash 3.x compatibility.

## Modified Files

### New Files
- `.claude/hooks/lib/hook-utils.sh` — Shared hook utilities (is_self_dev, is_autopilot, json_ok/fail)
- `.claude/hooks/memory-check.sh` — Command hook replacing prompt-based memory check
- `.claude/tests/test-autonomous-pipeline.sh` — 24 tests covering all requirements

### Modified Files
- `.claude/settings.json` — Replaced prompt hook with command hook for memory check
- `.claude/hooks/self-dev-docs-check.sh` — Refactored to use shared hook-utils.sh
- `.claude/scripts/lib/core.sh` — Added SDD_AUTOPILOT env var export
- `.claude/scripts/commands/sdd.sh` — Added --auto-merge flag, post-run automation, SDD_AUTOPILOT=1

## Requirements Coverage

| Requirement | Status | Implementation |
|-------------|--------|----------------|
| REQ-1: SDD_AUTOPILOT env var | ✅ | Set in cmd_sdd_run, exported from core.sh |
| REQ-2: Hook bypass on autopilot | ✅ | memory-check.sh checks is_autopilot() |
| REQ-3: Auto update-memory | ✅ | cmd_update_memory --full after agents complete |
| REQ-4: Auto learn extract | ✅ | cmd_learn extract after successful merge |
| REQ-5: Auto-merge or prompt | ✅ | --auto-merge flag, default pauses |
| REQ-6: Auto archive | ✅ | Archive after successful auto-merge |
| REQ-7: Convert prompt to command hook | ✅ | memory-check.sh command hook |
| REQ-8: Shared is_self_dev() | ✅ | hooks/lib/hook-utils.sh |

## How to Test

### Run automated tests
```bash
bash .claude/tests/test-autonomous-pipeline.sh
```

### Manual verification

1. **Autopilot bypass**: Set `SDD_AUTOPILOT=1` and run `echo '{}' | bash .claude/hooks/memory-check.sh` — should output `{"ok": true}`

2. **Self-dev bypass**: In the orchestrator repo, run `echo '{}' | bash .claude/hooks/memory-check.sh` — should output `{"ok": true}`

3. **Full pipeline**: `orchestrate.sh sdd run 003 --auto-merge` — should run gate → tasks → setup → start → monitor → merge → archive without stopping

4. **Backward compat**: `orchestrate.sh sdd run 003` (without --auto-merge) — should still pause before merge

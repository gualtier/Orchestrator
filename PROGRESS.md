# Progress: Ralph Loop Engine + CLI Integration

## Steps

- [x] Read and understand existing codebase (process.sh, start.sh, status.sh, sdd.sh, orchestrate.sh)
- [x] Create lib/ralph.sh — loop engine core
  - [x] ralph_loop() — main iteration loop
  - [x] check_completion_signal() — scan log for RALPH_COMPLETE
  - [x] run_gates() — execute gate commands sequentially
  - [x] check_convergence() — detect stalled agents
  - [x] write_iteration_context() — build feedback for next iteration
  - [x] parse_ralph_config() — read ralph frontmatter from task file
- [x] Modify commands/start.sh — add --ralph flag and ralph detection
  - [x] Add --ralph and --max-iterations flag parsing to cmd_start()
  - [x] Add ralph detection in start_single_agent() to call ralph_loop()
  - [x] Add completion signal instruction to prompt when ralph mode active
- [x] Modify commands/status.sh — add iteration/gate display
  - [x] Read .iteration and .gates files in cmd_status_enhanced()
  - [x] Read .iteration and .gates files in cmd_status_standard()
  - [x] Show iteration count, gate results, convergence indicator
- [x] Modify commands/sdd.sh — add --ralph passthrough
  - [x] Add --ralph flag parsing in cmd_sdd_run()
  - [x] Pass --ralph through to cmd_start()
- [x] Modify orchestrate.sh — add source and cancel-ralph command
  - [x] Add source lib/ralph.sh
  - [x] Add cancel-ralph command routing
- [x] Add ralph-aware task template
  - [x] Update task template with ralph frontmatter section
- [ ] Test backward compatibility and ralph functionality
  - [ ] Verify script sources without errors
  - [ ] Verify start without --ralph works identically
  - [ ] Verify --ralph flag parsing
  - [ ] Verify cancel-ralph command routing
- [ ] Commit and create DONE.md

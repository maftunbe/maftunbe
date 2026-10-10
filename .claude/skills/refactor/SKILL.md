---
name: refactor
description: >
  Refactor existing code without changing its behavior. Use when asked to
  clean up, simplify, split, or restructure a file or function in this repo
  — especially TradeSupervisor.mq5's indicator-polling and voting logic.
---

# Refactor

Change structure, not behavior. Before and after must produce the same
output for the same input.

## Approach

1. Identify the smallest unit that's doing too much (e.g. a function mixing
   indicator buffer reads, vote tallying, and notification dispatch)
2. Extract along existing seams the codebase already implies — don't invent
   a new abstraction layer the project doesn't otherwise use
3. Keep input-processing style consistent with `architecture-patterns.md`
   (Signal + Trade + Risk + Filter split) when a change grows past a few
   functions
4. Preserve all existing behavior: magic numbers, thresholds, and edge-case
   handling move as-is unless the refactor's explicit purpose is to fix one
5. Note where a refactor would require touching the EA's default input
   values — flag it, don't change input defaults silently

## Verification

After refactoring, diff the logic path for each of: a normal tick, the
first tick after `OnInit`, and a tick with a missing/zero indicator buffer
value. Behavior must be identical to before the refactor.

---
name: bug-review
description: >
  Review a diff or file for correctness bugs before it's committed or merged.
  Use when asked to check code for bugs, find what's wrong, review before
  merging, or when a change touches order/position logic, buffer indexing,
  or external API calls in this repo.
---

# Bug Review

Find real defects, not style nits. For each candidate issue, trace a concrete
input or state that reaches it and produces a wrong result or crash — if no
such path exists, it isn't a finding.

## Checklist for this repo's MQL5 code

- **Double comparison**: `==`/`!=` on `double` without `NormalizeDouble()` or
  a tolerance
- **Buffer/array indexing**: series vs. non-series arrays, off-by-one in
  `OnCalculate()`'s `prev_calculated` handling
- **Order/position management**: unchecked return values of `OrderSend()`,
  `PositionOpen()`, `CTrade` calls; reverse-loop requirement when closing by
  index
- **Broker quirks**: 4-digit vs. 5-digit point size, `SYMBOL_FILLING_MODE`
  hardcoding instead of detection
- **WebRequest/Telegram/AI calls**: unhandled network failure, blocking call
  inside tick processing, missing timeout, token/URL exposure in logs
- **State across ticks**: `static`/global variables that should reset per
  bar but don't, or vice versa

## Output

List each finding as: file:line, the concrete failure scenario, and the
smallest fix. Skip anything you can't tie to an actual input or sequence of
events.

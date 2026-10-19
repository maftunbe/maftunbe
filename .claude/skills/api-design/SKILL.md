---
name: api-design
description: >
  Design or review the shape of an external integration (Telegram, AI
  provider, webhook, new EA input group) before implementing it. Use when
  adding a new InpXxx input block, a new WebRequest call, or a new provider
  to TradeSupervisor.mq5's EAIProvider/EIndMode pattern.
---

# API Design

This EA's existing surface is its `input` groups (`EIndMode`, `EAIProvider`,
per-indicator `InpNameN`/`InpModeN`/`InpBufAN`/`InpWeightN`) and its outbound
calls (Telegram Bot API, Anthropic Messages API, OpenAI-compatible chat
completions). Match this shape before adding a new one.

## When adding a new indicator slot or provider

- Follow the existing enum + numbered-input-group pattern
  (`InpUse4`/`InpName4`/... already exists as the template) instead of a new
  shape
- New `EAIProvider` entries need: endpoint URL, auth header format, and
  response-parsing differences — document all three before writing the
  `WebRequest()` call
- Keep weight/vote semantics (`InpWeightN`, `0` = advisory only) consistent
  across indicators

## When adding a new outbound call (Telegram, webhook, AI)

- Decide synchronous vs. `EventSetTimer()`-polled before writing it —
  `WebRequest()` blocks and isn't available in the Strategy Tester or
  indicators
- Define the failure contract: what happens to the trade/signal flow if the
  call times out or returns an error — never let a notification failure
  block or alter trade logic
- Keep the payload minimal: send what the message needs, not the full
  account/position state

## Output

State the new input/output shape, the failure contract, and one worked
example (sample request + expected response) before implementation starts.

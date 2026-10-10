---
name: docs-writer
description: >
  Write or update documentation for this repo — README sections, input
  parameter docs, or setup instructions. Use when asked to document a
  feature, write a README, or explain how to configure TradeSupervisor.mq5.
---

# Docs Writer

## Conventions for this repo

- Match the existing comment language (Uzbek) used in
  `TradeSupervisor.mq5`'s header and input-group comments when documenting
  EA behavior for end users; use English for developer-facing docs (SKILL.md
  files, code comments aimed at contributors)
- Document every `input` parameter's effect, not just its name — state what
  changing it does to EA behavior, not only its type
- Never include a real bot token, chat ID, or API key in an example — use
  placeholders like `<YOUR_BOT_TOKEN>`
- For setup docs (Telegram, AI provider), give the exact steps in order:
  where to get the credential, which EA input field it goes in, and how to
  verify it worked (e.g. a test alert)

## Output

Write docs that a user who has never opened the `.mq5` file could follow.
Prefer a short numbered setup list over prose. Flag anywhere behavior is
inferred from code rather than confirmed by testing.

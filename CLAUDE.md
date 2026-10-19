# Claude Project Instructions

This repository holds MQL5 code for MetaTrader 5, including the
`TradeSupervisor` Expert Advisor (`MQL5/Experts/TradeSupervisor.mq5`), which
watches chart indicators to confirm or contest trades, logs results to CSV,
and can report via Telegram, MT5 push, or an Anthropic/OpenAI API call.

## Skills

Claude Code auto-loads skills from `.claude/skills/`. The ones installed here:

- [`.claude/skills/mql-developer/SKILL.md`](.claude/skills/mql-developer/SKILL.md) —
  full MQL4/MQL5 development reference: EA architecture, trading operations,
  external API communication (WebRequest/REST, relevant to this EA's Telegram
  and Anthropic/OpenAI calls), backtesting, security/licensing.
- [`.claude/skills/mql5-indicator-patterns/SKILL.md`](.claude/skills/mql5-indicator-patterns/SKILL.md) —
  custom indicator patterns: buffers, display scale, new-bar detection,
  warmup calculation.
- [`.claude/skills/bug-review/SKILL.md`](.claude/skills/bug-review/SKILL.md) —
  review a diff/file for correctness bugs before merging.
- [`.claude/skills/security-audit/SKILL.md`](.claude/skills/security-audit/SKILL.md) —
  audit for leaked secrets, unsafe WebRequest/Telegram/AI calls.
- [`.claude/skills/refactor/SKILL.md`](.claude/skills/refactor/SKILL.md) —
  restructure code without changing behavior.
- [`.claude/skills/api-design/SKILL.md`](.claude/skills/api-design/SKILL.md) —
  design new EA inputs or external integrations before implementing them.
- [`.claude/skills/docs-writer/SKILL.md`](.claude/skills/docs-writer/SKILL.md) —
  write/update README sections and setup docs.

No action is needed to "use" them — Claude Code reads a skill's `SKILL.md`
automatically when its description matches the task at hand.

## General rules

- Inspect project context before editing
- Prefer minimal, safe fixes
- Explain trade-offs and risks
- Suggest tests for non-trivial changes
- Keep responses structured and actionable
- Never hardcode secrets (bot tokens, API keys) — these are entered as EA
  inputs in the MT5 terminal, never committed to the repo

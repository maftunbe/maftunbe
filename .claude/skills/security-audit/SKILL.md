---
name: security-audit
description: >
  Audit code for security issues before committing or merging. Use when
  asked for a security review, when secrets/tokens/credentials are touched,
  or when code adds a new external API call (WebRequest, Telegram, Anthropic,
  OpenAI) in this repo.
---

# Security Audit

## What to check in this repo

- **Secrets never committed**: bot tokens (`InpBotToken`), chat IDs, and AI
  API keys must stay as EA `input` parameters entered in the MT5 terminal —
  never hardcoded in `.mq5`/`.mqh` source, never logged, never written to
  the CSV journal
- **WebRequest allowlisting**: confirm the target URL is meant to be
  whitelisted in Tools > Options > Expert Advisors, not assumed
- **Outbound data**: check what the Telegram/Anthropic/OpenAI payload
  actually contains — account number, balance, or symbol data leaking where
  it shouldn't
- **Injection in built strings**: MQL has no native JSON; manually built
  JSON/URL strings must escape user- or market-derived values (symbol names,
  comment fields) before concatenation
- **Licensing/protection code**: if `security-licensing.md` patterns
  (account-based licensing, server-side validation) are touched, verify the
  check can't be bypassed by a stale cached response or a missing
  fail-closed default

## Output

Report each finding as: what leaks or can be bypassed, the concrete
attacker/accident scenario, and the fix. A finding needs a real path to
exposure — not just "could theoretically."

# Six Agent AI Trading Desk — Automated (Crypto, Paper Trading Only)

An automated version of the manual ATLAS/VEGA/ORION/LUNA/TITAN/NOVA paper-trading
workflow, targeting crypto via Binance Testnet. This runs scheduled, but it is
**not** an autonomous live-trading bot: every proposed trade still requires a human
tap on a Telegram button before anything reaches the exchange, and the exchange it
reaches is a testnet with no real money.

## Non-negotiable rules (unchanged from the manual guide)

- No real-money execution, ever. This project only talks to Binance **Testnet**.
- No credentials in prompts, logs, or the journal — only in `.env`, which is never committed.
- `TRADING_ENABLED=false` by default. Flip it only after validating the manual
  cadence of decisions and reading every agent report for a while.
- The mechanical risk gate (`risk_gate.py`) can reject a trade NOVA approved; it can
  never be overridden by an LLM's output, no matter how the prompt is phrased.
- A human approves or rejects every TRADE proposal via Telegram before an order is placed.

## Architecture

```
scheduler (APScheduler, every CYCLE_INTERVAL_MINUTES)
  -> data_collector.build_source_pack()      # Binance Testnet OHLCV + CryptoPanic news
  -> agents.orchestrator.run_cycle()
       ATLAS, VEGA, ORION, LUNA              # parallel-ish narrow reports (cheap model)
       risk_gate (mechanical, no LLM)        # hard numeric checks
       TITAN (narrative, strong model)       # explains the mechanical result, can downgrade
       NOVA (strong model)                   # TRADE / WAIT / REJECT + machine-parseable plan
       risk_gate AGAIN on NOVA's own numbers # final veto, independent of the LLM
  -> db.py (SQLite journal of every pack, report, and decision)
  -> telegram_approval (if verdict == TRADE) # human approve/reject buttons
       -> executor.py (only on approval)     # places a limit order on Binance Testnet
```

## Setup

1. `python -m venv venv && source venv/bin/activate && pip install -r requirements.txt`
2. Copy `.env.example` to `.env` and fill in:
   - `ANTHROPIC_API_KEY` — console.anthropic.com
   - `BINANCE_TESTNET_API_KEY` / `BINANCE_TESTNET_SECRET` — https://testnet.binance.vision
     (register separately from your real Binance account; this is a sandboxed system)
   - `CRYPTOPANIC_API_KEY` — optional, free tier at cryptopanic.com/developers
   - `TELEGRAM_BOT_TOKEN` — create a bot via @BotFather, then message it once and read
     `TELEGRAM_CHAT_ID` from `https://api.telegram.org/bot<TOKEN>/getUpdates`
3. Leave `TRADING_ENABLED=false` for the first runs. Watch the Telegram messages and the
   SQLite journal (`trading_desk.sqlite3`) to see what the desk would have done.
4. Only after reviewing at least ~20 cycles by hand, set `TRADING_ENABLED=true` to allow
   approved trades to actually place testnet orders.
5. `python main.py`

## What is intentionally NOT automated yet

- **Sentiment (LUNA)**: no social/search API is wired in; LUNA will correctly report
  "NOT AVAILABLE" rather than invent a mood. Wiring in a real source (e.g. LunarCrush) is
  a deliberate later step, not an oversight.
- **Position monitoring / stop-loss execution after entry**: this scaffold places the
  entry order on approval but does not yet manage the open position (trailing stop,
  auto-close at target). That is real execution-risk territory and should be designed
  and reviewed separately before being added.
- **Multi-exchange / multi-account**: one exchange (Binance Testnet), one Telegram chat.

## Kill switch

`TRADING_ENABLED` is checked in three independent places: `risk_gate.evaluate_trade_plan`,
`telegram_approval.on_callback`, and `executor.submit_trade`. Setting it to `false` and
restarting the process is the fastest way to guarantee no new order can be submitted,
even if every other check somehow passed.

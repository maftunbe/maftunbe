"""Central config. Every value is read once at import time from the environment.

No secret ever has a default here — a missing key fails loudly instead of
silently falling back to an empty string that would make a later API call
fail with a confusing error.
"""
import os
from dotenv import load_dotenv

load_dotenv()


def _require(name: str) -> str:
    value = os.environ.get(name)
    if not value:
        raise RuntimeError(f"Missing required environment variable: {name}")
    return value


def _bool(name: str, default: bool = False) -> bool:
    return os.environ.get(name, str(default)).strip().lower() == "true"


ANTHROPIC_API_KEY = os.environ.get("ANTHROPIC_API_KEY", "")
BINANCE_TESTNET_API_KEY = os.environ.get("BINANCE_TESTNET_API_KEY", "")
BINANCE_TESTNET_SECRET = os.environ.get("BINANCE_TESTNET_SECRET", "")
CRYPTOPANIC_API_KEY = os.environ.get("CRYPTOPANIC_API_KEY", "")
TELEGRAM_BOT_TOKEN = os.environ.get("TELEGRAM_BOT_TOKEN", "")
TELEGRAM_CHAT_ID = os.environ.get("TELEGRAM_CHAT_ID", "")

# Master switch. Everything downstream of order submission re-checks this
# immediately before acting — never trust a value cached earlier in a cycle.
TRADING_ENABLED = _bool("TRADING_ENABLED", default=False)

RISK_RULES = {
    "max_open_positions": int(os.environ.get("MAX_OPEN_POSITIONS", "1")),
    "max_loss_pct_of_balance": float(os.environ.get("MAX_LOSS_PCT_OF_BALANCE", "0.25")),
    "min_reward_to_risk": float(os.environ.get("MIN_REWARD_TO_RISK", "2.0")),
    "max_trades_per_day": int(os.environ.get("MAX_TRADES_PER_DAY", "3")),
}

WATCHED_SYMBOLS = [s.strip() for s in os.environ.get("WATCHED_SYMBOLS", "BTC/USDT").split(",") if s.strip()]
CYCLE_INTERVAL_MINUTES = int(os.environ.get("CYCLE_INTERVAL_MINUTES", "60"))

DB_PATH = os.environ.get("DB_PATH", "trading_desk.sqlite3")

# Agents that only summarize/rank get the cheap model; the two decision
# agents that gate real(ish) money get the stronger one.
MODEL_FAST = os.environ.get("MODEL_FAST", "claude-haiku-5-5")
MODEL_STRONG = os.environ.get("MODEL_STRONG", "claude-sonnet-5-5")

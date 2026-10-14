"""Builds the SOURCE PACK: the one bundle of facts every agent must reason
from. Nothing here calls an LLM — this module only fetches data.

Everything returned is treated as untrusted content once it reaches the
agents (see agents/prompts.py) — a headline or a social post is data, not
an instruction, however it is worded.
"""
from datetime import datetime, timezone

import ccxt
import requests

import config

TESTNET_URLS = {
    "spot": "https://testnet.binance.vision",
}


def _binance_testnet():
    exchange = ccxt.binance({
        "apiKey": config.BINANCE_TESTNET_API_KEY,
        "secret": config.BINANCE_TESTNET_SECRET,
        "enableRateLimit": True,
    })
    exchange.set_sandbox_mode(True)  # ccxt's switch for Binance's public testnet
    return exchange


def fetch_market_snapshot(symbol: str, timeframe: str = "1h", limit: int = 100) -> dict:
    exchange = _binance_testnet()
    ohlcv = exchange.fetch_ohlcv(symbol, timeframe=timeframe, limit=limit)
    ticker = exchange.fetch_ticker(symbol)
    candles = [
        {"ts": c[0], "open": c[1], "high": c[2], "low": c[3], "close": c[4], "volume": c[5]}
        for c in ohlcv
    ]
    return {
        "symbol": symbol,
        "timeframe": timeframe,
        "current_price": ticker.get("last"),
        "candles": candles,
    }


def fetch_news(currency_code: str, max_items: int = 5) -> list[dict]:
    """CryptoPanic free-tier feed, filtered to one asset. Returns [] on any
    failure rather than raising — a missing news source is something ORION
    is told to flag as MISSING INFORMATION, not a reason to crash the cycle.
    """
    if not config.CRYPTOPANIC_API_KEY:
        return []
    try:
        resp = requests.get(
            "https://cryptopanic.com/api/v1/posts/",
            params={
                "auth_token": config.CRYPTOPANIC_API_KEY,
                "currencies": currency_code,
                "public": "true",
            },
            timeout=10,
        )
        resp.raise_for_status()
        results = resp.json().get("results", [])[:max_items]
        return [
            {
                "title": item.get("title"),
                "url": item.get("url"),
                "source": (item.get("source") or {}).get("title"),
                "published_at": item.get("published_at"),
            }
            for item in results
        ]
    except requests.RequestException:
        return []


def build_source_pack(symbol: str, account_rules: dict) -> dict:
    """symbol like 'BTC/USDT'. account_rules should mirror config.RISK_RULES
    so every agent — including the human reading the journal later — sees
    the same limits NOVA and TITAN were bound by.
    """
    base_currency = symbol.split("/")[0]
    market = fetch_market_snapshot(symbol)
    news = fetch_news(base_currency)
    return {
        "symbol": symbol,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "market": market,
        "news": news,
        "sentiment": None,  # intentionally omitted for v1 — see README
        "account_rules": account_rules,
        "missing": [] if news else ["news: no CRYPTOPANIC_API_KEY configured or fetch failed"],
    }

"""Entry point. Runs the Telegram bot (for approvals) and the APScheduler
cron job (for desk cycles) in the same asyncio event loop.

Usage: python main.py
"""
import asyncio
import logging

import ccxt
from apscheduler.schedulers.asyncio import AsyncIOScheduler

import config
import db
import telegram_approval
from agents import orchestrator

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
logger = logging.getLogger("main")


def _fetch_account_balance(quote_currency: str = "USDT") -> float:
    exchange = ccxt.binance({
        "apiKey": config.BINANCE_TESTNET_API_KEY,
        "secret": config.BINANCE_TESTNET_SECRET,
        "enableRateLimit": True,
    })
    exchange.set_sandbox_mode(True)
    balance = exchange.fetch_balance()
    return balance.get(quote_currency, {}).get("free", 0.0) or 0.0


async def run_all_symbols(app):
    balance = _fetch_account_balance()
    for symbol in config.WATCHED_SYMBOLS:
        try:
            result = orchestrator.run_cycle(symbol, account_balance=balance)
            logger.info("Cycle done for %s: %s", symbol, result["verdict"])
            if result["verdict"] == "TRADE":
                await telegram_approval.request_approval(
                    app, result["decision_id"], symbol, result["trade_plan"]
                )
        except Exception:
            logger.exception("Cycle failed for %s", symbol)


async def main():
    db.init_db()
    if not config.TRADING_ENABLED:
        logger.warning("TRADING_ENABLED=false — desk will scan and propose but never place orders.")

    app = telegram_approval.build_app()
    await app.initialize()
    await app.start()
    await app.updater.start_polling()

    scheduler = AsyncIOScheduler()
    scheduler.add_job(
        run_all_symbols, "interval", minutes=config.CYCLE_INTERVAL_MINUTES, args=[app]
    )
    scheduler.start()
    logger.info(
        "Desk started. Watching %s every %s minutes.",
        config.WATCHED_SYMBOLS, config.CYCLE_INTERVAL_MINUTES,
    )

    try:
        await asyncio.Event().wait()  # run forever
    finally:
        await app.updater.stop()
        await app.stop()
        await app.shutdown()


if __name__ == "__main__":
    asyncio.run(main())

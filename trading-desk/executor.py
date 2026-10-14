"""The only module allowed to call an exchange order-placement endpoint.
Called from exactly one place: telegram_approval.on_callback, after a human
has tapped Approve. Re-checks the kill switch itself — never trust that the
caller already checked it.
"""
import ccxt

import config
import db
import risk_gate


def _binance_testnet():
    exchange = ccxt.binance({
        "apiKey": config.BINANCE_TESTNET_API_KEY,
        "secret": config.BINANCE_TESTNET_SECRET,
        "enableRateLimit": True,
    })
    exchange.set_sandbox_mode(True)
    return exchange


def submit_trade(decision_id: int, trade_plan: dict) -> str:
    if not config.TRADING_ENABLED:
        raise RuntimeError("TRADING_ENABLED is false — refusing to submit, even though approved.")

    decision_row = db.get_decision(decision_id)
    if decision_row is None or decision_row["human_approved"] != 1:
        raise RuntimeError("No recorded human approval for this decision — refusing to submit.")

    symbol = trade_plan.get("symbol") or decision_row["symbol"]
    if not symbol:
        raise RuntimeError("Trade plan has no symbol — refusing to guess one.")

    side = trade_plan["side"]
    qty = trade_plan.get("suggested_qty")
    if not qty or qty <= 0:
        raise RuntimeError(f"Invalid quantity computed by risk_gate: {qty}")

    exchange = _binance_testnet()
    balance = exchange.fetch_balance()
    quote_currency = symbol.split("/")[1]
    account_balance = balance.get(quote_currency, {}).get("free", 0)

    final_check = risk_gate.evaluate_trade_plan(trade_plan, account_balance, symbol)
    if not final_check.passed:
        raise RuntimeError(f"Risk gate re-check failed at execution time: {final_check.reason}")

    order_side = "buy" if side == "long" else "sell"
    order = exchange.create_order(
        symbol=symbol,
        type="limit",
        side=order_side,
        amount=qty,
        price=trade_plan["entry"],
    )

    db.save_trade(
        decision_id=decision_id,
        symbol=symbol,
        side=side,
        entry=trade_plan["entry"],
        stop=trade_plan["stop"],
        target=trade_plan["target"],
        qty=qty,
        status="submitted",
        exchange_order_id=order.get("id"),
    )
    return f"Paper order submitted on testnet: {order.get('id')}"

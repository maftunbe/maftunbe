"""The human approval gate. A TRADE decision is never sent to the exchange
directly — it is posted here first, and executor.submit_trade is only ever
called from on_approval_callback, after a person taps a button.

This is the one component in the whole desk that a human, not a schedule,
drives.
"""
import json
import logging

from telegram import InlineKeyboardButton, InlineKeyboardMarkup, Update
from telegram.ext import Application, CallbackQueryHandler, ContextTypes

import config
import db
import executor

logger = logging.getLogger(__name__)


def format_decision_message(decision_row, trade_plan: dict) -> str:
    return (
        f"\U0001F7E1 NOVA: TRADE proposal (decision #{decision_row['id']})\n\n"
        f"Symbol: {decision_row['symbol']}\n"
        f"Side: {trade_plan.get('side')}\n"
        f"Entry: {trade_plan.get('entry')}\n"
        f"Stop: {trade_plan.get('stop')}\n"
        f"Target: {trade_plan.get('target')}\n"
        f"Suggested qty: {trade_plan.get('suggested_qty')}\n\n"
        f"Reason: {decision_row['reason']}\n\n"
        f"This is a PAPER (testnet) order. Approve only after reading the full agent "
        f"reports in the journal."
    )


async def request_approval(app: Application, decision_id: int, symbol: str, trade_plan: dict):
    decision_row = db.get_decision(decision_id)
    text = format_decision_message(decision_row, trade_plan)
    keyboard = InlineKeyboardMarkup([
        [
            InlineKeyboardButton("✅ Approve (paper order)", callback_data=f"approve:{decision_id}"),
            InlineKeyboardButton("❌ Reject", callback_data=f"reject:{decision_id}"),
        ]
    ])
    await app.bot.send_message(chat_id=config.TELEGRAM_CHAT_ID, text=text, reply_markup=keyboard)


async def on_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    action, decision_id_str = query.data.split(":")
    decision_id = int(decision_id_str)
    decision_row = db.get_decision(decision_id)

    if decision_row is None:
        await query.edit_message_text("Decision not found (database mismatch).")
        return

    if decision_row["human_approved"] is not None:
        await query.edit_message_text(f"{query.message.text}\n\n(Already decided — ignoring.)")
        return

    if action == "approve":
        db.set_human_decision(decision_id, approved=True)
        if not config.TRADING_ENABLED:
            await query.edit_message_text(
                f"{query.message.text}\n\n⚠️ Approved, but TRADING_ENABLED=false — "
                f"no order was sent. Flip the kill switch in .env to actually submit paper orders."
            )
            return
        trade_plan = json.loads(decision_row["trade_plan_json"])
        try:
            result = executor.submit_trade(decision_id, trade_plan)
            await query.edit_message_text(f"{query.message.text}\n\n✅ Approved. {result}")
        except Exception as exc:  # noqa: BLE001 — surface any exchange error to the human
            logger.exception("Order submission failed")
            await query.edit_message_text(f"{query.message.text}\n\n❌ Approved but order FAILED: {exc}")
    else:
        db.set_human_decision(decision_id, approved=False)
        await query.edit_message_text(f"{query.message.text}\n\n❌ Rejected by human. No order sent.")


def build_app() -> Application:
    app = Application.builder().token(config.TELEGRAM_BOT_TOKEN).build()
    app.add_handler(CallbackQueryHandler(on_callback))
    return app

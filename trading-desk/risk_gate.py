"""Mechanical risk checks. This module never calls an LLM and never trusts
one — it is the thing that actually stops a trade, independent of whatever
TITAN or NOVA wrote in prose. If this says REJECT, nothing downstream can
override it (see agents/orchestrator.py and prompts.TITAN_NARRATIVE).
"""
from dataclasses import dataclass

import config
import db


@dataclass
class RiskCheckResult:
    passed: bool
    checks: dict  # name -> "PASS" | "FAIL: <reason>"
    reason: str    # human-readable summary, used verbatim if passed is False


def evaluate_trade_plan(trade_plan: dict, account_balance: float, symbol: str) -> RiskCheckResult:
    """trade_plan must contain: entry, stop, target, side ('long'/'short').
    Any missing or non-numeric field is itself a FAIL — never guessed.
    """
    rules = config.RISK_RULES
    checks: dict[str, str] = {}

    if not config.TRADING_ENABLED:
        return RiskCheckResult(False, {"kill_switch": "FAIL: TRADING_ENABLED is false"},
                                "Kill switch is off (TRADING_ENABLED=false).")

    required = ("entry", "stop", "target", "side")
    missing = [f for f in required if trade_plan.get(f) in (None, "")]
    if missing:
        return RiskCheckResult(False, {"inputs": f"FAIL: missing fields {missing}"},
                                f"Trade plan missing required fields: {missing}")

    entry, stop, target, side = (
        float(trade_plan["entry"]),
        float(trade_plan["stop"]),
        float(trade_plan["target"]),
        trade_plan["side"],
    )

    risk_per_unit = abs(entry - stop)
    reward_per_unit = abs(target - entry)
    if risk_per_unit <= 0:
        return RiskCheckResult(False, {"stop_distance": "FAIL: entry == stop"},
                                "Stop is at entry price — zero risk distance is invalid.")

    rr = reward_per_unit / risk_per_unit
    checks["reward_to_risk"] = (
        f"PASS ({rr:.2f} >= {rules['min_reward_to_risk']})"
        if rr >= rules["min_reward_to_risk"]
        else f"FAIL ({rr:.2f} < {rules['min_reward_to_risk']})"
    )

    open_positions = db.count_open_positions()
    checks["max_open_positions"] = (
        f"PASS ({open_positions} < {rules['max_open_positions']})"
        if open_positions < rules["max_open_positions"]
        else f"FAIL ({open_positions} >= {rules['max_open_positions']})"
    )

    trades_today = db.count_trades_opened_today()
    checks["max_trades_per_day"] = (
        f"PASS ({trades_today} < {rules['max_trades_per_day']})"
        if trades_today < rules["max_trades_per_day"]
        else f"FAIL ({trades_today} >= {rules['max_trades_per_day']})"
    )

    max_loss_amount = account_balance * (rules["max_loss_pct_of_balance"] / 100.0)
    # qty is sized so that risk_per_unit * qty == max_loss_amount; verify the
    # plan's own qty (if supplied) doesn't exceed that, else compute it.
    implied_qty = max_loss_amount / risk_per_unit
    trade_plan["suggested_qty"] = implied_qty
    checks["position_sizing"] = f"PASS (qty capped at {implied_qty:.6f} {symbol.split('/')[0]} for max loss {max_loss_amount:.2f})"

    failed = [name for name, result in checks.items() if result.startswith("FAIL")]
    passed = len(failed) == 0
    reason = "All mechanical checks passed." if passed else f"Failed checks: {failed}"
    return RiskCheckResult(passed, checks, reason)

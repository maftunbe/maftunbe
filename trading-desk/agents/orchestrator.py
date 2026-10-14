"""Runs one full desk cycle for one symbol: ATLAS -> VEGA -> ORION -> LUNA ->
mechanical risk gate -> TITAN narrative -> NOVA. Nothing here submits an
order — the cycle ends at a Decision row; executor.py is a separate,
explicitly human-gated step (see telegram_approval.py).
"""
import json
import re

import config
import data_collector
import db
import risk_gate
from agents import llm_client, prompts


def _extract_json_block(text: str) -> dict:
    match = re.search(r"```json\s*(\{.*?\})\s*```", text, re.DOTALL)
    if not match:
        raise ValueError("NOVA response did not end with a parseable json block")
    return json.loads(match.group(1))


def run_cycle(symbol: str, account_balance: float) -> dict:
    pack = data_collector.build_source_pack(symbol, account_rules=config.RISK_RULES)
    pack_id = db.save_source_pack(symbol, pack)

    reports = {}
    for name, prompt in (
        ("ATLAS", prompts.ATLAS),
        ("VEGA", prompts.VEGA),
        ("ORION", prompts.ORION),
        ("LUNA", prompts.LUNA),
    ):
        output = llm_client.call_agent(prompt, pack, model=config.MODEL_FAST)
        db.save_agent_report(pack_id, name, output)
        reports[name] = output

    # TITAN doesn't get a trade plan to grade yet — NOVA hasn't proposed one.
    # It gets the account's current standing against the hard limits, so its
    # narrative is grounded in the same numbers the mechanical gate will use
    # on NOVA's actual plan below.
    account_standing = {
        "open_positions": db.count_open_positions(),
        "trades_opened_today": db.count_trades_opened_today(),
        "account_balance": account_balance,
        "limits": config.RISK_RULES,
        "kill_switch_enabled": config.TRADING_ENABLED,
    }

    titan_input = {**pack, "reports": reports, "account_standing": account_standing}
    titan_output = llm_client.call_agent(prompts.TITAN_NARRATIVE, titan_input, model=config.MODEL_STRONG)
    db.save_agent_report(pack_id, "TITAN", titan_output)
    reports["TITAN"] = titan_output

    nova_input = {**pack, "reports": reports}
    nova_output = llm_client.call_agent(prompts.NOVA, nova_input, model=config.MODEL_STRONG)
    db.save_agent_report(pack_id, "NOVA", nova_output)

    try:
        nova_json = _extract_json_block(nova_output)
    except ValueError as exc:
        decision_id = db.save_decision(pack_id, symbol, "REJECT", f"Unparseable NOVA output: {exc}", None)
        return {"decision_id": decision_id, "verdict": "REJECT", "nova_text": nova_output}

    verdict = nova_json.get("verdict")

    if verdict == "TRADE":
        trade_plan = {
            "symbol": symbol,
            "entry": nova_json.get("entry"),
            "stop": nova_json.get("stop"),
            "target": nova_json.get("target"),
            "side": nova_json.get("side"),
        }
        final_gate = risk_gate.evaluate_trade_plan(trade_plan, account_balance, symbol)
        if not final_gate.passed:
            # The mechanical gate overrules NOVA. This is the hard veto the
            # guide gives TITAN — enforced in code, not in a prompt.
            decision_id = db.save_decision(pack_id, symbol, "REJECT", final_gate.reason, None)
            return {"decision_id": decision_id, "verdict": "REJECT", "nova_text": nova_output,
                    "override_reason": final_gate.reason}
        # final_gate.evaluate_trade_plan already wrote trade_plan["suggested_qty"] in place.
        decision_id = db.save_decision(pack_id, symbol, "TRADE", nova_json.get("reason", ""), trade_plan)
        return {"decision_id": decision_id, "verdict": "TRADE", "trade_plan": trade_plan,
                "nova_text": nova_output}

    decision_id = db.save_decision(pack_id, symbol, verdict or "WAIT", nova_json.get("reason", ""), None)
    return {"decision_id": decision_id, "verdict": verdict, "nova_text": nova_output}

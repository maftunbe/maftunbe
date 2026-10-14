"""Thin SQLite layer. No ORM — the schema is small and stable enough that
raw SQL stays more readable than a mapping layer.
"""
import json
import sqlite3
from contextlib import contextmanager
from datetime import datetime, timezone

import config

SCHEMA = """
CREATE TABLE IF NOT EXISTS source_packs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    symbol TEXT NOT NULL,
    created_at TEXT NOT NULL,
    data_json TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS agent_reports (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    source_pack_id INTEGER NOT NULL REFERENCES source_packs(id),
    agent_name TEXT NOT NULL,
    output_text TEXT NOT NULL,
    created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS decisions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    source_pack_id INTEGER NOT NULL REFERENCES source_packs(id),
    symbol TEXT NOT NULL,
    verdict TEXT NOT NULL,              -- TRADE / WAIT / REJECT
    reason TEXT NOT NULL,
    trade_plan_json TEXT,               -- entry/stop/target/qty when verdict=TRADE
    created_at TEXT NOT NULL,
    human_approved INTEGER,             -- NULL=pending, 1=approved, 0=rejected
    human_decided_at TEXT
);

CREATE TABLE IF NOT EXISTS trades (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    decision_id INTEGER NOT NULL REFERENCES decisions(id),
    symbol TEXT NOT NULL,
    side TEXT NOT NULL,
    entry_price REAL,
    stop_price REAL,
    target_price REAL,
    qty REAL,
    status TEXT NOT NULL,               -- submitted / filled / closed / failed
    exchange_order_id TEXT,
    opened_at TEXT NOT NULL,
    closed_at TEXT,
    pnl REAL
);
"""


@contextmanager
def connect():
    conn = sqlite3.connect(config.DB_PATH)
    conn.row_factory = sqlite3.Row
    try:
        yield conn
        conn.commit()
    finally:
        conn.close()


def init_db():
    with connect() as conn:
        conn.executescript(SCHEMA)


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def save_source_pack(symbol: str, data: dict) -> int:
    with connect() as conn:
        cur = conn.execute(
            "INSERT INTO source_packs (symbol, created_at, data_json) VALUES (?, ?, ?)",
            (symbol, _now(), json.dumps(data)),
        )
        return cur.lastrowid


def save_agent_report(source_pack_id: int, agent_name: str, output_text: str) -> int:
    with connect() as conn:
        cur = conn.execute(
            "INSERT INTO agent_reports (source_pack_id, agent_name, output_text, created_at) VALUES (?, ?, ?, ?)",
            (source_pack_id, agent_name, output_text, _now()),
        )
        return cur.lastrowid


def save_decision(source_pack_id: int, symbol: str, verdict: str, reason: str, trade_plan: dict | None) -> int:
    with connect() as conn:
        cur = conn.execute(
            "INSERT INTO decisions (source_pack_id, symbol, verdict, reason, trade_plan_json, created_at, human_approved) "
            "VALUES (?, ?, ?, ?, ?, ?, NULL)",
            (source_pack_id, symbol, verdict, reason, json.dumps(trade_plan) if trade_plan else None, _now()),
        )
        return cur.lastrowid


def set_human_decision(decision_id: int, approved: bool):
    with connect() as conn:
        conn.execute(
            "UPDATE decisions SET human_approved = ?, human_decided_at = ? WHERE id = ?",
            (1 if approved else 0, _now(), decision_id),
        )


def get_decision(decision_id: int) -> sqlite3.Row | None:
    with connect() as conn:
        cur = conn.execute("SELECT * FROM decisions WHERE id = ?", (decision_id,))
        return cur.fetchone()


def count_trades_opened_today(symbol: str | None = None) -> int:
    today = datetime.now(timezone.utc).date().isoformat()
    with connect() as conn:
        if symbol:
            cur = conn.execute(
                "SELECT COUNT(*) AS n FROM trades WHERE symbol = ? AND opened_at >= ?",
                (symbol, today),
            )
        else:
            cur = conn.execute("SELECT COUNT(*) AS n FROM trades WHERE opened_at >= ?", (today,))
        return cur.fetchone()["n"]


def count_open_positions() -> int:
    with connect() as conn:
        cur = conn.execute("SELECT COUNT(*) AS n FROM trades WHERE status IN ('submitted', 'filled')")
        return cur.fetchone()["n"]


def save_trade(decision_id: int, symbol: str, side: str, entry: float, stop: float,
                target: float, qty: float, status: str, exchange_order_id: str | None) -> int:
    with connect() as conn:
        cur = conn.execute(
            "INSERT INTO trades (decision_id, symbol, side, entry_price, stop_price, target_price, qty, "
            "status, exchange_order_id, opened_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (decision_id, symbol, side, entry, stop, target, qty, status, exchange_order_id, _now()),
        )
        return cur.lastrowid

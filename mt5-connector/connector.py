"""Read-only MetaTrader 5 history exporter for AI Trading Intelligence.

This module connects to an already-authenticated local MT5 terminal. It does not
accept account passwords and contains no trading/order-placement functions.
"""
from __future__ import annotations

import argparse
import json
import sys
import os
import urllib.error
import urllib.request
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

try:
    import MetaTrader5 as mt5
except ImportError:  # Friendly error when run on a non-Windows/non-MT5 machine.
    mt5 = None


def iso_utc(epoch_seconds: int | float | None) -> str | None:
    if epoch_seconds is None:
        return None
    return datetime.fromtimestamp(epoch_seconds, tz=timezone.utc).isoformat()


def as_number(value: Any) -> float | None:
    return None if value is None else float(value)


def collect_deal(deal: Any) -> dict[str, Any]:
    """Convert one MT5 deal record into a JSON-safe, broker-neutral record."""
    deal_type = int(getattr(deal, "type", -1))
    if deal_type == mt5.DEAL_TYPE_BUY:
        side = "buy"
    elif deal_type == mt5.DEAL_TYPE_SELL:
        side = "sell"
    else:
        side = "other"

    entry_code = int(getattr(deal, "entry", -1))
    entry_names = {
        getattr(mt5, "DEAL_ENTRY_IN", 0): "in",
        getattr(mt5, "DEAL_ENTRY_OUT", 1): "out",
        getattr(mt5, "DEAL_ENTRY_INOUT", 2): "inout",
        getattr(mt5, "DEAL_ENTRY_OUT_BY", 3): "out_by",
    }
    executed = getattr(deal, "time", None)
    return {
        "deal_ticket": str(getattr(deal, "ticket", "")),
        "order_ticket": str(getattr(deal, "order", "")),
        "position_id": str(getattr(deal, "position_id", "")),
        "symbol": str(getattr(deal, "symbol", "") or ""),
        "side": side,
        "deal_type_code": deal_type,
        "entry_type": entry_names.get(entry_code, "unknown"),
        "volume": as_number(getattr(deal, "volume", None)),
        "price": as_number(getattr(deal, "price", None)),
        "profit": as_number(getattr(deal, "profit", 0)) or 0.0,
        "commission": as_number(getattr(deal, "commission", 0)) or 0.0,
        "swap": as_number(getattr(deal, "swap", 0)) or 0.0,
        "fee": as_number(getattr(deal, "fee", 0)) or 0.0,
        "executed_at": iso_utc(executed),
        "time_msc": int(getattr(deal, "time_msc", 0) or 0),
        "comment": str(getattr(deal, "comment", "") or ""),
        "magic": int(getattr(deal, "magic", 0) or 0),
        "reason_code": int(getattr(deal, "reason", -1)),
    }


def collect_position(position: Any) -> dict[str, Any]:
    position_type = int(getattr(position, "type", -1))
    side = "buy" if position_type == mt5.POSITION_TYPE_BUY else "sell"
    return {
        "ticket": str(getattr(position, "ticket", "")),
        "identifier": str(getattr(position, "identifier", "")),
        "symbol": str(getattr(position, "symbol", "") or ""),
        "side": side,
        "volume": as_number(getattr(position, "volume", None)),
        "price_open": as_number(getattr(position, "price_open", None)),
        "price_current": as_number(getattr(position, "price_current", None)),
        "stop_loss": as_number(getattr(position, "sl", None)),
        "take_profit": as_number(getattr(position, "tp", None)),
        "profit": as_number(getattr(position, "profit", None)),
        "swap": as_number(getattr(position, "swap", None)),
        "opened_at": iso_utc(getattr(position, "time", None)),
        "comment": str(getattr(position, "comment", "") or ""),
        "magic": int(getattr(position, "magic", 0) or 0),
    }


def run(args: argparse.Namespace) -> dict[str, Any]:
    if mt5 is None:
        raise RuntimeError(
            "MetaTrader5 Python package is missing. Run this connector on Windows "
            "with the MT5 desktop terminal installed, then install requirements.txt."
        )

    initialized = mt5.initialize(path=args.terminal_path) if args.terminal_path else mt5.initialize()
    if not initialized:
        code, message = mt5.last_error()
        raise RuntimeError(f"Could not connect to the running MT5 terminal ({code}): {message}")

    try:
        account = mt5.account_info()
        if account is None:
            code, message = mt5.last_error()
            raise RuntimeError(f"MT5 account information unavailable ({code}): {message}")

        end = datetime.fromisoformat(args.to).replace(tzinfo=timezone.utc) if args.to else datetime.now(timezone.utc)
        start = datetime.fromisoformat(args.from_date).replace(tzinfo=timezone.utc) if args.from_date else datetime(2000, 1, 1, tzinfo=timezone.utc)
        if start >= end:
            raise ValueError("The --from date must be earlier than --to.")

        deals = mt5.history_deals_get(start, end)
        if deals is None:
            code, message = mt5.last_error()
            raise RuntimeError(f"MT5 history query failed ({code}): {message}")

        positions = mt5.positions_get()
        if positions is None:
            code, message = mt5.last_error()
            raise RuntimeError(f"MT5 open-position query failed ({code}): {message}")

        return {
            "schema_version": "1.0",
            "exported_at": datetime.now(timezone.utc).isoformat(),
            "history_range": {"from": start.isoformat(), "to": end.isoformat()},
            "mode": "read_only",
            "account": {
                "login": str(account.login),
                "server": str(account.server),
                "company": str(getattr(account, "company", "") or ""),
                "currency": str(account.currency),
                "leverage": int(account.leverage),
                "balance": as_number(account.balance),
                "equity": as_number(account.equity),
                "margin": as_number(account.margin),
                "margin_free": as_number(account.margin_free),
                "profit": as_number(account.profit),
                "trade_mode_code": int(account.trade_mode),
            },
            "deals": [collect_deal(deal) for deal in deals],
            "open_positions": [collect_position(position) for position in positions],
            "counts": {"deals": len(deals), "open_positions": len(positions)},
            "security": {
                "password_collected": False,
                "password_stored": False,
                "orders_submitted": False,
                "positions_modified": False,
            },
        }
    finally:
        mt5.shutdown()


def main() -> int:
    parser = argparse.ArgumentParser(description="Export MT5 account history (read-only).")
    parser.add_argument("--from", dest="from_date", help="UTC date/time, e.g. 2025-01-01T00:00:00")
    parser.add_argument("--to", help="UTC date/time; defaults to current UTC time")
    parser.add_argument("--output", default="ati-mt5-export.json", help="Output JSON file")
    parser.add_argument("--terminal-path", help="Optional path to terminal64.exe")
    parser.add_argument("--sync", action="store_true", help="Upload this read-only export to your enrolled AI Trading Intelligence account")
    parser.add_argument("--state-file", default="ati-sync-state.json", help="Local timestamp checkpoint used for incremental sync")
    args = parser.parse_args()

    try:
        state_path = Path(args.state_file).expanduser().resolve()
        if args.sync and not args.from_date and state_path.exists():
            try:
                state = json.loads(state_path.read_text(encoding="utf-8"))
                last_sync = datetime.fromisoformat(state["last_successful_sync"])
                args.from_date = (last_sync - timedelta(days=2)).astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S")
            except Exception:
                print("Sync checkpoint unreadable; starting with full available history.", file=sys.stderr)
        payload = run(args)
        output = Path(args.output).expanduser().resolve()
        output.write_text(json.dumps(payload, indent=2, ensure_ascii=False), encoding="utf-8")
        print(f"Export complete: {output}")
        print(f"Deals: {payload['counts']['deals']} | Open positions: {payload['counts']['open_positions']}")
        print("Read-only export. No MT5 password was requested or stored.")
        if args.sync:
            token = os.environ.get("ATI_CONNECTOR_TOKEN", "").strip()
            if not token:
                raise RuntimeError("Set ATI_CONNECTOR_TOKEN in your Windows environment before using --sync.")
            api_url = os.environ.get("ATI_API_URL", "https://ai-trading-intelligence-api.vercel.app").rstrip("/")
            request = urllib.request.Request(
                api_url + "/connector/sync",
                data=json.dumps(payload, ensure_ascii=False).encode("utf-8"),
                headers={"Authorization": "Bearer " + token, "Content-Type": "application/json"},
                method="POST",
            )
            try:
                with urllib.request.urlopen(request, timeout=120) as response:
                    result = json.loads(response.read().decode("utf-8"))
            except urllib.error.HTTPError as error:
                detail = error.read().decode("utf-8", errors="replace")[:500]
                raise RuntimeError(f"Cloud sync rejected ({error.code}): {detail}") from error
            state_path.write_text(
                json.dumps({"last_successful_sync": payload["history_range"]["to"]}, indent=2),
                encoding="utf-8",
            )
            print("Cloud sync complete:")
            print(json.dumps(result, indent=2))
            print(f"Incremental sync checkpoint saved: {state_path}")
        return 0
    except Exception as exc:
        print(f"Connector error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())

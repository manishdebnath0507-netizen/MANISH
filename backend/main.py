import os
from collections import defaultdict
from datetime import datetime
from zoneinfo import ZoneInfo

import httpx
from fastapi import FastAPI, Header, HTTPException
from fastapi.middleware.cors import CORSMiddleware

SUPABASE_URL = os.environ.get("SUPABASE_URL", "https://kgtypwftbxlnxcxkbqdw.supabase.co").rstrip("/")
SUPABASE_PUBLISHABLE_KEY = os.environ.get("SUPABASE_PUBLISHABLE_KEY", "")
APP_ORIGIN = "https://ai-trading-intelligence-one-space4.vercel.app"

app = FastAPI(title="AI Trading Intelligence API", version="0.2.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=[APP_ORIGIN],
    allow_credentials=True,
    allow_methods=["GET", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type", "apikey", "X-Timezone"],
)

async def get_user_trades(authorization: str | None):
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Sign in is required.")
    if not SUPABASE_PUBLISHABLE_KEY:
        raise HTTPException(status_code=503, detail="API configuration is incomplete.")
    headers = {
        "apikey": SUPABASE_PUBLISHABLE_KEY,
        "Authorization": authorization,
        "Accept": "application/json",
    }
    async with httpx.AsyncClient(timeout=20.0) as client:
        identity = await client.get(f"{SUPABASE_URL}/auth/v1/user", headers=headers)
        if identity.status_code != 200:
            raise HTTPException(status_code=401, detail="Your session is invalid or expired.")
        response = await client.get(
            f"{SUPABASE_URL}/rest/v1/trades",
            headers=headers,
            params={
                "select": "symbol,side,opened_at,closed_at,net_profit,result",
                "closed_at": "not.is.null",
                "order": "closed_at.asc",
                "limit": "5000",
            },
        )
        if response.status_code != 200:
            raise HTTPException(status_code=502, detail="Could not read your trade journal.")
        return response.json()

def parse_time(value: str | None, timezone_name: str):
    if not value:
        return None
    try:
        dt = datetime.fromisoformat(value.replace("Z", "+00:00"))
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=ZoneInfo("UTC"))
        return dt.astimezone(ZoneInfo(timezone_name))
    except Exception:
        return None

def build_metrics(trades: list[dict], timezone_name: str):
    closed = [t for t in trades if t.get("net_profit") is not None]
    values = [float(t.get("net_profit") or 0) for t in closed]
    wins = [v for v in values if v > 0]
    losses = [v for v in values if v < 0]
    gross_profit = sum(wins)
    gross_loss = abs(sum(losses))
    total = sum(values)
    equity = peak = max_drawdown = 0.0
    for value in values:
        equity += value
        peak = max(peak, equity)
        max_drawdown = max(max_drawdown, peak - equity)
    return {
        "closed_trades": len(closed),
        "wins": len(wins),
        "losses": len(losses),
        "breakeven": len(values) - len(wins) - len(losses),
        "win_rate_pct": round((len(wins) / len(values) * 100), 2) if values else 0,
        "net_profit": round(total, 2),
        "gross_profit": round(gross_profit, 2),
        "gross_loss": round(gross_loss, 2),
        "profit_factor": round(gross_profit / gross_loss, 3) if gross_loss else (None if not gross_profit else "infinite"),
        "expectancy": round(total / len(values), 2) if values else 0,
        "max_drawdown_currency": round(max_drawdown, 2),
        "timezone": timezone_name,
        "data_source": "authenticated Supabase trade records",
    }

@app.get("/health")
async def health():
    return {"status": "ok", "service": "ai-trading-intelligence-api", "version": "0.2.0"}

@app.get("/analytics/summary")
async def analytics_summary(
    authorization: str | None = Header(default=None),
    x_timezone: str = Header(default="Asia/Kolkata"),
):
    try:
        ZoneInfo(x_timezone)
    except Exception:
        x_timezone = "Asia/Kolkata"
    trades = await get_user_trades(authorization)
    return build_metrics(trades, x_timezone)

@app.get("/analytics/breakdown")
async def analytics_breakdown(
    authorization: str | None = Header(default=None),
    x_timezone: str = Header(default="Asia/Kolkata"),
):
    try:
        tz = ZoneInfo(x_timezone)
    except Exception:
        tz = ZoneInfo("Asia/Kolkata")
        x_timezone = "Asia/Kolkata"
    trades = await get_user_trades(authorization)
    weekday = defaultdict(lambda: {"trades": 0, "net_profit": 0.0, "wins": 0})
    monthly = defaultdict(lambda: {"trades": 0, "net_profit": 0.0, "wins": 0})
    for trade in trades:
        if trade.get("net_profit") is None:
            continue
        dt = parse_time(trade.get("closed_at") or trade.get("opened_at"), x_timezone)
        if not dt:
            continue
        value = float(trade.get("net_profit") or 0)
        for bucket, key in ((weekday, dt.strftime("%A")), (monthly, dt.strftime("%Y-%m"))):
            bucket[key]["trades"] += 1
            bucket[key]["net_profit"] += value
            bucket[key]["wins"] += int(value > 0)
    def clean(group):
        return {k: {**v, "net_profit": round(v["net_profit"], 2),
                    "win_rate_pct": round(v["wins"] / v["trades"] * 100, 2) if v["trades"] else 0}
                for k, v in group.items()}
    return {
        "timezone": x_timezone,
        "by_weekday": clean(weekday),
        "by_month": clean(monthly),
        "data_source": "authenticated Supabase trade records",
    }

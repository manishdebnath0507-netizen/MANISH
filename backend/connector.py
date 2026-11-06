import hashlib
import json
import os
import secrets
from datetime import datetime

import httpx
from fastapi import APIRouter, Header, HTTPException, Request
from pydantic import BaseModel, Field

SUPABASE_URL = os.environ.get("SUPABASE_URL", "https://kgtypwftbxlnxcxkbqdw.supabase.co").rstrip("/")
SUPABASE_KEY = os.environ.get("SUPABASE_PUBLISHABLE_KEY", "")
API_ORIGIN = "https://ai-trading-intelligence-api.vercel.app"
router = APIRouter(prefix="/connector", tags=["MT5 connector"])


class EnrollRequest(BaseModel):
    account_label: str = Field(default="MT5 trading account", min_length=2, max_length=80)
    device_label: str = Field(default="My Windows PC", min_length=2, max_length=80)
    connector_version: str = Field(default="1.1.0", max_length=30)


async def identify_user(authorization: str | None):
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Sign in is required.")
    if not SUPABASE_KEY:
        raise HTTPException(status_code=503, detail="API configuration is incomplete.")
    headers = {"apikey": SUPABASE_KEY, "Authorization": authorization}
    async with httpx.AsyncClient(timeout=20) as client:
        response = await client.get(f"{SUPABASE_URL}/auth/v1/user", headers=headers)
    if response.status_code != 200:
        raise HTTPException(status_code=401, detail="Your session is invalid or expired.")
    return response.json()


@router.post("/enroll")
async def enroll(body: EnrollRequest, authorization: str | None = Header(default=None)):
    identity = await identify_user(authorization)
    user_id = identity.get("id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Could not identify signed-in user.")
    token = secrets.token_urlsafe(40)
    token_hash = hashlib.sha256(token.encode("utf-8")).hexdigest()
    headers = {
        "apikey": SUPABASE_KEY,
        "Authorization": authorization,
        "Content-Type": "application/json",
        "Prefer": "return=representation",
    }
    async with httpx.AsyncClient(timeout=25) as client:
        account_response = await client.post(
            f"{SUPABASE_URL}/rest/v1/trading_accounts",
            headers=headers,
            json={"user_id": user_id, "platform": "MT5", "account_label": body.account_label, "is_active": True},
        )
        if account_response.status_code not in (200, 201):
            raise HTTPException(status_code=502, detail="Could not create the trading account.")
        account_rows = account_response.json()
        if not account_rows:
            raise HTTPException(status_code=502, detail="Trading account creation was not confirmed.")
        account_id = account_rows[0]["id"]
        connection_response = await client.post(
            f"{SUPABASE_URL}/rest/v1/mt5_connections",
            headers=headers,
            json={
                "user_id": user_id,
                "trading_account_id": account_id,
                "device_label": body.device_label,
                "connector_version": body.connector_version,
                "token_hash": token_hash,
                "status": "active",
                "enrolled_at": datetime.utcnow().isoformat() + "Z",
            },
        )
        if connection_response.status_code not in (200, 201):
            raise HTTPException(status_code=502, detail="Could not enroll the connector. Please retry.")
        connection_rows = connection_response.json()
        if not connection_rows:
            raise HTTPException(status_code=502, detail="Connector enrollment was not confirmed.")
    return {
        "status": "enrolled",
        "account_id": account_id,
        "connection_id": connection_rows[0]["id"],
        "connector_token": token,
        "api_url": API_ORIGIN,
        "read_only": True,
        "warning": "This credential is shown once. Store it securely and revoke it if exposed.",
    }


@router.post("/sync")
async def sync(request: Request, authorization: str | None = Header(default=None)):
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Connector credential is required.")
    token = authorization.split(" ", 1)[1].strip()
    if len(token) < 32 or len(token) > 256:
        raise HTTPException(status_code=401, detail="Connector credential is invalid.")
    raw = await request.body()
    if len(raw) > 12 * 1024 * 1024:
        raise HTTPException(status_code=413, detail="Sync batch is too large. Export a shorter date range.")
    try:
        payload = json.loads(raw)
    except json.JSONDecodeError:
        raise HTTPException(status_code=400, detail="Sync body must be valid JSON.")
    if not isinstance(payload, dict) or payload.get("mode") != "read_only":
        raise HTTPException(status_code=400, detail="Only read-only MT5 payloads are accepted.")
    if not isinstance(payload.get("deals"), list) or len(payload["deals"]) > 10000:
        raise HTTPException(status_code=400, detail="Deal batch must contain no more than 10,000 records.")
    if not SUPABASE_KEY:
        raise HTTPException(status_code=503, detail="API configuration is incomplete.")
    headers = {
        "apikey": SUPABASE_KEY,
        "Content-Type": "application/json",
    }
    async with httpx.AsyncClient(timeout=90) as client:
        response = await client.post(
            f"{SUPABASE_URL}/rest/v1/rpc/ati_sync_mt5",
            headers=headers,
            json={"p_token": token, "p_payload": payload},
        )
    if response.status_code in (401, 403):
        raise HTTPException(status_code=401, detail="Connector credential is invalid or revoked.")
    if response.status_code >= 400:
        raise HTTPException(status_code=400, detail="Sync batch rejected. Check the account history and connector version.")
    return response.json()


@router.get("/connections")
async def list_connections(authorization: str | None = Header(default=None)):
    await identify_user(authorization)
    headers = {"apikey": SUPABASE_KEY, "Authorization": authorization}
    params = {
        "select": "id,device_label,connector_version,status,enrolled_at,last_seen_at,revoked_at,trading_account_id",
        "order": "enrolled_at.desc",
    }
    async with httpx.AsyncClient(timeout=20) as client:
        response = await client.get(
            f"{SUPABASE_URL}/rest/v1/mt5_connections",
            headers=headers,
            params=params,
        )
    if response.status_code != 200:
        raise HTTPException(status_code=502, detail="Could not load your MT5 connectors.")
    return {"connections": response.json()}


@router.post("/revoke/{connection_id}")
async def revoke(connection_id: str, authorization: str | None = Header(default=None)):
    await identify_user(authorization)
    headers = {
        "apikey": SUPABASE_KEY,
        "Authorization": authorization,
        "Content-Type": "application/json",
        "Prefer": "return=representation",
    }
    async with httpx.AsyncClient(timeout=20) as client:
        response = await client.patch(
            f"{SUPABASE_URL}/rest/v1/mt5_connections",
            headers=headers,
            params={"id": f"eq.{connection_id}", "select": "id"},
            json={"status": "revoked", "revoked_at": datetime.utcnow().isoformat() + "Z"},
        )
    if response.status_code not in (200, 204):
        raise HTTPException(status_code=502, detail="Could not revoke the connector.")
    rows = response.json() if response.content else []
    if not rows:
        raise HTTPException(status_code=404, detail="Connector not found or not owned by this account.")
    return {"status": "revoked", "connection_id": connection_id}

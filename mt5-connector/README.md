# MT5 connector (read-only)

This Windows helper reads an MT5 terminal that you have already logged into.
It can export a local JSON file or upload history to your enrolled AI Trading
Intelligence account.

## Safety
- Sign in to your broker inside the official MT5 desktop terminal.
- Never enter your MT5 password into this connector, ChatGPT, or the website.
- The connector cannot place, modify, or close trades.
- The server stores only a hash of the connector credential.
- Keep credentials and exported account history private.

## Enroll
1. Sign in to AI Trading Intelligence.
2. Open Settings and choose **Create secure connector**.
3. Copy the one-time credential and save it securely.
4. Set it as the Windows user environment variable named ATI_CONNECTOR_TOKEN.
5. Close and reopen PowerShell.

## Install
Install Python 3.10+ and the MT5 desktop terminal. Sign in to MT5, then run:

```powershell
py -m venv .venv
.\.venv\Scripts\Activate.ps1
py -m pip install --upgrade pip
pip install -r requirements.txt
```

## Export and sync

```powershell
python connector.py --output ati-mt5-export.json
python connector.py --sync
```

By default, the export requests history from 1 January 2000 through the current
UTC time, subject to the history available in the broker terminal. Use --from
and --to to narrow the date range when necessary.

## Reconciliation
- Broker deal tickets are synchronized idempotently.
- Entry and exit deals are grouped by position identifier.
- Partial closes are accumulated before a position is marked closed.
- Realized P/L includes profit, commission, swap and fees.
- Open positions retain current price and floating P/L separately.
- Netting reversal (INOUT) positions remain in the raw deal ledger for review
  rather than being guessed into a potentially incorrect trade.
- Execution timestamps are normalized to UTC.

The connector reads only. It never sends a trading instruction to MT5.

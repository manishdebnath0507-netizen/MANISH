# MT5 local connector (read-only)

This Windows helper reads trade history from an MT5 desktop terminal that you
have already logged into. It exports a normalized JSON file for the AI Trading
Intelligence import pipeline.

## Safety

- Never enter your MT5 password into this connector or into ChatGPT.
- Log in to your broker inside the official MT5 desktop terminal yourself.
- The connector calls only account/history/position read functions.
- It does not contain order placement, order modification, close-position, or
  account-login code.
- Keep exported JSON private: it contains account identifiers and trading data.

## Install

1. Install the MT5 desktop terminal and sign in normally.
2. Install Python 3.10+ on the same Windows computer.
3. Open PowerShell in this folder and run:

```powershell
py -m venv .venv
.\.venv\Scripts\Activate.ps1
py -m pip install --upgrade pip
pip install -r requirements.txt
```

## Export one year of history

Keep MT5 open and logged in, then run:

```powershell
python connector.py --output ati-mt5-export.json
```

Choose an explicit date range (UTC):

```powershell
python connector.py --from 2025-01-01T00:00:00 --to 2026-01-01T00:00:00 --output ati-history.json
```

If multiple terminals are installed, pass the terminal executable path:

```powershell
python connector.py --terminal-path "C:\Program Files\MetaTrader 5\terminal64.exe"
```

The export includes account metadata, historical deals, open positions, UTC
timestamps, commissions, swaps, fees, and broker deal/order/position identifiers.
It preserves deal-level facts; server-side reconciliation will group entry and
exit deals into positions, including partial closes.

## Current limitation

This first connector stage exports locally only. It does not upload data or
enroll a device yet. The authenticated upload endpoint and revocable connector
enrollment must be completed before exported data is imported into the cloud
journal.
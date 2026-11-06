# MT5 connector — implementation plan

The Windows connector will read from an already authenticated local MetaTrader 5 terminal. It must not request or store the MT5 trading password and must not place, modify or close orders.

Implementation requirements:
- Read-only account, order, deal and position snapshots.
- Explicit account/device enrollment and revocable, rotating connector credentials.
- TLS transport, request signing, replay protection and idempotent sync.
- Backfill and incremental sync with broker/server timestamps and timezone metadata.
- Correct handling of partial closes, commissions, swaps, fees and corrections.
- Local status page and clear disconnect/revoke control.

Do not connect a live account until authentication, authorization, encryption and reconciliation tests pass.
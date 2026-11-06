# AI Trading Intelligence — project status

Last updated: 2026-11-06

## Completed
- [x] Separate repository and Vercel projects (kept separate from ONE SPACE).
- [x] Responsive dashboard prototype with journal, analytics, markets, events, backtesting, strategies and assistant sections.
- [x] Dedicated Supabase project created in Mumbai region (ap-south-1).
- [x] Initial 12-table database schema; RLS enabled on every table.
- [x] Anonymous access revoked from public tables; authenticated access scoped by auth.uid().
- [x] Cross-user ownership enforced by composite foreign keys between accounts, trades, deals, MT5 connections, sync runs, strategies and backtests.
- [x] Supporting indexes added for the composite ownership foreign keys.
- [x] Latest Supabase security advisor check: no findings.
- [x] Authenticated frontend sign-up/sign-in gate and per-user trade journal wiring.
- [x] FastAPI backend verifies Supabase user JWT and reads data through that user's RLS context (no service-role key).
- [x] Frontend and backend production deployments reported READY by Vercel.
- [x] Read-only Windows MT5 collector created: account snapshot, historical deals, open positions, UTC timestamps, commission, swap and fees.
- [x] Connector design explicitly avoids collecting/storing MT5 passwords and contains no trade execution operations.

## Pending implementation and verification
- [ ] Set Supabase Auth Site URL and allowed redirect URL to https://ai-trading-intelligence-one-space4.vercel.app (dashboard setting).
- [ ] Test real sign-up, email confirmation, sign-in and sign-out end to end.
- [ ] Test the Windows MT5 collector on a computer with an authenticated MT5 terminal.
- [ ] Implement secure connector enrollment, revocable device tokens and authenticated upload endpoint.
- [ ] Reconcile MT5 deal records into positions, including partial closes, corrections, fees, swaps and broker/server timezone handling.
- [ ] Build calculated performance analytics from verified deal records and add weekday/month/time-of-day insights.
- [ ] Integrate licensed market prices and economic calendar sources.
- [ ] Build realistic backtesting with spread, commissions, slippage and no look-ahead bias.
- [ ] Add AI analysis grounded in user trades and cited market/event sources.
- [ ] Run full security, privacy, recovery and end-to-end tests.

## Data safety
- Demo rows and overview figures are fictional and are not evidence of trading performance.
- The frontend contains only the Supabase publishable key. Never expose a Supabase secret/service-role key.
- Never ask for or store the user's MT5 trading password.
- MT5 integration is read-only: no placing, modifying or closing trades.
- Local connector exports contain account identifiers and trading history; store them privately.

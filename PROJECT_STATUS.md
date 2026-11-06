# AI Trading Intelligence — project status

Last updated: 2026-11-06

## Completed
- [x] Separate repository and Vercel projects, kept separate from ONE SPACE.
- [x] Responsive trading workspace prototype with journal, analytics, markets, events, backtesting, strategies and assistant sections.
- [x] Dedicated Supabase project in Mumbai (ap-south-1).
- [x] Initial 12-table schema; RLS enabled on all 12 application tables.
- [x] Anonymous direct table access revoked; authenticated rows scoped by auth.uid().
- [x] Composite ownership constraints prevent cross-user account/trade/strategy/backtest references.
- [x] Supabase security advisor checked; one intentional warning remains for the token-guarded SECURITY DEFINER sync RPC callable by anon. The function verifies a high-entropy per-device token hash, uses a fixed search_path, and is the only anonymous write path.
- [x] Supabase canonical schema snapshot and ownership-hardening migration documented.
- [x] Authenticated frontend sign-up/sign-in and per-user trade journal wiring.
- [x] FastAPI verifies Supabase user sessions and reads analytics under the user's RLS context.
- [x] Frontend and backend production deployments previously reached READY.
- [x] Windows MT5 collector reads an already-authenticated terminal; it does not collect/store broker passwords and has no trade execution calls.
- [x] Read-only connector enrollment API creates a per-device credential; only its SHA-256 hash is stored.
- [x] One-time connector enrollment UI added to Settings.
- [x] Revocable connector credentials supported by authenticated revoke endpoint.
- [x] Sync API validates a bounded read-only payload and calls a token-guarded database function; no service-role key is used.
- [x] Database sync function records deals idempotently by broker deal ticket.
- [x] Position reconciliation aggregates partial exits and includes profit, commission, swap and fees.
- [x] Open positions retain mark-to-market price and floating P/L separately from realized P/L.
- [x] MT5 netting reversal (INOUT) records are preserved but excluded from automatic grouping to avoid incorrect assumptions.
- [x] Optional Windows Task Scheduler scripts added for 15-minute sync while user is signed in and MT5 is available.

## Pending verification and development
- [x] Latest frontend and backend production deployments reached READY; backend build completed successfully.
- [ ] Set Supabase Auth Site URL and redirect URL to https://ai-trading-intelligence-one-space4.vercel.app.
- [ ] Test real account sign-up, email confirmation, sign-in and sign-out (requires the user's Supabase Auth URL setting and email confirmation).
- [ ] Enroll and test the connector on the user's Windows computer with MT5 open and signed in.
- [ ] Validate reconciliation against broker-specific examples, including netting reversals, commission-only deals and partial closes.
- [ ] Add UI to list all connected devices and revoke an existing connector after page refresh.
- [ ] Add pagination/incremental sync checkpoints to reduce large full-history uploads.
- [ ] Build detailed weekday, monthly, session, symbol and strategy analytics.
- [ ] Integrate licensed market prices and economic calendar data.
- [ ] Build realistic backtesting with bid/ask, spread, commission, slippage and no look-ahead bias.
- [ ] Add AI analysis grounded in verified trades and cited market/event sources.
- [ ] Complete security, privacy, recovery and end-to-end tests.

## Data safety
- Demo rows and prototype figures are fictional and are not evidence of trading performance.
- The frontend contains only the Supabase publishable key. Never expose a Supabase secret/service-role key.
- Never ask for or store the user's MT5 trading password.
- MT5 integration is read-only: no placing, modifying or closing trades.
- Connector credentials are one-time displayed, hashed in the database and revocable.
- The MT5 sync RPC is intentionally executable by the anon role only because the local device has no Supabase user session; every call must present its high-entropy device token, and the RPC validates the hash before writing. Supabase flags this SECURITY DEFINER pattern for manual review.
- Local connector exports contain account identifiers and trading history; store them privately.
- Scheduled synchronization depends on the user's Windows PC, MT5 terminal and internet connection being available.

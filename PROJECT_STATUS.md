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
- [x] Local incremental sync checkpoint added with a two-day overlap window; broker deal-ticket upserts prevent duplicate records.
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


## 2026-11-06 follow-up hardening
- Tightened the database read-only mode guard with `IS DISTINCT FROM`, so a missing/null mode is rejected even when the RPC is called directly.
- Added authenticated `GET /connector/connections` endpoint. It returns only safe device metadata and never returns connector token hashes.
- Added persistent connected-device list in Settings with enrollment time, last successful sync time, active/revoked state, and revoke action.
- Revoke endpoint now verifies that a row owned by the signed-in user was actually updated; unknown or foreign connection IDs return 404.
- The browser keeps the one-time token display behavior; the raw connector token is never persisted in the database or shown again after refresh.
- These changes are committed to the separate MANISH repository. Live deployment build and end-to-end browser verification are pending.


## 2026-11-06 UI redesign
- Replaced the plain prototype layout with a full dark, premium trading workspace design: branded sidebar, active navigation, compact top bar, responsive cards, performance snapshot, equity-curve illustration, next-step panel, and trading toolkit.
- Reworked all workspace pages: journal, analytics, markets, event intelligence, backtesting, strategies, AI assistant, and settings.
- Added a redesigned sign-in/sign-up screen, clear prototype-data notice, read-only MT5 safety messaging, and device-management presentation.
- Added responsive tablet/mobile navigation, including a persistent mobile Settings entry.
- Preserved the existing Supabase authentication, private trade loading, CSV export, analytics API, MT5 enrollment, token copy, connected-device listing and revoke actions.
- Updated tab handling so sidebar navigation remains in sync when a user opens a page through a dashboard shortcut.
- UI changes are committed on `main`. Vercel's deployment API rejected a manual production redeploy with HTTP 402 because the team hit its daily deployment API limit; the existing production deployment remains the prior build until Vercel accepts a new build. No claim is made that this redesign is already live.

# AI Trading Intelligence — project status

Last updated: 2026-11-06

## Completed
- [x] Separate repository and Vercel project (kept separate from ONE SPACE).
- [x] Responsive dashboard prototype with journal, analytics, markets, events, backtesting, strategies and assistant sections.
- [x] Dedicated Supabase project created in Mumbai region (ap-south-1).
- [x] Initial database schema: 12 tables.
- [x] Row Level Security enabled on all 12 tables.
- [x] Public anonymous role access revoked from public schema tables; authenticated role granted required table access.
- [x] Security advisor check returned no findings.
- [x] Frontend sign-up/sign-in gate wired to Supabase Auth.
- [x] Trade journal reads authenticated user's own trades from Supabase and falls back to clearly labelled illustrative demo rows when empty.
- [x] Production deployment built successfully and Vercel reports READY.
- [x] Vercel SSO protection disabled so the app can be reached publicly; app access is gated by Supabase Auth.

## Pending implementation and verification
- [ ] Set Supabase Auth Site URL and allowed redirect URL to the production domain (dashboard setting not exposed by current integration).
- [ ] Test real sign-up, email confirmation, sign-in and sign-out end to end.
- [ ] Add server-side backend API with verified user JWTs and scoped connector enrollment.
- [ ] Implement Windows MT5 read-only connector; test with an authenticated local terminal.
- [ ] Reconcile MT5 orders, deals, partial closes, fees, swaps and broker/server timezones.
- [ ] Build calculated performance analytics from verified deals.
- [ ] Integrate licensed market prices and economic calendar sources.
- [ ] Build realistic backtesting with spread, commissions, slippage and no look-ahead bias.
- [ ] Add AI analysis grounded in user trades and cited market/event sources.
- [ ] Run full security, privacy, recovery and end-to-end tests.

## Data safety
- Demo rows and overview figures are fictional and must never be interpreted as live performance.
- The frontend contains only the Supabase publishable key. Never expose a Supabase secret/service-role key.
- Never ask for or store the user's MT5 trading password.
- MT5 integration is planned to read from an already authenticated local MT5 terminal and must not place or modify trades.

# AI Trading Intelligence

A private trading analytics and research platform. This is a separate product and repository from ONE SPACE.

## Product scope
- MT5 history synchronization through a local, read-only Windows connector.
- Trade journal with order/deal reconciliation, partial closes, commissions, swaps and timestamps.
- Performance analytics: win rate, net P/L, profit factor, expectancy, drawdown, time-of-day, weekday and monthly breakdowns.
- Multi-asset market workspace.
- Economic calendar and event-impact research with source timestamps.
- Strategy library and realistic historical backtesting.
- AI assistant that analyses verified records and distinguishes facts from hypotheses.

## Current deployment
- Frontend: Vercel project `ai-trading-intelligence`, root directory `frontend`.
- Database and Auth: dedicated Supabase project in Mumbai (`ap-south-1`).\n- Backend: FastAPI on Vercel at https://ai-trading-intelligence-api.vercel.app (health, authenticated analytics summary and weekday/month breakdown).
- Production domain: https://ai-trading-intelligence-one-space4.vercel.app
- Git repository: https://github.com/manishdebnath0507-netizen/MANISH

## Local preview
Open `frontend/index.html` in a modern browser. The UI uses demo records until actual MT5 records are synchronized.

## Database
The initial 12-table schema is documented in `supabase/schema.sql`. All tables have RLS enabled; anonymous access is revoked and authenticated access is scoped by `auth.uid()`.

## Security
- Only the Supabase publishable key is used in the browser; it is safe to expose when RLS is enabled.
- Never expose a Supabase secret/service-role key in frontend code.
- Never request or store an MT5 trading password.
- MT5 connector will read from the already authenticated local MT5 terminal and will not place, modify or close orders.
- Connector credentials must be hashed at rest, scoped, revocable and rotated.

## Development sequence
1. Complete Auth URL setup and test sign-in.
2. Implement the authenticated backend and secure connector enrollment.
3. Implement the read-only MT5 Windows connector and reconcile broker deals.
4. Build analytics from real trades.
5. Add licensed market data and economic events.
6. Build and validate the backtesting engine.
7. Add grounded AI analysis, monitoring and end-to-end security tests.

See `PROJECT_STATUS.md` for completed and pending work. Demo values are fictional and not evidence of trading performance.

# AI Trading Intelligence

A private, personal trading analytics and research platform. This repository is separate from ONE SPACE.

## Product scope
- MT5 trade history synchronization through a local, read-only Windows connector.
- Trade journal with order/deal reconciliation, partial closes, commissions, swaps and timestamps.
- Performance analytics: win rate, net P/L, profit factor, expectancy, drawdown, time-of-day, weekday and monthly breakdowns.
- Market workspace for multiple asset classes.
- Economic calendar and event-impact research with source timestamps.
- Strategy library and realistic historical backtesting.
- AI assistant that analyses the user's own verified records and clearly separates facts from hypotheses.

## Security principles
- Never request or store the user's MT5 trading password.
- Start with read-only broker access; no order placement or modification.
- Keep broker connector credentials server-side, scoped and rotatable.
- Enforce per-user database access with Row Level Security.
- Never present sample data, stale quotes or generated analysis as live facts.

## Current status
The initial UI prototype is a design scaffold only. MT5, live data, authentication, database persistence, AI analysis and backtesting are not yet production-connected. See PROJECT_STATUS.md.

## Local preview
Open `frontend/index.html` in a modern browser. The initial interface uses clearly labelled illustrative data.

## Architecture direction
- Frontend: responsive web application.
- Backend: FastAPI services for connector enrollment, sync and analytics.
- Database/auth: a dedicated Supabase project, separate from ONE SPACE.
- MT5: Windows-side read-only connector using the authenticated MetaTrader 5 terminal.
- Deployment: Vercel for the web application; backend/connector deployment selected after integration tests.

## Development sequence
1. Repository and architecture foundation.
2. Authentication, database schema and RLS.
3. Secure local MT5 connector and trade/deal reconciliation.
4. Verified analytics and journal.
5. Market data and economic calendar integrations.
6. Backtesting engine with spread, fees, slippage and no look-ahead bias.
7. AI analysis, tests, security review and deployment.

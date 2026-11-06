-- AI Trading Intelligence database snapshot.
-- Dedicated Supabase project: kgtypwftbxlnxcxkbqdw (ap-south-1).
-- Apply only to a fresh project; this is a schema snapshot, not a rerunnable migration.

create extension if not exists pgcrypto;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  timezone text not null default 'Asia/Kolkata',
  default_currency text not null default 'USD',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.trading_accounts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  broker text,
  platform text not null default 'MT5',
  account_label text not null,
  account_login text,
  server_name text,
  account_currency text,
  account_type text,
  is_demo boolean,
  is_active boolean not null default true,
  last_synced_at timestamptz,
  created_at timestamptz not null default now(),
  unique (id, user_id),
  unique (user_id, id)
);

create table public.mt5_connections (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  trading_account_id uuid,
  device_label text not null,
  connector_version text,
  token_hash text not null unique,
  status text not null default 'pending' check (status in ('pending','active','revoked','expired')),
  enrolled_at timestamptz,
  last_seen_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  unique (user_id, id),
  foreign key (trading_account_id) references public.trading_accounts(id)
);

create table public.strategies (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  market_scope text,
  timeframe text,
  rules jsonb not null default '{}'::jsonb,
  risk_rules jsonb not null default '{}'::jsonb,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, id)
);

create table public.trades (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  trading_account_id uuid not null references public.trading_accounts(id),
  broker_position_id text,
  symbol text not null,
  side text not null check (side in ('buy','sell')),
  volume numeric not null check (volume > 0),
  opened_at timestamptz not null,
  closed_at timestamptz,
  entry_price numeric,
  exit_price numeric,
  stop_loss numeric,
  take_profit numeric,
  gross_profit numeric,
  commission numeric not null default 0,
  swap numeric not null default 0,
  fees numeric not null default 0,
  net_profit numeric,
  result text check (result in ('win','loss','breakeven') or result is null),
  comment text,
  strategy_id uuid,
  source text not null default 'mt5',
  broker_timezone text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, id),
  foreign key (user_id, trading_account_id) references public.trading_accounts(user_id, id),
  foreign key (user_id, strategy_id) references public.strategies(user_id, id)
);

create table public.trade_deals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  trading_account_id uuid not null references public.trading_accounts(id),
  trade_id uuid,
  broker_deal_id text not null,
  broker_order_id text,
  position_id text,
  symbol text not null,
  deal_type text,
  entry_type text,
  volume numeric,
  price numeric,
  profit numeric not null default 0,
  commission numeric not null default 0,
  swap numeric not null default 0,
  fee numeric not null default 0,
  executed_at timestamptz not null,
  raw_payload jsonb,
  created_at timestamptz not null default now(),
  unique (trading_account_id, broker_deal_id),
  foreign key (user_id, trading_account_id) references public.trading_accounts(user_id, id),
  foreign key (user_id, trade_id) references public.trades(user_id, id)
);

create table public.economic_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  provider text not null,
  provider_event_id text,
  currency text,
  country text,
  title text not null,
  category text,
  impact text check (impact in ('low','medium','high') or impact is null),
  scheduled_at timestamptz not null,
  previous_value text,
  consensus_value text,
  actual_value text,
  source_url text,
  status text not null default 'scheduled',
  created_at timestamptz not null default now(),
  unique (user_id, provider, provider_event_id)
);

create table public.market_watchlist (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  symbol text not null,
  asset_class text,
  provider text,
  created_at timestamptz not null default now(),
  unique (user_id, symbol, provider)
);

create table public.backtest_runs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  strategy_id uuid,
  symbol text not null,
  timeframe text not null,
  start_at timestamptz not null,
  end_at timestamptz not null,
  initial_balance numeric,
  spread_model jsonb not null default '{}'::jsonb,
  commission_model jsonb not null default '{}'::jsonb,
  slippage_model jsonb not null default '{}'::jsonb,
  parameters jsonb not null default '{}'::jsonb,
  metrics jsonb not null default '{}'::jsonb,
  status text not null default 'queued' check (status in ('queued','running','completed','failed')),
  created_at timestamptz not null default now(),
  unique (user_id, id),
  foreign key (user_id, strategy_id) references public.strategies(user_id, id)
);

create table public.backtest_trades (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  backtest_run_id uuid not null references public.backtest_runs(id),
  side text not null check (side in ('buy','sell')),
  opened_at timestamptz not null,
  closed_at timestamptz,
  entry_price numeric,
  exit_price numeric,
  volume numeric,
  gross_profit numeric,
  costs numeric,
  net_profit numeric,
  metadata jsonb not null default '{}'::jsonb,
  foreign key (user_id, backtest_run_id) references public.backtest_runs(user_id, id)
);

create table public.connector_sync_runs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  mt5_connection_id uuid,
  trading_account_id uuid,
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  status text not null default 'running' check (status in ('running','completed','failed')),
  deals_seen integer not null default 0,
  deals_inserted integer not null default 0,
  error_code text,
  error_message text,
  foreign key (user_id, mt5_connection_id) references public.mt5_connections(user_id, id),
  foreign key (user_id, trading_account_id) references public.trading_accounts(user_id, id)
);

create table public.ai_insights (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  insight_type text not null,
  title text not null,
  summary text not null,
  evidence jsonb not null default '{}'::jsonb,
  confidence numeric,
  generated_at timestamptz not null default now(),
  expires_at timestamptz
);

-- Indexes used by journal, analytics, sync, and ownership foreign keys.
create index idx_trades_user_opened on public.trades(user_id, opened_at desc);
create index idx_trades_account_closed on public.trades(trading_account_id, closed_at desc);
create index idx_deals_account_time on public.trade_deals(trading_account_id, executed_at desc);
create index idx_events_user_time on public.economic_events(user_id, scheduled_at);
create index idx_backtest_runs_user_created on public.backtest_runs(user_id, created_at desc);
create index idx_sync_runs_user_started on public.connector_sync_runs(user_id, started_at desc);
create index idx_trading_accounts_user on public.trading_accounts(user_id);
create index idx_mt5_connections_user on public.mt5_connections(user_id);
create index idx_mt5_connections_account on public.mt5_connections(trading_account_id);
create index idx_trade_deals_user on public.trade_deals(user_id);
create index idx_trade_deals_trade on public.trade_deals(trade_id);
create index idx_strategies_user on public.strategies(user_id);
create index idx_economic_events_user on public.economic_events(user_id);
create index idx_market_watchlist_user on public.market_watchlist(user_id);
create index idx_backtest_runs_user on public.backtest_runs(user_id);
create index idx_backtest_runs_strategy on public.backtest_runs(strategy_id);
create index idx_backtest_trades_user on public.backtest_trades(user_id);
create index idx_backtest_trades_run on public.backtest_trades(backtest_run_id);
create index idx_connector_sync_user on public.connector_sync_runs(user_id);
create index idx_connector_sync_connection on public.connector_sync_runs(mt5_connection_id);
create index idx_connector_sync_account on public.connector_sync_runs(trading_account_id);
create index idx_ai_insights_user on public.ai_insights(user_id);

create index idx_trades_owner_account on public.trades(user_id, trading_account_id);
create index idx_trades_owner_strategy on public.trades(user_id, strategy_id);
create index idx_trade_deals_owner_account on public.trade_deals(user_id, trading_account_id);
create index idx_trade_deals_owner_trade on public.trade_deals(user_id, trade_id);
create index idx_mt5_connections_owner_account on public.mt5_connections(user_id, trading_account_id);
create index idx_sync_runs_owner_connection on public.connector_sync_runs(user_id, mt5_connection_id);
create index idx_sync_runs_owner_account on public.connector_sync_runs(user_id, trading_account_id);
create index idx_backtest_runs_owner_strategy on public.backtest_runs(user_id, strategy_id);
create index idx_backtest_trades_owner_run on public.backtest_trades(user_id, backtest_run_id);

-- Row-level security is enabled on all public application tables.
alter table public.profiles enable row level security;
alter table public.trading_accounts enable row level security;
alter table public.mt5_connections enable row level security;
alter table public.trades enable row level security;
alter table public.trade_deals enable row level security;
alter table public.strategies enable row level security;
alter table public.economic_events enable row level security;
alter table public.market_watchlist enable row level security;
alter table public.backtest_runs enable row level security;
alter table public.backtest_trades enable row level security;
alter table public.connector_sync_runs enable row level security;
alter table public.ai_insights enable row level security;

create policy profiles_select_own on public.profiles for select to authenticated using ((select auth.uid()) = id);
create policy profiles_insert_own on public.profiles for insert to authenticated with check ((select auth.uid()) = id);
create policy profiles_update_own on public.profiles for update to authenticated using ((select auth.uid()) = id) with check ((select auth.uid()) = id);

create policy trading_accounts_owner_all on public.trading_accounts for all to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy mt5_connections_owner_all on public.mt5_connections for all to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy trades_owner_all on public.trades for all to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy trade_deals_owner_all on public.trade_deals for all to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy strategies_owner_all on public.strategies for all to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy economic_events_owner_all on public.economic_events for all to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy market_watchlist_owner_all on public.market_watchlist for all to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy backtest_runs_owner_all on public.backtest_runs for all to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy backtest_trades_owner_all on public.backtest_trades for all to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy connector_sync_runs_owner_all on public.connector_sync_runs for all to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy ai_insights_owner_all on public.ai_insights for all to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

revoke all on all tables in schema public from anon;
grant select, insert, update, delete on all tables in schema public to authenticated;

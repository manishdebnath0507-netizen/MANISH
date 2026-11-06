-- AI Trading Intelligence: cross-user ownership hardening
-- Applied to project kgtypwftbxlnxcxkbqdw (Mumbai).
-- These composite relationships prevent a signed-in user from attaching
-- their rows to another user's account, trade, strategy or backtest UUID.

ALTER TABLE public.trading_accounts ADD CONSTRAINT trading_accounts_user_id_id_key UNIQUE (user_id, id);
ALTER TABLE public.trades ADD CONSTRAINT trades_user_id_id_key UNIQUE (user_id, id);
ALTER TABLE public.strategies ADD CONSTRAINT strategies_user_id_id_key UNIQUE (user_id, id);
ALTER TABLE public.backtest_runs ADD CONSTRAINT backtest_runs_user_id_id_key UNIQUE (user_id, id);
ALTER TABLE public.mt5_connections ADD CONSTRAINT mt5_connections_user_id_id_key UNIQUE (user_id, id);

ALTER TABLE public.trades ADD CONSTRAINT trades_account_owner_fkey FOREIGN KEY (user_id, trading_account_id) REFERENCES public.trading_accounts (user_id, id);
ALTER TABLE public.trades ADD CONSTRAINT trades_strategy_owner_fkey FOREIGN KEY (user_id, strategy_id) REFERENCES public.strategies (user_id, id);
ALTER TABLE public.trade_deals ADD CONSTRAINT trade_deals_account_owner_fkey FOREIGN KEY (user_id, trading_account_id) REFERENCES public.trading_accounts (user_id, id);
ALTER TABLE public.trade_deals ADD CONSTRAINT trade_deals_trade_owner_fkey FOREIGN KEY (user_id, trade_id) REFERENCES public.trades (user_id, id);
ALTER TABLE public.mt5_connections ADD CONSTRAINT mt5_connections_account_owner_fkey FOREIGN KEY (user_id, trading_account_id) REFERENCES public.trading_accounts (user_id, id);
ALTER TABLE public.connector_sync_runs ADD CONSTRAINT connector_sync_runs_connection_owner_fkey FOREIGN KEY (user_id, mt5_connection_id) REFERENCES public.mt5_connections (user_id, id);
ALTER TABLE public.connector_sync_runs ADD CONSTRAINT connector_sync_runs_account_owner_fkey FOREIGN KEY (user_id, trading_account_id) REFERENCES public.trading_accounts (user_id, id);
ALTER TABLE public.backtest_runs ADD CONSTRAINT backtest_runs_strategy_owner_fkey FOREIGN KEY (user_id, strategy_id) REFERENCES public.strategies (user_id, id);
ALTER TABLE public.backtest_trades ADD CONSTRAINT backtest_trades_run_owner_fkey FOREIGN KEY (user_id, backtest_run_id) REFERENCES public.backtest_runs (user_id, id);

CREATE INDEX IF NOT EXISTS idx_trades_owner_account ON public.trades(user_id, trading_account_id);
CREATE INDEX IF NOT EXISTS idx_trades_owner_strategy ON public.trades(user_id, strategy_id);
CREATE INDEX IF NOT EXISTS idx_trade_deals_owner_account ON public.trade_deals(user_id, trading_account_id);
CREATE INDEX IF NOT EXISTS idx_trade_deals_owner_trade ON public.trade_deals(user_id, trade_id);
CREATE INDEX IF NOT EXISTS idx_mt5_connections_owner_account ON public.mt5_connections(user_id, trading_account_id);
CREATE INDEX IF NOT EXISTS idx_sync_runs_owner_connection ON public.connector_sync_runs(user_id, mt5_connection_id);
CREATE INDEX IF NOT EXISTS idx_sync_runs_owner_account ON public.connector_sync_runs(user_id, trading_account_id);
CREATE INDEX IF NOT EXISTS idx_backtest_runs_owner_strategy ON public.backtest_runs(user_id, strategy_id);
CREATE INDEX IF NOT EXISTS idx_backtest_trades_owner_run ON public.backtest_trades(user_id, backtest_run_id);

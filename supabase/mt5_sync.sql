-- MT5 connector enrollment and idempotent synchronization.
-- This migration has already been applied to the dedicated live project.
create extension if not exists pgcrypto with schema extensions;

alter table public.trading_accounts
  add column if not exists company text,
  add column if not exists balance numeric,
  add column if not exists equity numeric,
  add column if not exists margin numeric,
  add column if not exists margin_free numeric,
  add column if not exists leverage integer,
  add column if not exists trade_mode_code integer;

alter table public.trades
  add column if not exists current_price numeric,
  add column if not exists floating_profit numeric;

create unique index if not exists uq_trades_account_position
  on public.trades(trading_account_id, broker_position_id)
  where broker_position_id is not null;

create unique index if not exists uq_trading_accounts_owner_login_server
  on public.trading_accounts(user_id, account_login, server_name)
  where account_login is not null and server_name is not null;

create or replace function public.ati_sync_mt5(p_token text, p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_conn public.mt5_connections%rowtype;
  v_account public.trading_accounts%rowtype;
  v_item jsonb;
  v_seen integer := 0;
  v_synced integer := 0;
  v_trade_count integer := 0;
  v_rows integer := 0;
  v_pos record;
  v_trade_id uuid;
  v_closed boolean;
  v_net numeric;
begin
  if p_token is null or length(p_token) < 32 then
    raise exception 'Invalid connector credential' using errcode = '28000';
  end if;
  if p_payload is null or jsonb_typeof(p_payload) <> 'object'
     or p_payload->>'mode' <> 'read_only' then
    raise exception 'Invalid read-only connector payload' using errcode = '22023';
  end if;
  if jsonb_typeof(p_payload->'deals') <> 'array'
     or jsonb_array_length(p_payload->'deals') > 10000 then
    raise exception 'Invalid deal batch size' using errcode = '22023';
  end if;
  if jsonb_typeof(p_payload->'account') <> 'object' then
    raise exception 'Account metadata is missing' using errcode = '22023';
  end if;

  select * into v_conn
  from public.mt5_connections
  where token_hash = encode(digest(convert_to(p_token, 'UTF8'), 'sha256'), 'hex')
    and status = 'active'
    and revoked_at is null
  for update;

  if not found then
    raise exception 'Connector credential is invalid or revoked' using errcode = '28000';
  end if;

  select * into v_account
  from public.trading_accounts
  where id = v_conn.trading_account_id and user_id = v_conn.user_id
  for update;

  if not found then
    raise exception 'Linked trading account was not found' using errcode = '23503';
  end if;

  if coalesce(p_payload->'account'->>'login','') = ''
     or coalesce(p_payload->'account'->>'server','') = '' then
    raise exception 'MT5 account login and server are required' using errcode = '22023';
  end if;

  if v_account.account_login is not null
     and (v_account.account_login <> p_payload->'account'->>'login'
       or v_account.server_name <> p_payload->'account'->>'server') then
    raise exception 'This connector is linked to a different MT5 account' using errcode = '22023';
  end if;

  update public.trading_accounts set
    account_login = p_payload->'account'->>'login',
    server_name = p_payload->'account'->>'server',
    broker = coalesce(nullif(p_payload->'account'->>'company',''), broker),
    company = nullif(p_payload->'account'->>'company',''),
    account_currency = p_payload->'account'->>'currency',
    balance = nullif(p_payload->'account'->>'balance','')::numeric,
    equity = nullif(p_payload->'account'->>'equity','')::numeric,
    margin = nullif(p_payload->'account'->>'margin','')::numeric,
    margin_free = nullif(p_payload->'account'->>'margin_free','')::numeric,
    leverage = nullif(p_payload->'account'->>'leverage','')::integer,
    trade_mode_code = nullif(p_payload->'account'->>'trade_mode_code','')::integer,
    last_synced_at = now()
  where id = v_account.id and user_id = v_conn.user_id;

  for v_item in select value from jsonb_array_elements(p_payload->'deals')
  loop
    if coalesce(v_item->>'deal_ticket','') = ''
       or coalesce(v_item->>'executed_at','') = ''
       or coalesce(v_item->>'symbol','') = '' then
      raise exception 'A deal is missing its broker ticket, symbol, or execution time' using errcode = '22023';
    end if;
    v_seen := v_seen + 1;
    insert into public.trade_deals (
      user_id, trading_account_id, broker_deal_id, broker_order_id, position_id,
      symbol, deal_type, entry_type, volume, price, profit, commission, swap, fee,
      executed_at, raw_payload
    ) values (
      v_conn.user_id, v_account.id, v_item->>'deal_ticket', nullif(v_item->>'order_ticket',''),
      nullif(v_item->>'position_id',''), v_item->>'symbol', v_item->>'side',
      v_item->>'entry_type', nullif(v_item->>'volume','')::numeric,
      nullif(v_item->>'price','')::numeric, coalesce(nullif(v_item->>'profit','')::numeric,0),
      coalesce(nullif(v_item->>'commission','')::numeric,0),
      coalesce(nullif(v_item->>'swap','')::numeric,0),
      coalesce(nullif(v_item->>'fee','')::numeric,0),
      (v_item->>'executed_at')::timestamptz, v_item
    )
    on conflict (trading_account_id, broker_deal_id) do update set
      broker_order_id = excluded.broker_order_id,
      position_id = excluded.position_id,
      symbol = excluded.symbol,
      deal_type = excluded.deal_type,
      entry_type = excluded.entry_type,
      volume = excluded.volume,
      price = excluded.price,
      profit = excluded.profit,
      commission = excluded.commission,
      swap = excluded.swap,
      fee = excluded.fee,
      executed_at = excluded.executed_at,
      raw_payload = excluded.raw_payload;
    get diagnostics v_rows = row_count;
    v_synced := v_synced + v_rows;
  end loop;

  -- Rebuild positions from the deal ledger. Partial exits are accumulated.
  -- Netting reversals (INOUT) remain in raw deals and are excluded from
  -- automatic position grouping rather than being guessed incorrectly.
  for v_pos in
    select
      d.position_id,
      (array_agg(d.symbol order by d.executed_at) filter (where d.entry_type = 'in'))[1] as symbol,
      (array_agg(d.deal_type order by d.executed_at) filter (where d.entry_type = 'in'))[1] as side,
      min(d.executed_at) filter (where d.entry_type = 'in') as opened_at,
      max(d.executed_at) filter (where d.entry_type in ('out','out_by')) as last_exit_at,
      sum(d.volume) filter (where d.entry_type = 'in') as opened_volume,
      sum(d.volume) filter (where d.entry_type in ('out','out_by')) as closed_volume,
      sum(d.price*d.volume) filter (where d.entry_type = 'in') /
        nullif(sum(d.volume) filter (where d.entry_type = 'in'),0) as entry_price,
      sum(d.price*d.volume) filter (where d.entry_type in ('out','out_by')) /
        nullif(sum(d.volume) filter (where d.entry_type in ('out','out_by')),0) as exit_price,
      sum(d.profit) as gross_profit,
      sum(d.commission) as commission,
      sum(d.swap) as swap,
      sum(d.fee) as fees,
      bool_or(d.entry_type = 'inout') as has_reversal
    from public.trade_deals d
    where d.user_id = v_conn.user_id
      and d.trading_account_id = v_account.id
      and d.position_id is not null
    group by d.position_id
    having bool_or(d.entry_type = 'in')
  loop
    if v_pos.has_reversal then continue; end if;
    v_closed := coalesce(v_pos.closed_volume,0) >= coalesce(v_pos.opened_volume,0) - 0.00000001
      and coalesce(v_pos.opened_volume,0) > 0;
    v_net := coalesce(v_pos.gross_profit,0) + coalesce(v_pos.commission,0)
      + coalesce(v_pos.swap,0) + coalesce(v_pos.fees,0);

    insert into public.trades (
      user_id, trading_account_id, broker_position_id, symbol, side, volume,
      opened_at, closed_at, entry_price, exit_price, gross_profit, commission,
      swap, fees, net_profit, result, source, updated_at
    ) values (
      v_conn.user_id, v_account.id, v_pos.position_id, v_pos.symbol, v_pos.side,
      v_pos.opened_volume, v_pos.opened_at,
      case when v_closed then v_pos.last_exit_at else null end,
      v_pos.entry_price, case when v_closed then v_pos.exit_price else null end,
      case when v_closed then v_pos.gross_profit else null end,
      coalesce(v_pos.commission,0), coalesce(v_pos.swap,0), coalesce(v_pos.fees,0),
      case when v_closed then v_net else null end,
      case when not v_closed then null when v_net > 0 then 'win' when v_net < 0 then 'loss' else 'breakeven' end,
      'mt5', now()
    )
    on conflict (trading_account_id, broker_position_id) where broker_position_id is not null
    do update set
      symbol = excluded.symbol, side = excluded.side, volume = excluded.volume,
      opened_at = excluded.opened_at, closed_at = excluded.closed_at,
      entry_price = excluded.entry_price, exit_price = excluded.exit_price,
      gross_profit = excluded.gross_profit, commission = excluded.commission,
      swap = excluded.swap, fees = excluded.fees, net_profit = excluded.net_profit,
      result = excluded.result, updated_at = now()
    returning id into v_trade_id;

    update public.trade_deals set trade_id = v_trade_id
      where user_id = v_conn.user_id
        and trading_account_id = v_account.id
        and position_id = v_pos.position_id;
    v_trade_count := v_trade_count + 1;
  end loop;

  -- Current open positions retain mark-to-market data separately from realized P/L.
  if jsonb_typeof(p_payload->'open_positions') = 'array' then
    for v_item in select value from jsonb_array_elements(p_payload->'open_positions')
    loop
      if coalesce(v_item->>'identifier','') = '' then continue; end if;
      insert into public.trades (
        user_id, trading_account_id, broker_position_id, symbol, side, volume,
        opened_at, entry_price, stop_loss, take_profit, current_price,
        floating_profit, source, updated_at
      ) values (
        v_conn.user_id, v_account.id, v_item->>'identifier', v_item->>'symbol',
        v_item->>'side', nullif(v_item->>'volume','')::numeric,
        (v_item->>'opened_at')::timestamptz,
        nullif(v_item->>'price_open','')::numeric,
        nullif(v_item->>'stop_loss','')::numeric,
        nullif(v_item->>'take_profit','')::numeric,
        nullif(v_item->>'price_current','')::numeric,
        nullif(v_item->>'profit','')::numeric, 'mt5', now()
      )
      on conflict (trading_account_id, broker_position_id) where broker_position_id is not null
      do update set current_price = excluded.current_price,
        floating_profit = excluded.floating_profit, stop_loss = excluded.stop_loss,
        take_profit = excluded.take_profit, updated_at = now()
      where public.trades.closed_at is null;
    end loop;
  end if;

  update public.mt5_connections set last_seen_at = now(), status = 'active'
    where id = v_conn.id and user_id = v_conn.user_id;
  insert into public.connector_sync_runs (
    user_id, mt5_connection_id, trading_account_id, completed_at,
    status, deals_seen, deals_inserted
  ) values (
    v_conn.user_id, v_conn.id, v_account.id, now(), 'completed', v_seen, v_synced
  );

  return jsonb_build_object(
    'status','ok', 'deals_seen',v_seen, 'deals_synced',v_synced,
    'positions_reconciled',v_trade_count, 'read_only',true,
    'message','MT5 history synchronized. Netting reversals remain as raw deals for review.'
  );
end;
$$;

revoke all on function public.ati_sync_mt5(text,jsonb) from public;
revoke all on function public.ati_sync_mt5(text,jsonb) from authenticated;
grant execute on function public.ati_sync_mt5(text,jsonb) to anon;

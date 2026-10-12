-- Slice 2: holdings, transactions, rupiah savings and kantong cash, capital
-- cashflow, daily snapshots and unit performance.
-- See docs/prd.md 6.2.6, 6.4, 6.6, 7.7-7.9 and docs/hld.md 5.2, 6.2, 6.3.
--
-- Write paths go through security definer RPCs that check auth.uid(), so the
-- system-filled columns (flow_kind, counted_on, positions) stay consistent.
-- The client reads its own rows directly under RLS.

-- Custom SQLSTATEs, mapped to Indonesian messages in lib/core/errors:
--   KKN01  balance or position would go negative on some date (PRD F-TX-4)
--   KKD01  transaction date in the future or before the holding's opening
--   KKC01  kantong cash cannot be switched off while it holds money
--   KKH01  holding not found or not the caller's
--   KKA01  amount must be positive

-- ---------------------------------------------------------------------------
-- holdings
-- ---------------------------------------------------------------------------
create table public.holdings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid()
    references public.profiles (user_id) on delete cascade,
  portfolio_id uuid not null,
  category text not null
    check (category in ('gold', 'crypto', 'stock', 'mutual_fund', 'deposit',
                        'savings_idr', 'savings_fx', 'receivable', 'debt',
                        'cash')),
  name text not null
    check (name = btrim(name) and char_length(name) between 1 and 60),
  currency text not null default 'IDR' check (currency ~ '^[A-Z]{3,5}$'),
  params jsonb not null default '{}'::jsonb
    check (jsonb_typeof(params) = 'object'),
  started_on date not null default private.today_wib(),
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, user_id),
  -- NO ACTION (checked at the end of the statement) so deleting an account
  -- cascades cleanly, while deleting a kantong that still has holdings fails.
  foreign key (portfolio_id, user_id)
    references public.portfolios (id, user_id),
  -- Rupiah savings: the form is only a label (PRD 6.2.6).
  check (category <> 'savings_idr' or (
    currency = 'IDR' and params ->> 'form' in ('rekening', 'tunai'))),
  check (category <> 'cash' or currency = 'IDR')
);

-- One cash holding per kantong (HLD D-6; kantong cash is always rupiah).
create unique index holdings_one_cash_per_portfolio
  on public.holdings (portfolio_id) where category = 'cash';
create index holdings_user_portfolio on public.holdings (user_id, portfolio_id);

create trigger holdings_touch_updated_at
  before update on public.holdings
  for each row execute function private.touch_updated_at();

alter table public.holdings enable row level security;

create policy "own holdings" on public.holdings
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

revoke all on public.holdings from anon, authenticated;
grant select, delete on public.holdings to authenticated;
grant update (name, params, archived_at) on public.holdings to authenticated;

-- ---------------------------------------------------------------------------
-- transactions
-- ---------------------------------------------------------------------------
create table public.transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid()
    references public.profiles (user_id) on delete cascade,
  holding_id uuid not null,
  tx_date date not null,
  type text not null
    check (type in ('opening', 'buy', 'sell', 'deposit', 'withdraw', 'adjust',
                    'dividend', 'transfer_in', 'transfer_out', 'borrow',
                    'repay', 'write_off')),
  -- Quantity in the holding's unit (rupiah for savings and cash). Positive,
  -- except `adjust`, which carries the signed change.
  qty numeric not null check (qty <> 0),
  price numeric check (price >= 0),
  -- Rupiah value of the row, always positive; direction comes from `type`.
  amount numeric not null check (amount >= 0),
  fee numeric not null default 0 check (fee >= 0),
  tax numeric not null default 0 check (tax >= 0),
  reason text check (reason in ('tp', 'cut_loss', 'other')),
  -- HLD 6.2: external_in/out = capital cashflow; `none` on an opening row
  -- means "starting capital" (PRD A-14).
  flow_kind text not null
    check (flow_kind in ('external_in', 'external_out', 'internal', 'income',
                         'expense', 'none')),
  group_id uuid,
  realized_pl numeric,
  -- Snapshot date that first included this row (HLD 5.2 step 4).
  counted_on date,
  note text check (char_length(note) <= 280),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (holding_id, user_id)
    references public.holdings (id, user_id) on delete cascade,
  check (type = 'adjust' or qty > 0)
);

create unique index transactions_one_opening
  on public.transactions (holding_id) where type = 'opening';
create index transactions_holding_order
  on public.transactions (holding_id, tx_date, created_at);
create index transactions_uncounted
  on public.transactions (user_id) where counted_on is null;

create trigger transactions_touch_updated_at
  before update on public.transactions
  for each row execute function private.touch_updated_at();

alter table public.transactions enable row level security;

create policy "own transactions" on public.transactions
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

revoke all on public.transactions from anon, authenticated;
grant select, delete on public.transactions to authenticated;

-- ---------------------------------------------------------------------------
-- holding_positions: derived, rebuilt per holding on every change (HLD D-7).
-- ---------------------------------------------------------------------------
create table public.holding_positions (
  holding_id uuid primary key references public.holdings (id) on delete cascade,
  user_id uuid not null references public.profiles (user_id) on delete cascade,
  qty numeric not null default 0,
  avg_price numeric,
  buy_fee_per_unit numeric not null default 0,
  realized_pl_total numeric not null default 0,
  computed_at timestamptz not null default now()
);

alter table public.holding_positions enable row level security;

create policy "read own positions" on public.holding_positions
  for select to authenticated
  using (user_id = (select auth.uid()));

revoke all on public.holding_positions from anon, authenticated;
grant select on public.holding_positions to authenticated;

-- Sign of a row's quantity on the position.
create or replace function private.qty_sign(p_type text)
returns integer
language sql
immutable
set search_path = ''
as $$
  select case
    when p_type in ('opening', 'buy', 'deposit', 'dividend', 'transfer_in',
                    'borrow', 'adjust') then 1
    else -1
  end
$$;

-- Replays every transaction of one holding in date order (HLD D-7).
-- Slice 2 needs quantity only; avg price arrives with the asset slices.
-- Rejects any history where the quantity dips below zero on some date.
create or replace function private.recalc_holding(p_holding uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid;
  v_qty numeric := 0;
  r record;
begin
  select user_id into v_user from public.holdings where id = p_holding;
  if not found then
    return; -- holding is being deleted
  end if;

  for r in
    select t.tx_date, t.type, t.qty
    from public.transactions t
    where t.holding_id = p_holding
    order by t.tx_date, private.qty_sign(t.type) desc, t.created_at, t.id
  loop
    v_qty := v_qty + private.qty_sign(r.type) * r.qty;
    if v_qty < 0 then
      raise exception 'balance would go negative on %', r.tx_date
        using errcode = 'KKN01';
    end if;
  end loop;

  insert into public.holding_positions (holding_id, user_id, qty, avg_price,
                                        computed_at)
  values (p_holding, v_user, v_qty, null, now())
  on conflict (holding_id) do update
    set qty = excluded.qty, avg_price = excluded.avg_price,
        computed_at = excluded.computed_at;
end;
$$;

-- ---------------------------------------------------------------------------
-- Cashflow corrections (HLD H-2): editing or deleting a row that a snapshot
-- already counted does not rewrite history; the difference goes into the
-- next snapshot as a cashflow.
-- ---------------------------------------------------------------------------
create table private.cashflow_corrections (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles (user_id) on delete cascade,
  portfolio_id uuid not null,
  amount numeric not null,
  transaction_id uuid,
  created_at timestamptz not null default now(),
  counted_on date
);

create index cashflow_corrections_uncounted
  on private.cashflow_corrections (user_id) where counted_on is null;

-- Signed capital value of a row: setoran +, penarikan -, and the opening
-- balance counted as starting capital +. Everything else moves money inside
-- the tracked system and is not capital (PRD 7.7).
create or replace function private.capital_value(
  p_type text, p_flow_kind text, p_amount numeric)
returns numeric
language sql
immutable
set search_path = ''
as $$
  select case
    when p_flow_kind = 'external_in' then p_amount
    when p_flow_kind = 'external_out' then -p_amount
    when p_type = 'opening' and p_flow_kind = 'none' then p_amount
    else 0
  end
$$;

create or replace function private.transactions_after_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_old numeric := 0;
  v_new numeric := 0;
  v_portfolio uuid;
begin
  -- Account deletion cascades through here; nothing to correct.
  if not exists (select 1 from public.profiles
                 where user_id = coalesce(new.user_id, old.user_id)) then
    return null;
  end if;

  if tg_op in ('UPDATE', 'DELETE') and old.counted_on is not null then
    v_old := private.capital_value(old.type, old.flow_kind, old.amount);
    if tg_op = 'UPDATE' then
      v_new := private.capital_value(new.type, new.flow_kind, new.amount);
    end if;
    if v_new <> v_old then
      select portfolio_id into v_portfolio
      from public.holdings where id = old.holding_id;
      if v_portfolio is not null then
        insert into private.cashflow_corrections
          (user_id, portfolio_id, amount, transaction_id)
        values (old.user_id, v_portfolio, v_new - v_old, old.id);
      end if;
    end if;
  end if;

  perform private.recalc_holding(coalesce(new.holding_id, old.holding_id));
  return null;
end;
$$;

create trigger transactions_after_change
  after insert or update or delete on public.transactions
  for each row execute function private.transactions_after_change();

-- Deleting a holding cascades to its transactions after the holding row is
-- gone, so the per-row trigger cannot find its kantong. Book the capital the
-- counted rows carried as one correction up front.
create or replace function private.holdings_before_delete()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_capital numeric;
begin
  if not exists (select 1 from public.profiles where user_id = old.user_id) then
    return old;
  end if;
  select coalesce(sum(private.capital_value(t.type, t.flow_kind, t.amount)), 0)
    into v_capital
  from public.transactions t
  where t.holding_id = old.id and t.counted_on is not null;
  if v_capital <> 0 then
    insert into private.cashflow_corrections (user_id, portfolio_id, amount)
    values (old.user_id, old.portfolio_id, -v_capital);
  end if;
  return old;
end;
$$;

create trigger holdings_before_delete
  before delete on public.holdings
  for each row execute function private.holdings_before_delete();

-- ---------------------------------------------------------------------------
-- Kantong cash cannot be switched off while it holds money.
-- ---------------------------------------------------------------------------
create or replace function private.portfolios_guard_cash()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if old.cash_enabled and not new.cash_enabled and exists (
    select 1
    from public.holdings h
    join public.holding_positions p on p.holding_id = h.id
    where h.portfolio_id = new.id and h.category = 'cash' and p.qty <> 0
  ) then
    raise exception 'kantong cash still holds money' using errcode = 'KKC01';
  end if;
  return new;
end;
$$;

create trigger portfolios_guard_cash
  before update of cash_enabled on public.portfolios
  for each row execute function private.portfolios_guard_cash();

-- An empty, unused cash holding does not count as content: deleting the
-- kantong takes it along. Anything else blocks the delete (PRD F-PF-1).
create or replace function private.portfolios_drop_unused_cash()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.holdings h
  where h.portfolio_id = old.id and h.category = 'cash'
    and not exists (select 1 from public.transactions t
                    where t.holding_id = h.id);
  return old;
end;
$$;

create trigger portfolios_drop_unused_cash
  before delete on public.portfolios
  for each row execute function private.portfolios_drop_unused_cash();

-- ---------------------------------------------------------------------------
-- Write RPCs
-- ---------------------------------------------------------------------------
create or replace function private.require_uid()
returns uuid
language plpgsql
stable
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'not signed in' using errcode = '28000';
  end if;
  return v_uid;
end;
$$;

-- The caller's holding, locked, or KKH01.
create or replace function private.own_holding(p_holding uuid)
returns public.holdings
language plpgsql
set search_path = ''
as $$
declare
  h public.holdings;
begin
  select * into h from public.holdings
  where id = p_holding and user_id = private.require_uid()
  for update;
  if not found then
    raise exception 'holding not found' using errcode = 'KKH01';
  end if;
  return h;
end;
$$;

create or replace function private.check_tx_date(h public.holdings, p_on date)
returns void
language plpgsql
stable
set search_path = ''
as $$
begin
  if p_on is null or p_on > private.today_wib() then
    raise exception 'date is in the future' using errcode = 'KKD01';
  end if;
  if p_on < h.started_on then
    raise exception 'date is before the opening balance (%)', h.started_on
      using errcode = 'KKD01';
  end if;
end;
$$;

create or replace function private.check_amount(p_amount numeric)
returns void
language plpgsql
immutable
set search_path = ''
as $$
begin
  if p_amount is null or p_amount <= 0 then
    raise exception 'amount must be positive' using errcode = 'KKA01';
  end if;
end;
$$;

-- The kantong's cash holding, created on first use (HLD D-6).
create or replace function public.portfolio_cash_holding(p_portfolio uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_uid();
  v_id uuid;
  v_enabled boolean;
begin
  select cash_enabled into v_enabled from public.portfolios
  where id = p_portfolio and user_id = v_uid;
  if not found then
    raise exception 'kantong not found' using errcode = 'KKH01';
  end if;

  select id into v_id from public.holdings
  where portfolio_id = p_portfolio and category = 'cash';
  if v_id is not null then
    return v_id;
  end if;

  if not v_enabled then
    raise exception 'kantong cash is off' using errcode = 'KKC01';
  end if;

  insert into public.holdings (user_id, portfolio_id, category, name, started_on)
  values (v_uid, p_portfolio, 'cash', 'Kas',
          (select tracking_started_on from public.profiles
           where user_id = v_uid))
  returning id into v_id;
  insert into public.holding_positions (holding_id, user_id, qty)
  values (v_id, v_uid, 0);
  return v_id;
end;
$$;

-- Opening balance of a rupiah holding (savings or kantong cash).
-- p_as_deposit null = default rule in private.opening_flow_kind.
create or replace function public.record_opening(
  p_holding uuid, p_amount numeric, p_on date default null,
  p_as_deposit boolean default null)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  h public.holdings := private.own_holding(p_holding);
  v_on date := coalesce(p_on, private.today_wib());
  v_id uuid;
begin
  perform private.check_amount(p_amount);
  if v_on > private.today_wib() then
    raise exception 'date is in the future' using errcode = 'KKD01';
  end if;
  if exists (select 1 from public.transactions
             where holding_id = h.id and tx_date < v_on) then
    raise exception 'opening must come before other transactions'
      using errcode = 'KKD01';
  end if;

  update public.holdings set started_on = v_on where id = h.id;
  insert into public.transactions
    (user_id, holding_id, tx_date, type, qty, price, amount, flow_kind)
  values (h.user_id, h.id, v_on, 'opening', p_amount, 1, p_amount,
          private.opening_flow_kind(h.user_id, p_as_deposit))
  returning id into v_id;
  return v_id;
end;
$$;

-- New rupiah savings holding (PRD 6.2.6) with its opening balance.
create or replace function public.create_savings(
  p_portfolio uuid, p_name text, p_form text, p_amount numeric,
  p_on date default null, p_as_deposit boolean default null)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_uid();
  v_id uuid;
begin
  if not exists (select 1 from public.portfolios
                 where id = p_portfolio and user_id = v_uid) then
    raise exception 'kantong not found' using errcode = 'KKH01';
  end if;

  insert into public.holdings
    (user_id, portfolio_id, category, name, params, started_on)
  values (v_uid, p_portfolio, 'savings_idr', btrim(p_name),
          jsonb_build_object('form', p_form),
          coalesce(p_on, private.today_wib()))
  returning id into v_id;
  insert into public.holding_positions (holding_id, user_id, qty)
  values (v_id, v_uid, 0);

  if coalesce(p_amount, 0) > 0 then
    perform public.record_opening(v_id, p_amount, p_on, p_as_deposit);
  end if;
  return v_id;
end;
$$;

-- Setor / tarik modal on a rupiah holding: money entering or leaving the
-- tracked system (PRD 7.7, A-27).
create or replace function public.record_flow(
  p_holding uuid, p_direction text, p_amount numeric,
  p_on date default null, p_note text default null)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  h public.holdings := private.own_holding(p_holding);
  v_on date := coalesce(p_on, private.today_wib());
  v_in boolean;
  v_id uuid;
begin
  if h.category not in ('savings_idr', 'cash') then
    raise exception 'not a rupiah holding' using errcode = 'KKH01';
  end if;
  if p_direction not in ('in', 'out') then
    raise exception 'direction must be in or out' using errcode = '22023';
  end if;
  perform private.check_amount(p_amount);
  perform private.check_tx_date(h, v_on);
  v_in := p_direction = 'in';

  insert into public.transactions
    (user_id, holding_id, tx_date, type, qty, price, amount, flow_kind, note)
  values (h.user_id, h.id, v_on,
          case when v_in then 'deposit' else 'withdraw' end,
          p_amount, 1, p_amount,
          case when v_in then 'external_in' else 'external_out' end,
          nullif(btrim(p_note), ''))
  returning id into v_id;
  return v_id;
end;
$$;

-- "Set saldo" (PRD A-12a, A-38): the difference from the balance on that
-- date is a deposit or withdrawal, unless marked as interest or fees, in
-- which case it is investment income or expense and moves performance.
-- Returns null when the balance is unchanged.
create or replace function public.set_balance(
  p_holding uuid, p_balance numeric, p_on date default null,
  p_as_income boolean default false, p_note text default null)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  h public.holdings := private.own_holding(p_holding);
  v_on date := coalesce(p_on, private.today_wib());
  v_before numeric;
  v_delta numeric;
  v_id uuid;
begin
  if h.category not in ('savings_idr', 'cash') then
    raise exception 'not a rupiah holding' using errcode = 'KKH01';
  end if;
  if p_balance is null or p_balance < 0 then
    raise exception 'balance cannot be negative' using errcode = 'KKA01';
  end if;
  perform private.check_tx_date(h, v_on);

  select coalesce(sum(private.qty_sign(type) * qty), 0) into v_before
  from public.transactions
  where holding_id = h.id and tx_date <= v_on;
  v_delta := p_balance - v_before;
  if v_delta = 0 then
    return null;
  end if;

  insert into public.transactions
    (user_id, holding_id, tx_date, type, qty, price, amount, flow_kind, note)
  values (h.user_id, h.id, v_on, 'adjust', v_delta, 1, abs(v_delta),
          case
            when coalesce(p_as_income, false) and v_delta > 0 then 'income'
            when coalesce(p_as_income, false) then 'expense'
            when v_delta > 0 then 'external_in'
            else 'external_out'
          end,
          nullif(btrim(p_note), ''))
  returning id into v_id;
  return v_id;
end;
$$;

-- Edit a rupiah transaction's amount, date or note (PRD F-TX-5). Positions
-- are replayed; counted cashflow changes become corrections (HLD H-2).
create or replace function public.update_cash_transaction(
  p_id uuid, p_amount numeric, p_on date, p_note text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  t public.transactions;
  h public.holdings;
begin
  select * into t from public.transactions
  where id = p_id and user_id = private.require_uid();
  if not found then
    raise exception 'transaction not found' using errcode = 'KKH01';
  end if;
  h := private.own_holding(t.holding_id);
  if h.category not in ('savings_idr', 'cash') then
    raise exception 'not a rupiah holding' using errcode = 'KKH01';
  end if;
  perform private.check_amount(p_amount);

  if t.type = 'opening' then
    if p_on > private.today_wib() or exists (
      select 1 from public.transactions
      where holding_id = h.id and id <> t.id and tx_date < p_on) then
      raise exception 'opening must come before other transactions'
        using errcode = 'KKD01';
    end if;
    update public.holdings set started_on = p_on where id = h.id;
  else
    perform private.check_tx_date(h, p_on);
  end if;

  update public.transactions
  set amount = p_amount,
      qty = case when type = 'adjust' then sign(qty) * p_amount
                 else p_amount end,
      tx_date = p_on,
      note = nullif(btrim(p_note), '')
  where id = t.id;
end;
$$;

revoke all on function public.portfolio_cash_holding(uuid) from public, anon;
revoke all on function public.record_opening(uuid, numeric, date, boolean)
  from public, anon;
revoke all on function public.create_savings(uuid, text, text, numeric, date,
  boolean) from public, anon;
revoke all on function public.record_flow(uuid, text, numeric, date, text)
  from public, anon;
revoke all on function public.set_balance(uuid, numeric, date, boolean, text)
  from public, anon;
revoke all on function public.update_cash_transaction(uuid, numeric, date, text)
  from public, anon;
grant execute on function public.portfolio_cash_holding(uuid) to authenticated;
grant execute on function public.record_opening(uuid, numeric, date, boolean)
  to authenticated;
grant execute on function public.create_savings(uuid, text, text, numeric,
  date, boolean) to authenticated;
grant execute on function public.record_flow(uuid, text, numeric, date, text)
  to authenticated;
grant execute on function public.set_balance(uuid, numeric, date, boolean,
  text) to authenticated;
grant execute on function public.update_cash_transaction(uuid, numeric, date,
  text) to authenticated;

-- ---------------------------------------------------------------------------
-- Snapshots (PRD 6.6, HLD 5.2). Written only by private.take_snapshot.
-- ---------------------------------------------------------------------------
create table public.snapshots (
  user_id uuid not null references public.profiles (user_id) on delete cascade,
  snap_date date not null,
  total_assets numeric not null,
  total_receivables numeric not null default 0,
  total_debts numeric not null default 0,
  net_worth numeric not null,
  -- Capital cashflow counted into this snapshot (PRD 7.8, A-30).
  net_flow numeric not null default 0,
  cum_deposits numeric not null default 0,
  cum_withdrawals numeric not null default 0,
  -- Starting capital: net worth before cashflow on the first snapshot
  -- (PRD A-14). Net deposits = base_capital + cum_deposits - cum_withdrawals.
  base_capital numeric not null default 0,
  -- Null while unit performance is undefined (PRD A-36).
  units numeric,
  unit_value numeric,
  fx jsonb not null default '{}'::jsonb,
  stale_count integer not null default 0,
  created_at timestamptz not null default now(),
  primary key (user_id, snap_date)
);

create table public.snapshot_items (
  user_id uuid not null,
  snap_date date not null,
  holding_id uuid not null,
  portfolio_id uuid not null,
  category text not null,
  qty numeric not null,
  price numeric,
  price_date date,
  price_source text,
  value_idr numeric not null,
  cost_idr numeric not null,
  primary key (user_id, snap_date, holding_id),
  foreign key (user_id, snap_date)
    references public.snapshots (user_id, snap_date) on delete cascade
);

create table public.snapshot_portfolios (
  user_id uuid not null,
  snap_date date not null,
  portfolio_id uuid not null,
  value_idr numeric not null,
  net_flow numeric not null default 0,
  units numeric,
  unit_value numeric,
  cost_idr numeric not null default 0,
  unrealized_idr numeric not null default 0,
  realized_cum_idr numeric not null default 0,
  cash_idr numeric not null default 0,
  primary key (user_id, snap_date, portfolio_id),
  foreign key (user_id, snap_date)
    references public.snapshots (user_id, snap_date) on delete cascade
);

create index snapshot_portfolios_by_portfolio
  on public.snapshot_portfolios (portfolio_id, snap_date);

alter table public.snapshots enable row level security;
alter table public.snapshot_items enable row level security;
alter table public.snapshot_portfolios enable row level security;

create policy "read own snapshots" on public.snapshots
  for select to authenticated using (user_id = (select auth.uid()));
create policy "read own snapshot items" on public.snapshot_items
  for select to authenticated using (user_id = (select auth.uid()));
create policy "read own snapshot portfolios" on public.snapshot_portfolios
  for select to authenticated using (user_id = (select auth.uid()));

revoke all on public.snapshots, public.snapshot_items,
  public.snapshot_portfolios from anon, authenticated;
grant select on public.snapshots, public.snapshot_items,
  public.snapshot_portfolios to authenticated;

-- Value of every holding of a user on a date (HLD 5.2 step 2). The same
-- function feeds the live dashboard, so live and snapshot numbers agree.
-- Slice 2 values rupiah holdings; other categories join in later slices.
create or replace function private.valuate_user(p_user uuid, p_on date)
returns table (
  holding_id uuid, portfolio_id uuid, category text, qty numeric,
  price numeric, price_date date, price_source text,
  value_idr numeric, cost_idr numeric)
language sql
stable
set search_path = ''
as $$
  select h.id, h.portfolio_id, h.category, q.qty,
         1::numeric, p_on, 'idr'::text, q.qty, q.qty
  from public.holdings h
  cross join lateral (
    select coalesce(sum(private.qty_sign(t.type) * t.qty), 0) as qty
    from public.transactions t
    where t.holding_id = h.id and t.tx_date <= p_on
  ) q
  where h.user_id = p_user
    and h.category in ('savings_idr', 'cash')
    and h.started_on <= p_on
$$;

-- One step of the unit series (PRD 7.8, A-28, A-36).
--   p_prev_units: units after the previous snapshot (null = series not
--                 running, 0 = everything was withdrawn)
--   p_last_value: last defined unit value, used to restart the series so
--                 the chart stays continuous; 1000 if there never was one
--   p_value:      value (net worth) on this snapshot
--   p_flow:       capital cashflow counted into this snapshot
create or replace function private.unit_step(
  p_prev_units numeric, p_last_value numeric, p_value numeric,
  p_flow numeric, out units numeric, out unit_value numeric)
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_pre numeric := p_value - p_flow;
begin
  if p_prev_units is null or p_prev_units = 0 then
    -- Start or restart: everything present now buys units at the last value.
    if p_value > 0 then
      unit_value := coalesce(p_last_value, 1000);
      units := round(p_value / unit_value, 12);
    end if;
    return;
  end if;

  if v_pre <= 0 then
    -- Undefined (PRD A-36); the next snapshot restarts the series.
    return;
  end if;

  unit_value := round(v_pre / p_prev_units, 12);
  units := round(p_prev_units + p_flow / unit_value, 12);
  if units <= 0 then
    units := 0;
  end if;
end;
$$;

-- Takes the snapshot of one user for one date. Idempotent; returns false
-- when it already exists or the date is before tracking started (PRD A-17).
create or replace function private.take_snapshot(p_user uuid, p_on date)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_start date;
  v_prev public.snapshots;
  v_last_value numeric;
  v_assets numeric;
  v_flow numeric;
  v_in numeric;
  v_out numeric;
  v_step record;
begin
  select tracking_started_on into v_start
  from public.profiles where user_id = p_user;
  if not found or p_on < v_start then
    return false;
  end if;
  if exists (select 1 from public.snapshots
             where user_id = p_user and snap_date = p_on) then
    return false;
  end if;

  -- Serialize concurrent runs for the same user.
  perform pg_advisory_xact_lock(hashtext('snapshot:' || p_user::text));
  if exists (select 1 from public.snapshots
             where user_id = p_user and snap_date = p_on) then
    return false;
  end if;

  create temp table if not exists pg_temp.snap_val (
    holding_id uuid, portfolio_id uuid, category text, qty numeric,
    price numeric, price_date date, price_source text,
    value_idr numeric, cost_idr numeric) on commit drop;
  create temp table if not exists pg_temp.snap_flow (
    portfolio_id uuid, amount numeric) on commit drop;
  truncate pg_temp.snap_val, pg_temp.snap_flow;

  insert into pg_temp.snap_val select * from private.valuate_user(p_user, p_on);

  -- Cashflow not yet counted, including late ones (PRD A-30), plus
  -- corrections of counted rows (HLD H-2).
  insert into pg_temp.snap_flow
  select h.portfolio_id, case t.flow_kind when 'external_in' then t.amount
                                          else -t.amount end
  from public.transactions t
  join public.holdings h on h.id = t.holding_id
  where t.user_id = p_user and t.counted_on is null and t.tx_date <= p_on
    and t.flow_kind in ('external_in', 'external_out');
  insert into pg_temp.snap_flow
  select c.portfolio_id, c.amount
  from private.cashflow_corrections c
  where c.user_id = p_user and c.counted_on is null;

  update public.transactions set counted_on = p_on
  where user_id = p_user and counted_on is null and tx_date <= p_on;
  update private.cashflow_corrections set counted_on = p_on
  where user_id = p_user and counted_on is null;

  select coalesce(sum(value_idr), 0) into v_assets from pg_temp.snap_val;
  select coalesce(sum(amount), 0),
         coalesce(sum(amount) filter (where amount > 0), 0),
         coalesce(-sum(amount) filter (where amount < 0), 0)
    into v_flow, v_in, v_out
  from pg_temp.snap_flow;

  select * into v_prev from public.snapshots
  where user_id = p_user and snap_date < p_on
  order by snap_date desc limit 1;
  select s.unit_value into v_last_value from public.snapshots s
  where s.user_id = p_user and s.snap_date < p_on and s.unit_value is not null
  order by s.snap_date desc limit 1;

  if v_prev.user_id is null then
    -- First snapshot: what was there before today's cashflow is starting
    -- capital; the day's cashflow still counts as deposits (PRD A-14, A-28).
    select * into v_step from private.unit_step(null, null, v_assets, v_flow);
    insert into public.snapshots (user_id, snap_date, total_assets, net_worth,
      net_flow, cum_deposits, cum_withdrawals, base_capital, units, unit_value)
    values (p_user, p_on, v_assets, v_assets, v_flow, v_in, v_out,
            v_assets - v_flow, v_step.units, v_step.unit_value);
  else
    select * into v_step
    from private.unit_step(v_prev.units, v_last_value, v_assets, v_flow);
    insert into public.snapshots (user_id, snap_date, total_assets, net_worth,
      net_flow, cum_deposits, cum_withdrawals, base_capital, units, unit_value)
    values (p_user, p_on, v_assets, v_assets, v_flow,
            v_prev.cum_deposits + v_in, v_prev.cum_withdrawals + v_out,
            v_prev.base_capital, v_step.units, v_step.unit_value);
  end if;

  insert into public.snapshot_items (user_id, snap_date, holding_id,
    portfolio_id, category, qty, price, price_date, price_source, value_idr,
    cost_idr)
  select p_user, p_on, v.holding_id, v.portfolio_id, v.category, v.qty,
         v.price, v.price_date, v.price_source, v.value_idr, v.cost_idr
  from pg_temp.snap_val v;

  -- Per kantong: value, cash, cost and its own unit series (PRD A-29).
  insert into public.snapshot_portfolios (user_id, snap_date, portfolio_id,
    value_idr, net_flow, units, unit_value, cost_idr, unrealized_idr,
    realized_cum_idr, cash_idr)
  select p_user, p_on, agg.id, agg.value_idr, agg.flow, st.units,
         st.unit_value, agg.cost_idr, agg.value_idr - agg.cost_idr, 0,
         agg.cash_idr
  from (
    select p.id,
      coalesce((select sum(v.value_idr) from pg_temp.snap_val v
                where v.portfolio_id = p.id), 0) as value_idr,
      coalesce((select sum(v.cost_idr) from pg_temp.snap_val v
                where v.portfolio_id = p.id), 0) as cost_idr,
      coalesce((select sum(v.value_idr) from pg_temp.snap_val v
                where v.portfolio_id = p.id and v.category = 'cash'), 0)
        as cash_idr,
      coalesce((select sum(f.amount) from pg_temp.snap_flow f
                where f.portfolio_id = p.id), 0) as flow,
      (select sp.units from public.snapshot_portfolios sp
       where sp.user_id = p_user and sp.portfolio_id = p.id
         and sp.snap_date < p_on
       order by sp.snap_date desc limit 1) as prev_units,
      (select sp.unit_value from public.snapshot_portfolios sp
       where sp.user_id = p_user and sp.portfolio_id = p.id
         and sp.snap_date < p_on and sp.unit_value is not null
       order by sp.snap_date desc limit 1) as last_value
    from public.portfolios p
    where p.user_id = p_user
  ) agg
  cross join lateral private.unit_step(
    agg.prev_units, agg.last_value, agg.value_idr, agg.flow) st;

  return true;
end;
$$;

-- Flow kind for an opening balance. Before the first snapshot it is starting
-- capital (PRD A-14). After that it counts as a deposit, so adding an asset
-- you already owned does not show up as a gain (decided by Ilham, 12 Oct,
-- PRD A-42). The caller can override either way.
create or replace function private.opening_flow_kind(
  p_user uuid, p_as_deposit boolean)
returns text
language sql
stable
set search_path = ''
as $$
  select case
    when coalesce(p_as_deposit,
                  exists (select 1 from public.snapshots s
                          where s.user_id = p_user))
      then 'external_in'
    else 'none'
  end
$$;


-- ---------------------------------------------------------------------------
-- Daily job (HLD 5.1): one snapshot per user, errors isolated per user.
-- ---------------------------------------------------------------------------
create table private.job_runs (
  id bigint generated always as identity primary key,
  job text not null,
  run_for date,
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  users_done integer not null default 0,
  users_failed integer not null default 0
);

create table private.job_errors (
  id bigint generated always as identity primary key,
  run_id bigint not null references private.job_runs (id) on delete cascade,
  user_id uuid,
  sqlstate text,
  message text,
  at timestamptz not null default now()
);

create or replace function private.take_all_snapshots(
  p_on date default private.today_wib())
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_run bigint;
  v_done integer := 0;
  v_failed integer := 0;
  u record;
begin
  insert into private.job_runs (job, run_for) values ('take_snapshots', p_on)
  returning id into v_run;

  for u in
    select p.user_id from public.profiles p
    where p.tracking_started_on <= p_on
      and not exists (select 1 from public.snapshots s
                      where s.user_id = p.user_id and s.snap_date = p_on)
  loop
    begin
      if private.take_snapshot(u.user_id, p_on) then
        v_done := v_done + 1;
      end if;
    exception when others then
      v_failed := v_failed + 1;
      insert into private.job_errors (run_id, user_id, sqlstate, message)
      values (v_run, u.user_id, sqlstate, sqlerrm);
    end;
  end loop;

  update private.job_runs
  set finished_at = now(), users_done = v_done, users_failed = v_failed
  where id = v_run;
  return v_done;
end;
$$;

-- 18:00 WIB = 11:00 UTC, retried every 30 minutes until 23:30 WIB
-- (PRD F-SNAP-1, A-16). Skipped where pg_cron is not installed (local
-- test harnesses); Supabase ships it.
do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    create extension if not exists pg_cron;
    perform cron.schedule('take_snapshots', '0 11 * * *',
      'select private.take_all_snapshots()');
    perform cron.schedule('take_snapshots_retry', '*/30 11-16 * * *',
      'select private.take_all_snapshots()');
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Live dashboard (PRD F-DASH-1, HLD 9). Same valuation as the snapshot.
--
-- change = net worth now - last snapshot before today - cashflow since then.
-- [ASUMSI A-43] "Perubahan hari ini" leaves out today's deposits and
-- withdrawals, so a deposit does not read as a gain; the cashflow is
-- returned separately for the UI to mention.
-- ---------------------------------------------------------------------------
create or replace function public.dashboard_summary()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_uid();
  v_today date := private.today_wib();
  v_base public.snapshots;   -- last snapshot before today
  v_latest public.snapshots; -- last snapshot up to today
  v_nw numeric;
  v_since numeric;
  v_pending numeric;
  v_portfolios jsonb;
begin
  create temp table if not exists pg_temp.live_val (
    holding_id uuid, portfolio_id uuid, category text, qty numeric,
    price numeric, price_date date, price_source text,
    value_idr numeric, cost_idr numeric) on commit drop;
  truncate pg_temp.live_val;
  insert into pg_temp.live_val select * from private.valuate_user(v_uid, v_today);

  select * into v_base from public.snapshots
  where user_id = v_uid and snap_date < v_today
  order by snap_date desc limit 1;
  select * into v_latest from public.snapshots
  where user_id = v_uid and snap_date <= v_today
  order by snap_date desc limit 1;

  create temp table if not exists pg_temp.live_flow (
    portfolio_id uuid, amount numeric, counted_on date) on commit drop;
  truncate pg_temp.live_flow;
  insert into pg_temp.live_flow
  select h.portfolio_id,
         case t.flow_kind when 'external_in' then t.amount else -t.amount end,
         t.counted_on
  from public.transactions t
  join public.holdings h on h.id = t.holding_id
  where t.user_id = v_uid and t.tx_date <= v_today
    and t.flow_kind in ('external_in', 'external_out')
    and (t.counted_on is null or t.counted_on > coalesce(v_base.snap_date, '-infinity'::date));
  insert into pg_temp.live_flow
  select c.portfolio_id, c.amount, c.counted_on
  from private.cashflow_corrections c
  where c.user_id = v_uid
    and (c.counted_on is null or c.counted_on > coalesce(v_base.snap_date, '-infinity'::date));

  select coalesce(sum(value_idr), 0) into v_nw from pg_temp.live_val;
  select coalesce(sum(amount), 0) into v_since from pg_temp.live_flow;
  select coalesce(sum(amount), 0) into v_pending from pg_temp.live_flow
  where counted_on is null;

  select coalesce(jsonb_agg(jsonb_build_object(
    'portfolio_id', p.id,
    'value', f.value_idr::text,
    'cost', f.cost_idr::text,
    'unrealized', (f.value_idr - f.cost_idr)::text,
    'cash', f.cash_idr::text,
    'asset_count', f.asset_count,
    'flow_since', f.flow::text,
    'change', case when b.value_idr is null then null
                   else (f.value_idr - b.value_idr - f.flow)::text end,
    'change_pct', case when b.value_idr > 0
                       then round((f.value_idr - b.value_idr - f.flow)
                                  / b.value_idr * 100, 4)::text end,
    'base_value', b.value_idr::text
  ) order by p.sort_order), '[]'::jsonb)
  into v_portfolios
  from public.portfolios p
  cross join lateral (
    select
      coalesce((select sum(v.value_idr) from pg_temp.live_val v
                where v.portfolio_id = p.id), 0) as value_idr,
      coalesce((select sum(v.cost_idr) from pg_temp.live_val v
                where v.portfolio_id = p.id), 0) as cost_idr,
      coalesce((select sum(v.value_idr) from pg_temp.live_val v
                where v.portfolio_id = p.id and v.category = 'cash'), 0)
        as cash_idr,
      (select count(*) from public.holdings h
       where h.portfolio_id = p.id and h.category <> 'cash'
         and h.archived_at is null) as asset_count,
      coalesce((select sum(l.amount) from pg_temp.live_flow l
                where l.portfolio_id = p.id), 0) as flow
  ) f
  left join public.snapshot_portfolios b
    on b.user_id = v_uid and b.portfolio_id = p.id
   and b.snap_date = v_base.snap_date
  where p.user_id = v_uid;

  -- Amounts go out as strings so the client parses them without passing
  -- through floating point (CLAUDE.md: money is never a double).
  return jsonb_build_object(
    'as_of', v_today,
    'total_assets', v_nw::text,
    'total_receivables', '0',
    'total_debts', '0',
    'net_worth', v_nw::text,
    -- Before the first snapshot everything present is starting capital.
    'net_deposits', (case when v_latest.user_id is null then v_nw
                          else v_latest.base_capital + v_latest.cum_deposits
                               - v_latest.cum_withdrawals + v_pending end)::text,
    'base_date', v_base.snap_date,
    'base_net_worth', v_base.net_worth::text,
    'flow_since', v_since::text,
    'change', case when v_base.user_id is null then null
                   else (v_nw - v_base.net_worth - v_since)::text end,
    'change_pct', case when v_base.net_worth > 0
                       then round((v_nw - v_base.net_worth - v_since)
                                  / v_base.net_worth * 100, 4)::text end,
    'first_snapshot_on', (select min(snap_date) from public.snapshots
                          where user_id = v_uid),
    -- Allocation by asset kind (PRD F-DASH-5); kantong cash is its own slice.
    'categories', (select coalesce(jsonb_agg(jsonb_build_object(
                     'category', c.category, 'value', c.value_idr::text)
                     order by c.value_idr desc), '[]'::jsonb)
                   from (select category, sum(value_idr) as value_idr
                         from pg_temp.live_val group by category
                         having sum(value_idr) <> 0) c),
    'portfolios', v_portfolios);
end;
$$;

revoke all on function public.dashboard_summary() from public, anon;
grant execute on function public.dashboard_summary() to authenticated;

-- Snapshot list for Riwayat and the net worth chart, newest first. The
-- change follows the same rule as the dashboard (A-43): the day's counted
-- cashflow is not a gain or loss.
create or replace function public.snapshot_history(p_limit integer default 800)
returns table (
  snap_date date, net_worth text, net_flow text, change text,
  net_deposits text, unit_value text)
language sql
stable
security invoker
set search_path = ''
as $$
  select s.snap_date, s.net_worth::text, s.net_flow::text,
         (s.net_worth - lag(s.net_worth) over w - s.net_flow)::text,
         (s.base_capital + s.cum_deposits - s.cum_withdrawals)::text,
         s.unit_value::text
  from public.snapshots s
  where s.user_id = (select auth.uid())
  window w as (order by s.snap_date)
  order by s.snap_date desc
  limit p_limit
$$;

revoke all on function public.snapshot_history(integer) from public, anon;
grant execute on function public.snapshot_history(integer) to authenticated;

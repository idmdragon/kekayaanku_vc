-- Slice 2: rupiah savings, kantong cash, capital cashflow, snapshots and
-- unit performance (PRD 6.2.6, 6.4, 6.6, 7.7-7.9; HLD 5.2, 6.2, 6.3).
--
-- Ani tracks from 5 Jan 2026:
--   5 Jan  Tabungan BCA (Dana Darurat) opens with 10.000.000, kas Utama with
--          2.000.000. Both are starting capital (A-14).    NW 12.000.000
--   6 Jan  BCA balance set to 10.050.000, marked as interest (A-38).
--                                                            NW 12.050.000
--   7 Jan  Setor 5.000.000 into kas Utama.                   NW 17.050.000
--   8 Jan  Tarik 1.000.000 recorded late, dated 7 Jan (A-30). NW 16.050.000
--   9 Jan  New "Dompet" (Utama) with 500.000 after tracking started: counts
--          as a deposit (A-42).                              NW 16.550.000
--  10 Jan  The 7 Jan deposit is deleted after it was counted: a -5.000.000
--          correction lands on this snapshot (H-2).          NW 11.550.000
-- Only the 50.000 interest is performance: the unit value moves on 6 Jan
-- and stays put through every deposit, withdrawal and correction.
begin;
create extension if not exists pgtap with schema extensions;
select plan(72);

insert into auth.users (id, email, raw_user_meta_data) values
  ('11111111-1111-1111-1111-111111111111', 'ani@example.com',
   '{"display_name": "Ani"}'),
  ('22222222-2222-2222-2222-222222222222', 'budi@example.com', '{}');

update profiles set tracking_started_on = '2026-01-05'
where user_id = '11111111-1111-1111-1111-111111111111';

-- Structure ------------------------------------------------------------------
select ok((select bool_and(relrowsecurity) from pg_class where oid in (
  'public.holdings'::regclass, 'public.transactions'::regclass,
  'public.holding_positions'::regclass, 'public.snapshots'::regclass,
  'public.snapshot_items'::regclass, 'public.snapshot_portfolios'::regclass)),
  'RLS is on for every slice 2 table');

-- unit_step on its own (PRD 7.8, A-36) ----------------------------------------
select results_eq(
  $$select units, unit_value from private.unit_step(null, null, 12000000, 0)$$,
  $$values (12000::numeric, 1000::numeric)$$,
  'first day: unit value 1.000, units = net worth / 1.000');
select results_eq(
  $$select units, unit_value from private.unit_step(100000, 1000, 105000000, 5000000)$$,
  $$values (105000::numeric, 1000::numeric)$$,
  'a deposit buys units at the pre-flow value and leaves the unit value alone');
select results_eq(
  $$select units, unit_value from private.unit_step(105000, 1000, 115500000, 0)$$,
  $$values (105000::numeric, 1100::numeric)$$,
  'a 10% gain shows as a 10% higher unit value');
select results_eq(
  $$select units, unit_value from private.unit_step(105000, 1100, 0, -115500000)$$,
  $$values (0::numeric, 1100::numeric)$$,
  'withdrawing everything leaves zero units at the last value');
select results_eq(
  $$select units, unit_value from private.unit_step(0, 1100, 2200000, 2200000)$$,
  $$values (2000::numeric, 1100::numeric)$$,
  'after zero units the next deposit restarts at the last unit value');
select results_eq(
  $$select units, unit_value from private.unit_step(null, null, -5000000, 0)$$,
  $$values (null::numeric, null::numeric)$$,
  'net worth <= 0 at the start: series not started (A-36)');
select results_eq(
  $$select units, unit_value from private.unit_step(1000, 1000, -100, 0)$$,
  $$values (null::numeric, null::numeric)$$,
  'net worth turning <= 0 makes the unit value undefined (A-36)');
select results_eq(
  $$select units, unit_value from private.unit_step(null, 1100, 500000, 0)$$,
  $$values (round(500000 / 1100::numeric, 12), 1100::numeric)$$,
  'after an undefined stretch the series restarts at the last defined value');

-- Anonymous visitors -----------------------------------------------------------
set local role anon;
select throws_ok('select count(*) from public.holdings', '42501', null,
  'anon cannot read holdings');
select throws_ok($$select public.record_flow(gen_random_uuid(), 'in', 1)$$,
  '42501', null, 'anon cannot record cashflow');
reset role;

-- As Ani -------------------------------------------------------------------------
set local role authenticated;
set local request.jwt.claims = '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}';

insert into portfolios (name, emoji, color_key) values ('Dana Darurat', '🛟', 'mint');

create temp table ids (k text primary key, id uuid) on commit drop;
grant all on ids to authenticated;
insert into ids values
  ('utama', (select id from portfolios where name = 'Utama')),
  ('darurat', (select id from portfolios where name = 'Dana Darurat'));

select throws_ok(
  $$insert into transactions (holding_id, tx_date, type, qty, amount, flow_kind)
    values (gen_random_uuid(), '2026-01-05', 'deposit', 1, 1, 'external_in')$$,
  '42501', null, 'transactions are written only through the RPCs');
select throws_ok(
  $$insert into holdings (portfolio_id, category, name) values
    ((select id from ids where k = 'utama'), 'cash', 'Kas')$$,
  '42501', null, 'holdings are created only through the RPCs');

-- 5 Jan: opening balances.
insert into ids values ('bca', public.create_savings(
  (select id from ids where k = 'darurat'), 'Tabungan BCA', 'rekening',
  10000000, '2026-01-05'));
insert into ids values ('kas', public.portfolio_cash_holding(
  (select id from ids where k = 'utama')));

select is(public.portfolio_cash_holding((select id from ids where k = 'utama')),
  (select id from ids where k = 'kas'), 'kantong cash is created once and reused');
select lives_ok(
  $$select public.record_opening((select id from ids where k = 'kas'), 2000000, '2026-01-05')$$,
  'kas Utama gets an opening balance');

select results_eq(
  $$select h.category, h.name, h.params ->> 'form', p.qty from holdings h
    join holding_positions p on p.holding_id = h.id
    where h.id = (select id from ids where k = 'bca')$$,
  $$values ('savings_idr'::text, 'Tabungan BCA'::text, 'rekening'::text, 10000000::numeric)$$,
  'savings holding with its position');
select is(
  (select flow_kind from transactions
   where holding_id = (select id from ids where k = 'bca') and type = 'opening'),
  'none', 'an opening before the first snapshot is starting capital (A-14)');

select throws_ok(
  $$select public.record_opening((select id from ids where k = 'kas'), 1, '2026-01-05')$$,
  '23505', null, 'one opening per holding');
select throws_ok(
  $$select public.create_savings((select id from ids where k = 'utama'), 'X', 'brankas', 1)$$,
  '23514', null, 'savings form is rekening or tunai');
select throws_ok(
  $$select public.record_flow((select id from ids where k = 'kas'), 'out', 2000001, '2026-01-05')$$,
  'KKN01', null, 'cannot withdraw more than the balance on that date');
select throws_ok(
  $$select public.record_flow((select id from ids where k = 'kas'), 'in', 1,
     (now() at time zone 'Asia/Jakarta')::date + 1)$$,
  'KKD01', null, 'no transactions in the future');
select throws_ok(
  $$select public.record_flow((select id from ids where k = 'bca'), 'in', 1, '2026-01-04')$$,
  'KKD01', null, 'no transactions before the opening balance (A-13)');
select throws_ok(
  $$select public.record_flow((select id from ids where k = 'kas'), 'in', 0, '2026-01-05')$$,
  'KKA01', null, 'amount must be positive');

-- The job runs as the system.
reset role;
select ok(private.take_snapshot('11111111-1111-1111-1111-111111111111', '2026-01-05'),
  'snapshot 5 Jan');
select ok(not private.take_snapshot('11111111-1111-1111-1111-111111111111', '2026-01-04'),
  'no snapshot before tracking started (A-17)');
select ok(not private.take_snapshot('11111111-1111-1111-1111-111111111111', '2026-01-05'),
  'taking the same snapshot again does nothing');
select results_eq(
  $$select net_worth, net_flow, base_capital, cum_deposits, units, unit_value
    from snapshots where snap_date = '2026-01-05'$$,
  $$values (12000000::numeric, 0::numeric, 12000000::numeric, 0::numeric,
            12000::numeric, 1000::numeric)$$,
  '5 Jan: starting capital 12 jt = 12.000 units at 1.000');
select is((select count(*)::int from snapshot_items where snap_date = '2026-01-05'),
  2, '5 Jan: one item per holding');
select results_eq(
  $$select value_idr, cash_idr, units, unit_value from snapshot_portfolios
    where snap_date = '2026-01-05' order by value_idr$$,
  $$values (2000000::numeric, 2000000::numeric, 2000::numeric, 1000::numeric),
           (10000000::numeric, 0::numeric, 10000::numeric, 1000::numeric)$$,
  '5 Jan: each kantong starts its own unit series');

-- 6 Jan: interest via "set saldo".
set local role authenticated;
insert into ids values ('interest', public.set_balance(
  (select id from ids where k = 'bca'), 10050000, '2026-01-06', true));
select is(
  (select flow_kind from transactions where id = (select id from ids where k = 'interest')),
  'income', 'set saldo marked as interest is income, not a deposit (A-38)');
select is(public.set_balance((select id from ids where k = 'bca'), 10050000, '2026-01-06'),
  null, 'set saldo to the same balance records nothing');
reset role;
select ok(private.take_snapshot('11111111-1111-1111-1111-111111111111', '2026-01-06'),
  'snapshot 6 Jan');
select results_eq(
  $$select net_worth, net_flow, units, round(unit_value, 6) from snapshots
    where snap_date = '2026-01-06'$$,
  $$values (12050000::numeric, 0::numeric, 12000::numeric, 1004.166667::numeric)$$,
  '6 Jan: interest raises the unit value');
select is(
  (select unit_value from snapshot_portfolios
   where snap_date = '2026-01-06' and portfolio_id = (select id from ids where k = 'darurat')),
  1005::numeric, '6 Jan: Dana Darurat earned 0,5%');

-- 7 Jan: a deposit into kas Utama.
set local role authenticated;
insert into ids values ('gaji', public.record_flow(
  (select id from ids where k = 'kas'), 'in', 5000000, '2026-01-07', 'Gaji'));
select is(
  (select flow_kind from transactions where id = (select id from ids where k = 'gaji')),
  'external_in', 'setor is an external inflow');
reset role;
select ok(private.take_snapshot('11111111-1111-1111-1111-111111111111', '2026-01-07'),
  'snapshot 7 Jan');
select results_eq(
  $$select net_worth, net_flow, cum_deposits, round(unit_value, 6), round(units, 4)
    from snapshots where snap_date = '2026-01-07'$$,
  $$values (17050000::numeric, 5000000::numeric, 5000000::numeric,
            1004.166667::numeric, 16979.2531::numeric)$$,
  '7 Jan: a 5 jt deposit adds units and leaves the unit value unchanged');
select results_eq(
  $$select value_idr, net_flow, units, unit_value from snapshot_portfolios
    where snap_date = '2026-01-07' and portfolio_id = (select id from ids where k = 'utama')$$,
  $$values (7000000::numeric, 5000000::numeric, 7000::numeric, 1000::numeric)$$,
  '7 Jan: the deposit counts toward kantong Utama only');
select is(
  (select count(*)::int from transactions where counted_on = '2026-01-07'),
  1, 'the deposit is marked as counted by the 7 Jan snapshot');

-- 8 Jan: a withdrawal dated 7 Jan, recorded after that snapshot.
set local role authenticated;
select lives_ok(
  $$select public.record_flow((select id from ids where k = 'kas'), 'out', 1000000, '2026-01-07')$$,
  'a late withdrawal can be backdated');
reset role;
select ok(private.take_snapshot('11111111-1111-1111-1111-111111111111', '2026-01-08'),
  'snapshot 8 Jan');
select results_eq(
  $$select net_worth, net_flow, cum_withdrawals, round(unit_value, 6)
    from snapshots where snap_date = '2026-01-08'$$,
  $$values (16050000::numeric, -1000000::numeric, 1000000::numeric, 1004.166667::numeric)$$,
  '8 Jan: the late withdrawal lands on the next snapshot (A-30)');
select is(
  (select net_worth from snapshots where snap_date = '2026-01-07'),
  17050000::numeric, 'the 7 Jan snapshot stays as it was (F-SNAP-2)');

-- 9 Jan: an asset added after tracking started.
set local role authenticated;
insert into ids values ('dompet', public.create_savings(
  (select id from ids where k = 'utama'), 'Dompet', 'tunai', 500000, '2026-01-09'));
select is(
  (select flow_kind from transactions
   where holding_id = (select id from ids where k = 'dompet')),
  'external_in', 'an opening after the first snapshot counts as a deposit (A-42)');
insert into ids values ('celengan', public.record_opening(
  public.create_savings((select id from ids where k = 'utama'), 'Celengan',
    'tunai', 0, '2026-01-09'), 100, '2026-01-09', false));
select is(
  (select flow_kind from transactions where id = (select id from ids where k = 'celengan')),
  'none', 'the caller can still mark it as starting capital');
reset role;
-- Keep the scenario's numbers: drop the extra Celengan again.
delete from holdings where name = 'Celengan';
select ok(private.take_snapshot('11111111-1111-1111-1111-111111111111', '2026-01-09'),
  'snapshot 9 Jan');
select results_eq(
  $$select net_worth, net_flow, cum_deposits, round(unit_value, 6)
    from snapshots where snap_date = '2026-01-09'$$,
  $$values (16550000::numeric, 500000::numeric, 5500000::numeric, 1004.166667::numeric)$$,
  '9 Jan: the added asset is a deposit, not a gain');

-- 10 Jan: the counted 7 Jan deposit turns out to be a mistake.
set local role authenticated;
select lives_ok(
  $$delete from transactions where holding_id = (select id from ids where k = 'kas')
    and type = 'deposit'$$,
  'a counted deposit can be deleted');
select throws_ok(
  $$delete from transactions where holding_id = (select id from ids where k = 'kas')
    and type = 'opening'$$,
  'KKN01', null, 'deleting the opening would leave a negative balance');
reset role;
select is(
  (select amount from private.cashflow_corrections where counted_on is null),
  -5000000::numeric, 'the deletion leaves a -5 jt correction');
select ok(private.take_snapshot('11111111-1111-1111-1111-111111111111', '2026-01-10'),
  'snapshot 10 Jan');
select results_eq(
  $$select net_worth, net_flow, cum_deposits, cum_withdrawals, round(unit_value, 6)
    from snapshots where snap_date = '2026-01-10'$$,
  $$values (11550000::numeric, -5000000::numeric, 5500000::numeric,
            6000000::numeric, 1004.166667::numeric)$$,
  '10 Jan: the correction is a cashflow, the unit value holds');
select is(
  (select base_capital + cum_deposits - cum_withdrawals from snapshots
   where snap_date = '2026-01-10'),
  11500000::numeric, 'net deposits 11,5 jt against net worth 11,55 jt: 50 rb earned');

-- Editing a counted row also corrects (H-2).
set local role authenticated;
select lives_ok(
  $$select public.update_cash_transaction(
     (select id from transactions where holding_id = (select id from ids where k = 'dompet')),
     600000, '2026-01-09', 'salah ketik')$$,
  'a counted opening can be edited');
reset role;
select is(
  (select amount from private.cashflow_corrections where counted_on is null),
  100000::numeric, 'raising it by 100 rb leaves a +100 rb correction');

-- Live dashboard -----------------------------------------------------------------
set local role authenticated;
select lives_ok(
  $$select public.record_flow((select id from ids where k = 'kas'), 'in', 1000000)$$,
  'deposit today');
select results_eq(
  $$select (d ->> 'net_worth')::numeric, (d ->> 'net_deposits')::numeric,
           (d ->> 'flow_since')::numeric, (d ->> 'change')::numeric,
           (d ->> 'base_date')::date
    from (select public.dashboard_summary() as d) s$$,
  $$values (12650000::numeric, 12600000::numeric, 1100000::numeric, 0::numeric,
            '2026-01-10'::date)$$,
  'dashboard: live net worth, net deposits, and a change that ignores cashflow (A-43)');
select results_eq(
  $$select (p ->> 'value')::numeric, (p ->> 'cash')::numeric,
           (p ->> 'asset_count')::int, (p ->> 'change')::numeric
    from jsonb_array_elements(public.dashboard_summary() -> 'portfolios') p
    where (p ->> 'portfolio_id')::uuid = (select id from ids where k = 'utama')$$,
  $$values (2600000::numeric, 2000000::numeric, 1, 0::numeric)$$,
  'dashboard: kantong Utama figures (cash is not counted as an asset)');

-- Kantong rules ------------------------------------------------------------------
select throws_ok(
  $$update portfolios set cash_enabled = false where id = (select id from ids where k = 'utama')$$,
  'KKC01', null, 'kantong cash cannot be switched off while it holds money');
select throws_ok(
  $$delete from portfolios where id = (select id from ids where k = 'darurat')$$,
  '23503', null, 'a kantong with assets cannot be deleted (F-PF-1)');
insert into portfolios (name) values ('Kosong');
select isnt(public.portfolio_cash_holding((select id from portfolios where name = 'Kosong')),
  null, 'cash holding for an empty kantong');
select lives_ok(
  $$delete from portfolios where name = 'Kosong'$$,
  'a kantong with only an unused cash holding can be deleted');

-- Budi sees none of it -------------------------------------------------------------
set local request.jwt.claims = '{"sub": "22222222-2222-2222-2222-222222222222", "role": "authenticated"}';
select is((select count(*)::int from holdings) + (select count(*)::int from transactions)
          + (select count(*)::int from snapshots) + (select count(*)::int from holding_positions),
  0, 'Budi sees none of Ani''s holdings, transactions, positions or snapshots');
select throws_ok(
  $$select public.record_flow((select id from ids where k = 'kas'), 'in', 1)$$,
  'KKH01', null, 'Budi cannot write to Ani''s holding');
select throws_ok(
  $$select public.create_savings((select id from ids where k = 'utama'), 'X', 'tunai', 1)$$,
  'KKH01', null, 'Budi cannot add savings to Ani''s kantong');
select throws_ok(
  $$select public.portfolio_cash_holding((select id from ids where k = 'utama'))$$,
  'KKH01', null, 'Budi cannot open Ani''s kantong cash');
select lives_ok(
  $$delete from transactions where holding_id = (select id from ids where k = 'kas')$$,
  'a delete aimed at Ani''s rows runs...');
reset role;
select is(
  (select count(*)::int from transactions where holding_id = (select id from ids where k = 'kas')),
  3, '...and removes nothing');

-- The daily job ------------------------------------------------------------------
select is(private.take_all_snapshots(private.today_wib()), 2,
  'the job snapshots every user once');
select is(private.take_all_snapshots(private.today_wib()), 0,
  'and is idempotent');

-- Account deletion takes everything with it --------------------------------------
set local role authenticated;
set local request.jwt.claims = '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}';
select lives_ok('select public.delete_account()', 'Ani deletes her account');
reset role;
select is((select count(*)::int from holdings) + (select count(*)::int from transactions)
          + (select count(*)::int from snapshots where user_id = '11111111-1111-1111-1111-111111111111')
          + (select count(*)::int from private.cashflow_corrections),
  0, 'her holdings, transactions, snapshots and corrections are gone');

select * from finish();
rollback;

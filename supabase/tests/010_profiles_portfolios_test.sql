-- Slice 1: signup trigger, RLS isolation, column grants, delete account.
begin;
create extension if not exists pgtap with schema extensions;
select plan(31);

-- Two users. The signup trigger runs on insert.
insert into auth.users (id, email, raw_user_meta_data) values
  ('11111111-1111-1111-1111-111111111111', 'ani@example.com',
   '{"display_name": "Ani"}'),
  ('22222222-2222-2222-2222-222222222222', 'budi.santoso@example.com', '{}');

-- Structure ------------------------------------------------------------------
select ok((select relrowsecurity from pg_class where oid = 'public.profiles'::regclass),
  'RLS is on for profiles');
select ok((select relrowsecurity from pg_class where oid = 'public.portfolios'::regclass),
  'RLS is on for portfolios');

-- Signup trigger -------------------------------------------------------------
select is((select display_name from profiles
           where user_id = '11111111-1111-1111-1111-111111111111'),
  'Ani', 'display name comes from signup metadata');
select is((select display_name from profiles
           where user_id = '22222222-2222-2222-2222-222222222222'),
  'budi.santoso', 'display name falls back to the email local part');
select is((select accent from profiles
           where user_id = '11111111-1111-1111-1111-111111111111'),
  'amber', 'accent defaults to amber (DS-7)');
select results_eq(
  $$select name, emoji, color_key, sort_order, cash_enabled from portfolios
    where user_id = '11111111-1111-1111-1111-111111111111'$$,
  $$values ('Utama'::text, '💼'::text, 'langit'::text, 0, true)$$,
  'signup creates one default kantong "Utama"');
select is((select tracking_started_on from profiles
           where user_id = '11111111-1111-1111-1111-111111111111'),
  (now() at time zone 'Asia/Jakarta')::date, 'tracking starts today in WIB');

-- Anonymous visitors see nothing ---------------------------------------------
set local role anon;
select throws_ok('select count(*) from public.portfolios', '42501', null,
  'anon cannot read portfolios');
select throws_ok('select count(*) from public.profiles', '42501', null,
  'anon cannot read profiles');
select throws_ok('select public.delete_account()', '42501', null,
  'anon cannot call delete_account');
reset role;

-- As Ani ---------------------------------------------------------------------
set local role authenticated;
set local request.jwt.claims = '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}';

select is((select count(*)::int from profiles), 1, 'Ani sees only her profile');
select is((select count(*)::int from portfolios), 1, 'Ani sees only her kantong');

select lives_ok(
  $$insert into portfolios (name, emoji, color_key) values ('Saham Trading', '📈', 'mint')$$,
  'Ani creates a kantong without passing user_id');
select is((select user_id from portfolios where name = 'Saham Trading'),
  '11111111-1111-1111-1111-111111111111'::uuid, 'user_id defaults to the caller');
select is((select sort_order from portfolios where name = 'Saham Trading'),
  1, 'a new kantong goes to the end');

select throws_ok(
  $$insert into portfolios (user_id, name) values
    ('22222222-2222-2222-2222-222222222222', 'Titipan')$$,
  '42501', null, 'Ani cannot create a kantong for Budi');
select throws_ok(
  $$insert into portfolios (name) values ('  ')$$,
  '23514', null, 'blank names are rejected');
select throws_ok(
  $$insert into portfolios (name, color_key) values ('Emas', 'ungu')$$,
  '23514', null, 'unknown colours are rejected');

select lives_ok(
  $$update profiles set accent = 'blue', kantong_view = 'grid', display_name = 'Ani W.'$$,
  'Ani edits her own profile settings');
select is((select accent from profiles), 'blue', 'accent saved');
select throws_ok(
  $$update profiles set user_id = '22222222-2222-2222-2222-222222222222'$$,
  '42501', null, 'profile user_id is not writable');
select throws_ok(
  $$update profiles set tracking_started_on = '2020-01-01'$$,
  '42501', null, 'tracking start date is not writable by the client');

select lives_ok(
  $$select reorder_portfolios(array[
      (select id from portfolios where name = 'Saham Trading'),
      (select id from portfolios where name = 'Utama')])$$,
  'Ani reorders her kantong');
select results_eq(
  $$select name from portfolios order by sort_order$$,
  $$values ('Saham Trading'::text), ('Utama'::text)$$,
  'order follows the array');
reset role;

-- As Budi: Ani's rows are invisible and untouchable ---------------------------
set local role authenticated;
set local request.jwt.claims = '{"sub": "22222222-2222-2222-2222-222222222222", "role": "authenticated"}';

select is((select count(*)::int from portfolios), 1, 'Budi sees only his own kantong');
update portfolios set name = 'Diambil'
  where user_id = '11111111-1111-1111-1111-111111111111';
delete from portfolios where user_id = '11111111-1111-1111-1111-111111111111';
select reorder_portfolios(array(
  select id from portfolios));
reset role;

select is((select count(*)::int from portfolios
           where user_id = '11111111-1111-1111-1111-111111111111'
             and name in ('Saham Trading', 'Utama')),
  2, 'Budi could not rename or delete Ani''s kantong');
select is((select accent from profiles
           where user_id = '22222222-2222-2222-2222-222222222222'),
  'amber', 'Ani''s profile edit did not touch Budi');

-- Delete account ---------------------------------------------------------------
set local role authenticated;
set local request.jwt.claims = '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}';
select lives_ok('select delete_account()', 'Ani deletes her account');
reset role;

select is((select count(*)::int from auth.users
           where id = '11111111-1111-1111-1111-111111111111'), 0, 'auth user removed');
select is((select count(*)::int from portfolios
           where user_id = '11111111-1111-1111-1111-111111111111'), 0,
  'her kantong are removed with the account');
select is((select count(*)::int from portfolios
           where user_id = '22222222-2222-2222-2222-222222222222'), 1,
  'Budi''s data is untouched');

select * from finish();
rollback;

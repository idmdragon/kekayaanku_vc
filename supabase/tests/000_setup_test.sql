-- Smoke test so `supabase test db` has something to run before Slice 1.
-- Financial-logic tests (avg price, realized P/L, deposito, unit performance)
-- arrive with their slices; see PROGRESS.md.
begin;
create extension if not exists pgtap with schema extensions;
select plan(2);

select has_schema('public', 'public schema exists');
select ok(
  (select setting::int >= 150000 from pg_settings where name = 'server_version_num'),
  'Postgres is version 15 or newer'
);

select * from finish();
rollback;

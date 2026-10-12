-- Slice 1: profiles and portfolios (kantong), with RLS.
-- See docs/hld.md 6.2 and 7, docs/prd.md 6.1 and 6.11.

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

-- Business date = calendar date in WIB (HLD 3.2).
create or replace function private.today_wib()
returns date
language sql
stable
set search_path = ''
as $$
  select (now() at time zone 'Asia/Jakarta')::date
$$;

create or replace function private.touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- profiles: one row per auth user, created by the signup trigger below.
-- ---------------------------------------------------------------------------
create table public.profiles (
  user_id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null default ''
    check (char_length(display_name) <= 60),
  timezone text not null default 'Asia/Jakarta',
  -- docs/design-system.md DS-7: amber by default, lime or blue on request.
  accent text not null default 'amber'
    check (accent in ('amber', 'lime', 'blue')),
  theme_mode text not null default 'system'
    check (theme_mode in ('system', 'light', 'dark')),
  -- Tab Kantong list/grid toggle, remembered per user.
  kantong_view text not null default 'list'
    check (kantong_view in ('list', 'grid')),
  settings jsonb not null default '{}'::jsonb
    check (jsonb_typeof(settings) = 'object'),
  tracking_started_on date not null default private.today_wib(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger profiles_touch_updated_at
  before update on public.profiles
  for each row execute function private.touch_updated_at();

alter table public.profiles enable row level security;

create policy "read own profile" on public.profiles
  for select to authenticated
  using (user_id = (select auth.uid()));

create policy "update own profile" on public.profiles
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

-- Rows are created by the signup trigger and removed with the account, so the
-- client only reads and edits a fixed set of columns.
revoke all on public.profiles from anon, authenticated;
grant select on public.profiles to authenticated;
grant update (display_name, timezone, accent, theme_mode, kantong_view, settings)
  on public.profiles to authenticated;

-- ---------------------------------------------------------------------------
-- portfolios: the user's kantong. Every holding will belong to exactly one
-- (PRD A-39). Cash lives in a holding of category `cash` (HLD D-6, slice 2).
-- ---------------------------------------------------------------------------
create table public.portfolios (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid()
    references public.profiles (user_id) on delete cascade,
  name text not null
    check (name = btrim(name) and char_length(name) between 1 and 40),
  emoji text not null default '💼'
    check (char_length(emoji) between 1 and 16),
  color_key text not null default 'langit'
    check (color_key in ('langit', 'aprikot', 'lavender', 'emas',
                         'mint', 'jambu', 'laut', 'batu')),
  cash_enabled boolean not null default true,
  note text check (char_length(note) <= 280),
  sort_order integer not null,
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  -- Target for composite foreign keys from holdings (HLD 7).
  unique (id, user_id)
);

create index portfolios_user_order on public.portfolios (user_id, sort_order);

-- New kantong go to the end of the list unless the client picks a position.
create or replace function private.portfolios_default_sort_order()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.sort_order is null then
    select coalesce(max(p.sort_order), -1) + 1 into new.sort_order
    from public.portfolios p
    where p.user_id = new.user_id;
  end if;
  return new;
end;
$$;

create trigger portfolios_default_sort_order
  before insert on public.portfolios
  for each row execute function private.portfolios_default_sort_order();

create trigger portfolios_touch_updated_at
  before update on public.portfolios
  for each row execute function private.touch_updated_at();

alter table public.portfolios enable row level security;

create policy "own portfolios" on public.portfolios
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

revoke all on public.portfolios from anon, authenticated;
grant select, delete on public.portfolios to authenticated;
grant insert (name, emoji, color_key, cash_enabled, note, sort_order)
  on public.portfolios to authenticated;
grant update (name, emoji, color_key, cash_enabled, note, sort_order, archived_at)
  on public.portfolios to authenticated;

-- Reorder in one call: position in the array becomes sort_order.
-- Security invoker, so RLS limits it to the caller's own kantong.
create or replace function public.reorder_portfolios(ordered_ids uuid[])
returns void
language sql
security invoker
set search_path = ''
as $$
  update public.portfolios p
  set sort_order = o.ordinality - 1
  from unnest(ordered_ids) with ordinality as o (id, ordinality)
  where p.id = o.id;
$$;

revoke all on function public.reorder_portfolios(uuid[]) from public, anon;
grant execute on function public.reorder_portfolios(uuid[]) to authenticated;

-- ---------------------------------------------------------------------------
-- Signup: create the profile and the default kantong "Utama" (PRD F-PF-2).
-- ---------------------------------------------------------------------------
create or replace function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_name text := left(btrim(coalesce(
    nullif(btrim(new.raw_user_meta_data ->> 'display_name'), ''),
    split_part(coalesce(new.email, ''), '@', 1)
  )), 60);
begin
  insert into public.profiles (user_id, display_name)
  values (new.id, v_name);

  insert into public.portfolios (user_id, name, emoji, color_key, sort_order)
  values (new.id, 'Utama', '💼', 'langit', 0);

  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function private.handle_new_user();

-- ---------------------------------------------------------------------------
-- Delete account and all its data (PRD F-AUTH-6). Everything user-owned
-- cascades from auth.users -> profiles.
-- ---------------------------------------------------------------------------
create or replace function public.delete_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'not signed in' using errcode = '28000';
  end if;
  delete from auth.users where id = v_uid;
end;
$$;

revoke all on function public.delete_account() from public, anon;
grant execute on function public.delete_account() to authenticated;

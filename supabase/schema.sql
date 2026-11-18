-- The Stack Zone — Supabase schema
-- Run this once in Supabase → SQL Editor.

create extension if not exists pgcrypto;

-- Zones: public info only
create table if not exists zones (
  id          text primary key,
  name        text not null check (char_length(name) between 2 and 60),
  description text check (char_length(description) <= 160),
  listed      boolean not null default true,
  created_at  timestamptz not null default now()
);

-- Edit keys live in a separate table that nobody can read directly
create table if not exists zone_secrets (
  zone_id  text primary key references zones(id) on delete cascade,
  key_hash text not null
);

create table if not exists lives (
  id         uuid primary key default gen_random_uuid(),
  zone_id    text not null references zones(id) on delete cascade,
  url        text not null check (url ~ '^https://' and char_length(url) <= 400),
  creator    text not null check (char_length(creator) between 1 and 60),
  category   text not null default 'LIVE' check (char_length(category) <= 20),
  kind       text not null default 'link' check (kind in ('youtube', 'substack', 'link')),
  paid       int  not null default 0,
  ended      boolean not null default false,
  added_at   timestamptz not null default now()
);
-- Migration for existing deployments: add kind if the column doesn't exist yet
alter table lives add column if not exists kind text not null default 'link'
  check (kind in ('youtube', 'substack', 'link'));
create index if not exists lives_zone_idx on lives(zone_id, added_at desc);

create table if not exists headlines (
  id         uuid primary key default gen_random_uuid(),
  zone_id    text not null references zones(id) on delete cascade,
  text       text not null check (char_length(text) between 1 and 120),
  created_at timestamptz not null default now()
);

-- Row level security: public read, no direct writes (writes go through functions below)
alter table zones        enable row level security;
alter table zone_secrets enable row level security;
alter table lives        enable row level security;
alter table headlines    enable row level security;

drop policy if exists "read zones" on zones;
create policy "read zones" on zones for select using (true);
drop policy if exists "read lives" on lives;
create policy "read lives" on lives for select using (true);
drop policy if exists "read headlines" on headlines;
create policy "read headlines" on headlines for select using (true);
-- zone_secrets: no policies = no access for anon

-- Directory of listed zones with how many Lives are on right now
create or replace view zone_directory as
select z.id, z.name, z.description, z.created_at,
  (select count(*) from lives l
     where l.zone_id = z.id and not l.ended and l.added_at > now() - interval '2 hours') as live_count
from zones z
where z.listed;
grant select on zone_directory to anon, authenticated;

-- Helpers
create or replace function _check_key(p_zone text, p_key text) returns void
language plpgsql security definer set search_path = public, extensions as $$
begin
  if not exists (select 1 from zone_secrets
                 where zone_id = p_zone and key_hash = encode(digest(p_key, 'sha256'), 'hex')) then
    raise exception 'Invalid edit key';
  end if;
end $$;
revoke all on function _check_key(text, text) from public, anon, authenticated;

-- Create a zone → returns its id and private edit key
create or replace function create_zone(p_name text, p_description text, p_listed boolean)
returns json language plpgsql security definer set search_path = public, extensions as $$
declare
  v_id  text;
  v_key text := encode(gen_random_bytes(18), 'hex');
  v_base text := trim(both '-' from regexp_replace(lower(coalesce(p_name,'')), '[^a-z0-9]+', '-', 'g'));
begin
  if v_base = '' then v_base := 'zone'; end if;
  v_id := left(v_base, 40) || '-' || substr(encode(gen_random_bytes(3), 'hex'), 1, 5);
  insert into zones(id, name, description, listed) values (v_id, trim(p_name), nullif(trim(p_description), ''), coalesce(p_listed, true));
  insert into zone_secrets(zone_id, key_hash) values (v_id, encode(digest(v_key, 'sha256'), 'hex'));
  return json_build_object('id', v_id, 'edit_key', v_key);
end $$;

create or replace function check_edit_key(p_zone text, p_key text) returns boolean
language plpgsql security definer set search_path = public, extensions as $$
begin
  perform _check_key(p_zone, p_key); return true;
exception when others then return false;
end $$;

create or replace function add_live(p_zone text, p_key text, p_url text, p_creator text, p_category text)
returns uuid language plpgsql security definer set search_path = public, extensions as $$
declare
  v_id   uuid;
  v_kind text;
begin
  perform _check_key(p_zone, p_key);
  if (select count(*) from lives where zone_id = p_zone and not ended and added_at > now() - interval '2 hours') >= 16 then
    raise exception 'This zone already has 16 Lives on';
  end if;
  v_kind := case
    when p_url ~* 'youtube\.com|youtu\.be' then 'youtube'
    when p_url ~* '\.substack\.com'        then 'substack'
    else 'link'
  end;
  insert into lives(zone_id, url, creator, category, kind)
  values (p_zone, trim(p_url), trim(p_creator), upper(coalesce(nullif(trim(p_category),''), 'LIVE')), v_kind)
  returning id into v_id;
  return v_id;
end $$;

create or replace function end_live(p_zone text, p_key text, p_live uuid)
returns void language plpgsql security definer set search_path = public, extensions as $$
begin
  perform _check_key(p_zone, p_key);
  update lives set ended = true where id = p_live and zone_id = p_zone;
end $$;

-- "+1 PAID" — bumps the score bug and fires the hype guy for every viewer
create or replace function bump_paid(p_zone text, p_key text, p_live uuid)
returns void language plpgsql security definer set search_path = public, extensions as $$
begin
  perform _check_key(p_zone, p_key);
  update lives set paid = paid + 1 where id = p_live and zone_id = p_zone;
end $$;

create or replace function add_headline(p_zone text, p_key text, p_text text)
returns void language plpgsql security definer set search_path = public, extensions as $$
begin
  perform _check_key(p_zone, p_key);
  insert into headlines(zone_id, text) values (p_zone, trim(p_text));
  delete from headlines where zone_id = p_zone and id not in
    (select id from headlines where zone_id = p_zone order by created_at desc limit 8);
end $$;

grant execute on function create_zone(text, text, boolean)          to anon, authenticated;
grant execute on function check_edit_key(text, text)                to anon, authenticated;
grant execute on function add_live(text, text, text, text, text)    to anon, authenticated;
grant execute on function end_live(text, text, uuid)                to anon, authenticated;
grant execute on function bump_paid(text, text, uuid)               to anon, authenticated;
grant execute on function add_headline(text, text, text)            to anon, authenticated;

-- Realtime: push changes to viewers (idempotent)
do $$ begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'lives') then
    alter publication supabase_realtime add table lives;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'headlines') then
    alter publication supabase_realtime add table headlines;
  end if;
end $$;

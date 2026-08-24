-- ============================================================
-- Loods 25 — Supabase schema & functies
-- Voer dit EENMALIG uit: Supabase-project > SQL Editor > New query > plak alles > Run
-- ============================================================

create extension if not exists pgcrypto;

-- ============== TABELLEN ==============

create table if not exists users (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  pin_hash text,                          -- null = nog niet geclaimd
  total_ingelegd integer not null default 0,
  opgehaald integer not null default 0,
  created_at timestamptz not null default now()
);
create unique index if not exists users_name_lower_uidx on users (lower(name));

create table if not exists loods_log (
  id uuid primary key default gen_random_uuid(),
  type text not null check (type in ('inleg','ophalen')),
  user_id uuid references users(id) on delete set null,
  user_name text not null,
  amount integer not null,
  cumulative_after integer,               -- alleen ingevuld bij 'inleg'
  zakjes_after integer,                   -- alleen ingevuld bij 'inleg'
  zakjes_delta integer,                   -- alleen ingevuld bij 'inleg'
  tegoed_after integer,                   -- alleen ingevuld bij 'ophalen'
  ts timestamptz not null default now()
);
create index if not exists loods_log_ts_idx on loods_log (ts desc);

create table if not exists customers (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  phone text,
  groep text,
  total_geleverd integer not null default 0,
  created_at timestamptz not null default now(),
  created_by text
);
create unique index if not exists customers_name_lower_uidx on customers (lower(name));

create table if not exists customer_log (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references customers(id) on delete cascade,
  by_user_id uuid references users(id) on delete set null,
  by_user_name text not null,
  amount integer not null,
  cumulative_after integer not null,
  zakjes_after integer not null,
  zakjes_delta integer not null,
  ts timestamptz not null default now()
);
create index if not exists customer_log_customer_idx on customer_log (customer_id, ts desc);

-- ============== PUBLIEKE VIEW (zonder pin_hash!) ==============
-- De front-end leest gebruikers via deze view, nooit rechtstreeks uit `users`,
-- zodat de (gehashte) pincode nooit over de lijn gaat.

create or replace view users_public as
  select id, name, total_ingelegd, opgehaald, created_at, (pin_hash is not null) as claimed
  from users;

-- ============== ROW LEVEL SECURITY ==============
-- Iedereen (anon key) mag alles LEZEN. Schrijven kan alleen via de functies
-- hieronder (SECURITY DEFINER) — rechtstreekse INSERT/UPDATE/DELETE door de
-- browser wordt geblokkeerd omdat er geen policies voor bestaan.

alter table users enable row level security;
alter table loods_log enable row level security;
alter table customers enable row level security;
alter table customer_log enable row level security;

-- Bewust GEEN select-policy op `users` zelf — alleen via de `users_public` view.

drop policy if exists "select loods_log" on loods_log;
create policy "select loods_log" on loods_log for select using (true);

drop policy if exists "select customers" on customers;
create policy "select customers" on customers for select using (true);

drop policy if exists "select customer_log" on customer_log;
create policy "select customer_log" on customer_log for select using (true);

grant select on users_public to anon, authenticated;
grant select on loods_log, customers, customer_log to anon, authenticated;

-- ============== FUNCTIES ==============
-- SECURITY DEFINER: draaien met de rechten van de eigenaar (jij, via de SQL
-- editor), die als tabel-eigenaar altijd RLS mag omzeilen. Dat is de enige
-- weg naar schrijven — zo valideert en berekent de server alles zelf.

create or replace function fn_create_profile(p_name text, p_pin_hash text)
returns users
language plpgsql security definer set search_path = public as $$
declare v_count int; v_user users;
begin
  select count(*) into v_count from users;
  if v_count >= 25 then raise exception 'LOODS_VOL'; end if;
  if p_name is null or length(trim(p_name)) = 0 then raise exception 'ONGELDIGE_NAAM'; end if;
  if exists (select 1 from users where lower(name) = lower(trim(p_name))) then
    raise exception 'NAAM_BESTAAT_AL';
  end if;
  if p_pin_hash is null or length(p_pin_hash) <> 64 then raise exception 'ONGELDIGE_CODE'; end if;
  insert into users(name, pin_hash) values (trim(p_name), p_pin_hash) returning * into v_user;
  return v_user;
end; $$;

create or replace function fn_claim_profile(p_user_id uuid, p_pin_hash text)
returns users
language plpgsql security definer set search_path = public as $$
declare v_user users;
begin
  if p_pin_hash is null or length(p_pin_hash) <> 64 then raise exception 'ONGELDIGE_CODE'; end if;
  update users set pin_hash = p_pin_hash
    where id = p_user_id and pin_hash is null
    returning * into v_user;
  if v_user.id is null then raise exception 'AL_GECLAIMD'; end if;
  return v_user;
end; $$;

create or replace function fn_verify_login(p_user_id uuid, p_pin_hash text)
returns boolean
language sql security definer set search_path = public as $$
  select exists(select 1 from users where id = p_user_id and pin_hash = p_pin_hash);
$$;

create or replace function fn_register_inleg(p_user_id uuid, p_amount integer)
returns loods_log
language plpgsql security definer set search_path = public as $$
declare v_before int; v_after int; v_user users; v_log loods_log;
begin
  if p_amount is null or p_amount <= 0 then raise exception 'ONGELDIG_AANTAL'; end if;
  select * into v_user from users where id = p_user_id for update;
  if v_user.id is null then raise exception 'GEBRUIKER_NIET_GEVONDEN'; end if;
  v_before := floor(v_user.total_ingelegd / 3.0);
  update users set total_ingelegd = total_ingelegd + p_amount
    where id = p_user_id returning * into v_user;
  v_after := floor(v_user.total_ingelegd / 3.0);
  insert into loods_log(type, user_id, user_name, amount, cumulative_after, zakjes_after, zakjes_delta)
    values ('inleg', v_user.id, v_user.name, p_amount, v_user.total_ingelegd, v_after, v_after - v_before)
    returning * into v_log;
  return v_log;
end; $$;

create or replace function fn_register_ophalen(p_user_id uuid, p_amount integer)
returns loods_log
language plpgsql security definer set search_path = public as $$
declare v_user users; v_tegoed int; v_log loods_log;
begin
  if p_amount is null or p_amount <= 0 then raise exception 'ONGELDIG_AANTAL'; end if;
  select * into v_user from users where id = p_user_id for update;
  if v_user.id is null then raise exception 'GEBRUIKER_NIET_GEVONDEN'; end if;
  v_tegoed := floor(v_user.total_ingelegd / 3.0) - v_user.opgehaald;
  if p_amount > v_tegoed then raise exception 'ONVOLDOENDE_TEGOED'; end if;
  update users set opgehaald = opgehaald + p_amount
    where id = p_user_id returning * into v_user;
  insert into loods_log(type, user_id, user_name, amount, tegoed_after)
    values ('ophalen', v_user.id, v_user.name, p_amount, floor(v_user.total_ingelegd/3.0) - v_user.opgehaald)
    returning * into v_log;
  return v_log;
end; $$;

create or replace function fn_create_klant(p_name text, p_phone text, p_groep text, p_created_by text)
returns customers
language plpgsql security definer set search_path = public as $$
declare v_klant customers;
begin
  if p_name is null or length(trim(p_name)) = 0 then raise exception 'ONGELDIGE_NAAM'; end if;
  if exists (select 1 from customers where lower(name) = lower(trim(p_name))) then
    raise exception 'KLANT_BESTAAT_AL';
  end if;
  insert into customers(name, phone, groep, created_by)
    values (trim(p_name), nullif(trim(coalesce(p_phone,'')),''), nullif(trim(coalesce(p_groep,'')),''), p_created_by)
    returning * into v_klant;
  return v_klant;
end; $$;

create or replace function fn_register_levering(p_customer_id uuid, p_amount integer, p_by_user_id uuid, p_by_user_name text)
returns customer_log
language plpgsql security definer set search_path = public as $$
declare v_before int; v_after int; v_klant customers; v_log customer_log;
begin
  if p_amount is null or p_amount <= 0 then raise exception 'ONGELDIG_AANTAL'; end if;
  select * into v_klant from customers where id = p_customer_id for update;
  if v_klant.id is null then raise exception 'KLANT_NIET_GEVONDEN'; end if;
  v_before := floor(v_klant.total_geleverd / 4.0);
  update customers set total_geleverd = total_geleverd + p_amount
    where id = p_customer_id returning * into v_klant;
  v_after := floor(v_klant.total_geleverd / 4.0);
  insert into customer_log(customer_id, by_user_id, by_user_name, amount, cumulative_after, zakjes_after, zakjes_delta)
    values (v_klant.id, p_by_user_id, p_by_user_name, p_amount, v_klant.total_geleverd, v_after, v_after - v_before)
    returning * into v_log;
  return v_log;
end; $$;

grant execute on function
  fn_create_profile(text, text),
  fn_claim_profile(uuid, text),
  fn_verify_login(uuid, text),
  fn_register_inleg(uuid, integer),
  fn_register_ophalen(uuid, integer),
  fn_create_klant(text, text, text, text),
  fn_register_levering(uuid, integer, uuid, text)
to anon, authenticated;

-- ============== STARTPROFIELEN ==============

insert into users(name) values ('siebe'),('ivar'),('bob'),('matis')
  on conflict do nothing;

-- ============== REALTIME ==============
-- Zet live-updates aan zodat alle 25 leden elkaars acties meteen zien.
-- Als dit een foutmelding geeft dat de tabellen al toegevoegd zijn: negeren, dat betekent dat het al aan staat.

alter publication supabase_realtime add table users, loods_log, customers, customer_log;

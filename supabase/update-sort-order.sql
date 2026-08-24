-- ============================================================
-- Wietloods — update: profielen handmatig herschikken (Boss menu)
-- Voer dit EENMALIG uit in de Supabase SQL Editor (New query > plak > Run),
-- na de vorige updates.
-- ============================================================

-- ============== KOLOM + BACKFILL ==============

alter table users add column if not exists sort_order integer;

-- bestaande profielen krijgen een startvolgorde op basis van aanmaakdatum
update users u set sort_order = sub.rn
from (select id, row_number() over (order by created_at) as rn from users) sub
where u.id = sub.id and u.sort_order is null;

create or replace view users_public as
  select id, name, total_ingelegd, opgehaald, created_at, (pin_hash is not null) as claimed, avatar_url, sort_order
  from users;

-- ============== NIEUWE PROFIELEN: automatisch achteraan ==============

create or replace function fn_create_profile(p_name text, p_pin_hash text)
returns users
language plpgsql security definer set search_path = public as $$
declare v_count int; v_user users; v_next_order int;
begin
  select count(*) into v_count from users;
  if v_count >= 25 then raise exception 'LOODS_VOL'; end if;
  if p_name is null or length(trim(p_name)) = 0 then raise exception 'ONGELDIGE_NAAM'; end if;
  if exists (select 1 from users where lower(name) = lower(trim(p_name))) then
    raise exception 'NAAM_BESTAAT_AL';
  end if;
  if p_pin_hash is null or length(p_pin_hash) <> 64 then raise exception 'ONGELDIGE_CODE'; end if;
  select coalesce(max(sort_order), 0) + 1 into v_next_order from users;
  insert into users(name, pin_hash, sort_order) values (trim(p_name), p_pin_hash, v_next_order) returning * into v_user;
  return v_user;
end; $$;

-- ============== BOSS: VOLGORDE INSTELLEN (slepen) ==============

create or replace function fn_boss_set_order(p_order jsonb, p_boss_pin_hash text)
returns boolean
language plpgsql security definer set search_path = public as $$
declare v_ok boolean; v_id_text text; v_idx integer := 0;
begin
  select exists(select 1 from admin_config where id = true and boss_pin_hash = p_boss_pin_hash) into v_ok;
  if not v_ok then raise exception 'ONJUISTE_BOSSCODE'; end if;
  for v_id_text in select * from jsonb_array_elements_text(p_order) loop
    update users set sort_order = v_idx where id = v_id_text::uuid;
    v_idx := v_idx + 1;
  end loop;
  return true;
end; $$;
grant execute on function fn_boss_set_order(jsonb, text) to anon, authenticated;

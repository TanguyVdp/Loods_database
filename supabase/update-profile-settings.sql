-- ============================================================
-- Wietloods — update: profielinstellingen (naam, code wijzigen, boss reset)
-- Voer dit EENMALIG uit in de Supabase SQL Editor (New query > plak > Run),
-- na de vorige updates.
-- ============================================================

-- ============== NAAM WIJZIGEN ==============

create or replace function fn_update_name(p_user_id uuid, p_new_name text)
returns users
language plpgsql security definer set search_path = public as $$
declare v_user users;
begin
  if p_new_name is null or length(trim(p_new_name)) = 0 then raise exception 'ONGELDIGE_NAAM'; end if;
  if exists (select 1 from users where lower(name) = lower(trim(p_new_name)) and id <> p_user_id) then
    raise exception 'NAAM_BESTAAT_AL';
  end if;
  update users set name = trim(p_new_name) where id = p_user_id returning * into v_user;
  if v_user.id is null then raise exception 'GEBRUIKER_NIET_GEVONDEN'; end if;
  return v_user;
end; $$;
grant execute on function fn_update_name(uuid, text) to anon, authenticated;

-- ============== CODE WIJZIGEN (met huidige code) ==============

create or replace function fn_change_pin(p_user_id uuid, p_old_pin_hash text, p_new_pin_hash text)
returns boolean
language plpgsql security definer set search_path = public as $$
declare v_ok boolean;
begin
  if p_new_pin_hash is null or length(p_new_pin_hash) <> 64 then raise exception 'ONGELDIGE_CODE'; end if;
  select exists(select 1 from users where id = p_user_id and pin_hash = p_old_pin_hash) into v_ok;
  if not v_ok then raise exception 'ONJUISTE_CODE'; end if;
  update users set pin_hash = p_new_pin_hash where id = p_user_id;
  return true;
end; $$;
grant execute on function fn_change_pin(uuid, text, text) to anon, authenticated;

-- ============== BOSS: CODE RESETTEN ==============
-- Profiel blijft volledig bestaan (naam, geschiedenis, totalen) maar wordt
-- terug "vrij" (claimed = false), zodat de persoon opnieuw kan claimen met
-- een nieuwe zelfgekozen code.

create or replace function fn_boss_reset_pin(p_user_id uuid, p_boss_pin_hash text)
returns boolean
language plpgsql security definer set search_path = public as $$
declare v_ok boolean;
begin
  select exists(select 1 from admin_config where id = true and boss_pin_hash = p_boss_pin_hash) into v_ok;
  if not v_ok then raise exception 'ONJUISTE_BOSSCODE'; end if;
  update users set pin_hash = null where id = p_user_id;
  if not found then raise exception 'GEBRUIKER_NIET_GEVONDEN'; end if;
  return true;
end; $$;
grant execute on function fn_boss_reset_pin(uuid, text) to anon, authenticated;

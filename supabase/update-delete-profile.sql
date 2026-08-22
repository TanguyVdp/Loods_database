-- ============================================================
-- Wietloods — update: profiel verwijderen vanuit Boss menu
-- Voer dit EENMALIG uit in de Supabase SQL Editor (New query > plak > Run),
-- NA schema.sql en update-boss-menu.sql die je al gerund hebt.
-- Raakt je ingestelde bosscode NIET aan.
-- ============================================================

create or replace function fn_delete_profile(p_user_id uuid, p_boss_pin_hash text)
returns boolean
language plpgsql security definer set search_path = public as $$
declare v_ok boolean;
begin
  select exists(select 1 from admin_config where id = true and boss_pin_hash = p_boss_pin_hash) into v_ok;
  if not v_ok then raise exception 'ONJUISTE_BOSSCODE'; end if;
  delete from users where id = p_user_id;
  if not found then raise exception 'GEBRUIKER_NIET_GEVONDEN'; end if;
  return true;
end; $$;

grant execute on function fn_delete_profile(uuid, text) to anon, authenticated;

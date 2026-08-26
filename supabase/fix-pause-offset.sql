-- ============================================================
-- Wietloods — fix: pauzeduur telt nu mee als extra verschuiving
--
-- Tot nu toe bevroor pauzeren enkel de WEERGAVE (nowForQueue in index.html),
-- maar de onderliggende planning rekende gewoon door met de echte klok.
-- Bij hervatten leek het daardoor alsof er tijdens de pauze "vanzelf" van
-- alles verwerkt was. Nu telt de pauzeduur (paused_at tot het moment van
-- hervatten) automatisch mee op bij offset_minutes — exact hetzelfde
-- mechanisme als een server-restart, maar dan voor de pauze zelf.
--
-- Voer dit EENMALIG uit in de Supabase SQL Editor.
-- ============================================================

create or replace function fn_set_maintenance(p_paused boolean, p_user_id uuid, p_pin_hash text)
returns loods_baseline
language plpgsql security definer set search_path = public as $$
declare v_name text; v_row loods_baseline; v_pause_minutes int;
begin
  select lower(name) into v_name from users where id = p_user_id and pin_hash = p_pin_hash;
  if v_name is null or v_name not like 'bob%' then raise exception 'ONJUISTE_CODE'; end if;

  select * into v_row from loods_baseline where id = true;

  if p_paused then
    update loods_baseline set paused = true, paused_at = now()
      where id = true returning * into v_row;
  else
    if v_row.paused and v_row.paused_at is not null then
      v_pause_minutes := round(extract(epoch from (now() - v_row.paused_at)) / 60.0);
    else
      v_pause_minutes := 0;
    end if;
    update loods_baseline set paused = false, paused_at = null,
      offset_minutes = offset_minutes + v_pause_minutes
      where id = true returning * into v_row;
  end if;

  return v_row;
end; $$;
grant execute on function fn_set_maintenance(boolean, uuid, text) to anon, authenticated;

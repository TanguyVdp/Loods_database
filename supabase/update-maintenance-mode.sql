-- ============================================================
-- Wietloods — update: onderhoudsmodus (pauzeknop op Bob's dashboard)
-- Pauzeert de wachtrij-klok (bevriest op het exacte moment van pauzeren) en
-- blokkeert inleg/ophalen voor iedereen, tot Bob opnieuw hervat. Handig om
-- de site "stil te zetten" tijdens onderhoud (bv. een ratio-wijziging),
-- zodat er geen data meer verandert terwijl er getest/aangepast wordt.
-- Voer dit EENMALIG uit in de Supabase SQL Editor (New query > plak > Run).
-- ============================================================

alter table loods_baseline add column if not exists paused boolean not null default false;
alter table loods_baseline add column if not exists paused_at timestamptz;

-- Zelfde toegangscontrole als fn_set_loods_baseline: enkel het profiel met
-- naam die met "bob" begint, geverifieerd via zijn eigen pincode.
create or replace function fn_set_maintenance(p_paused boolean, p_user_id uuid, p_pin_hash text)
returns loods_baseline
language plpgsql security definer set search_path = public as $$
declare v_name text; v_row loods_baseline;
begin
  select lower(name) into v_name from users where id = p_user_id and pin_hash = p_pin_hash;
  if v_name is null or v_name not like 'bob%' then raise exception 'ONJUISTE_CODE'; end if;
  update loods_baseline set paused = p_paused, paused_at = case when p_paused then now() else null end
    where id = true returning * into v_row;
  return v_row;
end; $$;
grant execute on function fn_set_maintenance(boolean, uuid, text) to anon, authenticated;

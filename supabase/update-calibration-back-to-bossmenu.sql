-- ============================================================
-- Wietloods — kalibreren + pauzeren terug naar Boss menu (bosscode)
-- i.p.v. Bob's persoonlijke pincode. Stabieler: de bosscode verandert
-- nooit, in tegenstelling tot iemands persoonlijke code.
-- Voer dit EENMALIG uit in de Supabase SQL Editor.
-- ============================================================

drop function if exists fn_set_loods_baseline(integer, integer, integer, uuid, text);

create or replace function fn_set_loods_baseline(p_offset_minutes integer, p_batch_size integer, p_batch_minutes integer, p_boss_pin_hash text, p_set_by text)
returns loods_baseline
language plpgsql security definer set search_path = public as $$
declare v_ok boolean; v_row loods_baseline;
begin
  select exists(select 1 from admin_config where id = true and boss_pin_hash = p_boss_pin_hash) into v_ok;
  if not v_ok then raise exception 'ONJUISTE_BOSSCODE'; end if;
  if p_offset_minutes is null then raise exception 'ONGELDIG_AANTAL'; end if;
  if p_batch_size is null or p_batch_size <= 0 then raise exception 'ONGELDIGE_BATCH'; end if;
  if p_batch_minutes is null or p_batch_minutes <= 0 then raise exception 'ONGELDIGE_BATCH'; end if;
  update loods_baseline set offset_minutes = p_offset_minutes, batch_size = p_batch_size, batch_minutes = p_batch_minutes,
    set_at = now(), set_by = p_set_by
    where id = true returning * into v_row;
  return v_row;
end; $$;
grant execute on function fn_set_loods_baseline(integer, integer, integer, text, text) to anon, authenticated;

drop function if exists fn_set_maintenance(boolean, uuid, text);

create or replace function fn_set_maintenance(p_paused boolean, p_boss_pin_hash text)
returns loods_baseline
language plpgsql security definer set search_path = public as $$
declare v_ok boolean; v_row loods_baseline; v_pause_minutes int;
begin
  select exists(select 1 from admin_config where id = true and boss_pin_hash = p_boss_pin_hash) into v_ok;
  if not v_ok then raise exception 'ONJUISTE_BOSSCODE'; end if;

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
grant execute on function fn_set_maintenance(boolean, text) to anon, authenticated;

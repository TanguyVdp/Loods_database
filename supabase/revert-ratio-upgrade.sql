-- ============================================================
-- Wietloods — VOLLEDIGE TERUGDRAAI van de ratio-upgrade-poging (2/1)
--
-- Zet alles terug naar exact de staat van het moment dat de wachtrij
-- gepauzeerd werd (26/08, 17u49:06 Belgische tijd) — vóór er iets aan de
-- ratio, de snelheid of legacy_zakjes veranderd was:
--   - loods_baseline terug naar de oude snelheid (3 zakjes/3 min) en de
--     oude kalibratie (offset -5 min), pauzemoment ongewijzigd op het
--     originele tijdstip
--   - legacy_zakjes van iedereen terug naar 0 (geen ratio-splitsing meer)
--   - fn_register_inleg / fn_register_ophalen terug naar de simpele 3:1-
--     formule (exact zoals in update-ratio-3to1.sql), geen gesplitste
--     legacy/nieuw-formule meer
--
-- De site blijft gewoon gepauzeerd — niemand kan intussen iets aanpassen.
-- Voer dit EENMALIG uit in de Supabase SQL Editor.
-- ============================================================

update loods_baseline
  set batch_size = 3, batch_minutes = 3, offset_minutes = -5,
      paused_at = '2026-08-26T15:49:06.807727+00:00'
  where id = true;

update users set legacy_zakjes = 0;

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

-- ============================================================
-- Wietloods — loods-upgrade: ratio 3:1 -> 2:1 + snellere verwerking (fris)
--
-- Dit gebeurt nu op een volledig LEGE loods (net gereset) — dus geen
-- legacy-opsplitsing nodig zoals bij de eerdere (mislukte) poging: iedereen
-- start gewoon vanaf 0 aan de nieuwe ratio en snelheid. De RPC's gebruiken
-- wel dezelfde legacy_zakjes-bewuste formule als voorbereiding op een
-- eventuele latere ratio-wijziging (legacy_zakjes blijft gewoon op 0 staan
-- voor iedereen, dus in de praktijk gedraagt dit zich als een simpele 2:1).
--
-- Voer dit EENMALIG uit in de Supabase SQL Editor (New query > plak > Run).
-- ============================================================

create or replace function fn_register_inleg(p_user_id uuid, p_amount integer)
returns loods_log
language plpgsql security definer set search_path = public as $$
declare v_before int; v_after int; v_user users; v_log loods_log; v_rest int;
begin
  if p_amount is null or p_amount <= 0 then raise exception 'ONGELDIG_AANTAL'; end if;
  select * into v_user from users where id = p_user_id for update;
  if v_user.id is null then raise exception 'GEBRUIKER_NIET_GEVONDEN'; end if;
  v_rest := greatest(0, v_user.total_ingelegd - v_user.legacy_zakjes * 3);
  v_before := v_user.legacy_zakjes + floor(v_rest / 2.0);
  update users set total_ingelegd = total_ingelegd + p_amount
    where id = p_user_id returning * into v_user;
  v_rest := greatest(0, v_user.total_ingelegd - v_user.legacy_zakjes * 3);
  v_after := v_user.legacy_zakjes + floor(v_rest / 2.0);
  insert into loods_log(type, user_id, user_name, amount, cumulative_after, zakjes_after, zakjes_delta)
    values ('inleg', v_user.id, v_user.name, p_amount, v_user.total_ingelegd, v_after, v_after - v_before)
    returning * into v_log;
  return v_log;
end; $$;

create or replace function fn_register_ophalen(p_user_id uuid, p_amount integer)
returns loods_log
language plpgsql security definer set search_path = public as $$
declare v_user users; v_tegoed int; v_zakjes int; v_rest int; v_log loods_log;
begin
  if p_amount is null or p_amount <= 0 then raise exception 'ONGELDIG_AANTAL'; end if;
  select * into v_user from users where id = p_user_id for update;
  if v_user.id is null then raise exception 'GEBRUIKER_NIET_GEVONDEN'; end if;
  v_rest := greatest(0, v_user.total_ingelegd - v_user.legacy_zakjes * 3);
  v_zakjes := v_user.legacy_zakjes + floor(v_rest / 2.0);
  v_tegoed := v_zakjes - v_user.opgehaald;
  if p_amount > v_tegoed then raise exception 'ONVOLDOENDE_TEGOED'; end if;
  update users set opgehaald = opgehaald + p_amount
    where id = p_user_id returning * into v_user;
  insert into loods_log(type, user_id, user_name, amount, tegoed_after)
    values ('ophalen', v_user.id, v_user.name, p_amount, v_zakjes - v_user.opgehaald)
    returning * into v_log;
  return v_log;
end; $$;

update loods_baseline set batch_size = 5, batch_minutes = 2, offset_minutes = 0 where id = true;

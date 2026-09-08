-- ============================================================
-- Wietloods — update: max onverwerkt van 4.000 naar 5.000 planten
--
-- Zelfde regel als in update-max-onverwerkt.sql, enkel de grens omhoog:
-- iedereen mag nu tot 5.000 planten "momenteel inleg" (nog niet door de
-- wachtrij verwerkt) tegelijk hebben liggen i.p.v. 4.000. Verder ongewijzigd
-- — nog steeds geen harde totaalgrens, enkel op wat er nu nog onverwerkt ligt,
-- en die ruimte groeit vanzelf weer aan naarmate de wachtrij verwerkt.
--
-- Voer dit EENMALIG uit in de Supabase SQL Editor, na update-max-onverwerkt.sql.
-- ============================================================

drop function if exists fn_register_inleg(uuid, integer, integer);

create or replace function fn_register_inleg(p_user_id uuid, p_amount integer, p_huidig_momenteel_inleg integer)
returns loods_log
language plpgsql security definer set search_path = public as $$
declare v_before int; v_after int; v_user users; v_log loods_log; v_rest int;
begin
  if p_amount is null or p_amount <= 0 then raise exception 'ONGELDIG_AANTAL'; end if;
  if p_huidig_momenteel_inleg is not null and p_huidig_momenteel_inleg + p_amount > 5000 then
    raise exception 'MAX_ONVERWERKT_BEREIKT';
  end if;
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
grant execute on function fn_register_inleg(uuid, integer, integer) to anon, authenticated;

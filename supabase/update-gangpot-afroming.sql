-- ============================================================
-- Wietloods — update: gangpot-afroming op elke inleg (puur server-side)
--
-- Bij ELKE inleg (door wie dan ook, via het gewone inlegformulier of via
-- het Boss-registratieformulier) gaat vanaf nu 1 op elke 5 ingelegde
-- planten automatisch naar een gedeeld profiel "gangpot" — de overige 4
-- op 5 blijven voor de inlegger zelf. Bij 10 ingelegde planten (= 5
-- zakjes aan de huidige 2:1-ratio): 4 zakjes voor de persoon, 1 zakje
-- voor gangpot. Bij 1000 planten: 800 voor de persoon (-> 400 zakjes),
-- 200 voor gangpot (-> 100 zakjes).
--
-- Dit gebeurt volledig in fn_register_inleg zelf — de website-code (RPC-
-- aanroep, formulieren, wachtrij-weergave, Overzicht per profiel) blijft
-- ONGEWIJZIGD: die kent "gangpot" niet, het is gewoon een extra profiel
-- met zijn eigen Ingelegd/Tegoed, net als alle andere 25. Het logboek
-- krijgt per inleg nu wel 2 regels i.p.v. 1 (inlegger + gangpot vlak na
-- elkaar) — daardoor toont de wachtrij gangpot's aandeel automatisch als
-- volgende regel vlak na die van de inlegger (zelfde boundary-batch-
-- gedrag als bij 2 gewone opeenvolgende inleggingen).
--
-- Aannames (makkelijk aan te passen in een latere update als nodig):
--   - verdeling is vast op 1/5 (20%) voor gangpot, 4/5 (80%) voor de
--     inlegger — afgerond naar onder op planten-niveau (floor(bedrag/5))
--   - logt iemand in ALS gangpot zelf, dan wordt er niet van gangpot
--     zelf afgeroomd (voorkomt een cirkel)
--   - gangpot is een volwaardig profiel: het kan zelf ook gewoon
--     gepincodeerd/geclaimd en opgehaald worden zoals ieder ander profiel
--   - dit geldt vanaf NU voor nieuwe inleg; niet retroactief op bestaande
--     logboek-regels (niet nodig: de loods wordt toch volledig gereset,
--     zie reset-loods-data.sql — volgorde van de 2 scripts maakt niet uit)
--
-- Voer dit EENMALIG uit in de Supabase SQL Editor (New query > plak > Run).
-- ============================================================

-- gangpot-profiel aanmaken indien het nog niet bestaat (onderaan de
-- bestaande volgorde, zelf nog niet geclaimd/geen pincode)
insert into users (name, sort_order)
select 'gangpot', coalesce((select max(sort_order) from users), 0) + 1
where not exists (select 1 from users where lower(name) = 'gangpot');

drop function if exists fn_register_inleg(uuid, integer, integer);

create or replace function fn_register_inleg(p_user_id uuid, p_amount integer, p_huidig_momenteel_inleg integer)
returns loods_log
language plpgsql security definer set search_path = public as $$
declare
  v_before int; v_after int; v_user users; v_log loods_log; v_rest int;
  v_gangpot_id uuid; v_amount_gangpot int; v_amount_self int;
  v_gangpot users; v_gangpot_before int; v_gangpot_after int; v_gangpot_rest int;
begin
  if p_amount is null or p_amount <= 0 then raise exception 'ONGELDIG_AANTAL'; end if;
  if p_huidig_momenteel_inleg is not null and p_huidig_momenteel_inleg + p_amount > 6000 then
    raise exception 'MAX_ONVERWERKT_BEREIKT';
  end if;

  select * into v_user from users where id = p_user_id for update;
  if v_user.id is null then raise exception 'GEBRUIKER_NIET_GEVONDEN'; end if;

  select id into v_gangpot_id from users where lower(name) = 'gangpot';

  if v_gangpot_id is not null and v_gangpot_id <> p_user_id then
    v_amount_gangpot := floor(p_amount / 5.0);
  else
    v_amount_gangpot := 0;
  end if;
  v_amount_self := p_amount - v_amount_gangpot;

  -- aandeel van de inlegger zelf (4/5)
  v_rest := greatest(0, v_user.total_ingelegd - v_user.legacy_zakjes * 3);
  v_before := v_user.legacy_zakjes + floor(v_rest / 2.0);
  update users set total_ingelegd = total_ingelegd + v_amount_self
    where id = p_user_id returning * into v_user;
  v_rest := greatest(0, v_user.total_ingelegd - v_user.legacy_zakjes * 3);
  v_after := v_user.legacy_zakjes + floor(v_rest / 2.0);
  insert into loods_log(type, user_id, user_name, amount, cumulative_after, zakjes_after, zakjes_delta)
    values ('inleg', v_user.id, v_user.name, v_amount_self, v_user.total_ingelegd, v_after, v_after - v_before)
    returning * into v_log;

  -- aandeel van gangpot (1/5) — apart, vlak aansluitend logboek-regeltje
  if v_amount_gangpot > 0 then
    select * into v_gangpot from users where id = v_gangpot_id for update;
    v_gangpot_rest := greatest(0, v_gangpot.total_ingelegd - v_gangpot.legacy_zakjes * 3);
    v_gangpot_before := v_gangpot.legacy_zakjes + floor(v_gangpot_rest / 2.0);
    update users set total_ingelegd = total_ingelegd + v_amount_gangpot
      where id = v_gangpot_id returning * into v_gangpot;
    v_gangpot_rest := greatest(0, v_gangpot.total_ingelegd - v_gangpot.legacy_zakjes * 3);
    v_gangpot_after := v_gangpot.legacy_zakjes + floor(v_gangpot_rest / 2.0);
    insert into loods_log(type, user_id, user_name, amount, cumulative_after, zakjes_after, zakjes_delta)
      values ('inleg', v_gangpot.id, v_gangpot.name, v_amount_gangpot, v_gangpot.total_ingelegd, v_gangpot_after, v_gangpot_after - v_gangpot_before);
  end if;

  return v_log;
end; $$;
grant execute on function fn_register_inleg(uuid, integer, integer) to anon, authenticated;

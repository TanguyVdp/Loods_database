-- ============================================================
-- Wietloods — update: klanten kunnen nu ook "geleverd" (verkocht voor geld)
-- worden i.p.v. enkel "geswapt" (het bestaande 4:1-systeem).
--
-- Swappen (bestaand, ongewijzigd): 4 geswapt = 1 zakje, meteen meegekregen.
-- Leveren/verkopen (nieuw): vrije prijs per stuk, geen zakjes — puur een
-- verkoopregistratie met automatisch berekende totaalprijs.
--
-- Voer dit EENMALIG uit in de Supabase SQL Editor (New query > plak > Run).
-- ============================================================

-- ============== KOLOMMEN ==============

alter table customer_log add column if not exists kind text not null default 'swap' check (kind in ('swap','levering'));
alter table customer_log add column if not exists price_per_unit numeric;
alter table customer_log add column if not exists total_price numeric;

alter table customers add column if not exists total_verkocht integer not null default 0;
alter table customers add column if not exists total_omzet numeric not null default 0;

-- ============== NIEUWE FUNCTIE: verkoop registreren ==============

create or replace function fn_register_levering_verkoop(
  p_customer_id uuid, p_amount integer, p_price_per_unit numeric,
  p_by_user_id uuid, p_by_user_name text
)
returns customer_log
language plpgsql security definer set search_path = public as $$
declare v_klant customers; v_log customer_log; v_total numeric;
begin
  if p_amount is null or p_amount <= 0 then raise exception 'ONGELDIG_AANTAL'; end if;
  if p_price_per_unit is null or p_price_per_unit < 0 then raise exception 'ONGELDIGE_PRIJS'; end if;

  select * into v_klant from customers where id = p_customer_id for update;
  if v_klant.id is null then raise exception 'KLANT_NIET_GEVONDEN'; end if;

  v_total := p_amount * p_price_per_unit;

  update customers set total_verkocht = total_verkocht + p_amount, total_omzet = total_omzet + v_total
    where id = p_customer_id returning * into v_klant;

  insert into customer_log(customer_id, by_user_id, by_user_name, amount, cumulative_after, zakjes_after, zakjes_delta, kind, price_per_unit, total_price)
    values (v_klant.id, p_by_user_id, p_by_user_name, p_amount, v_klant.total_verkocht, 0, 0, 'levering', p_price_per_unit, v_total)
    returning * into v_log;

  return v_log;
end; $$;
grant execute on function fn_register_levering_verkoop(uuid, integer, numeric, uuid, text) to anon, authenticated;

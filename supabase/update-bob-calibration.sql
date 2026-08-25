-- ============================================================
-- Wietloods — update: wachtrij-kalibratie verhuist van Boss menu naar het
-- dashboard, enkel zichtbaar/bruikbaar voor het profiel "bob". Geen aparte
-- bosscode meer nodig — in de plaats daarvan wordt Bob's EIGEN pincode
-- gecontroleerd (dezelfde die hij gebruikt om in te loggen), gekoppeld aan
-- het profiel met naam "bob". Dat is geen open deur: de server controleert
-- nog steeds een echt geheim (de pincode), enkel niet meer de gedeelde
-- bosscode maar Bob's persoonlijke code.
-- Voer dit EENMALIG uit in de Supabase SQL Editor (New query > plak > Run),
-- na de vorige updates.
-- ============================================================

drop function if exists fn_set_loods_baseline(integer, integer, integer, text, text);

create or replace function fn_set_loods_baseline(p_offset_minutes integer, p_batch_size integer, p_batch_minutes integer, p_user_id uuid, p_pin_hash text)
returns loods_baseline
language plpgsql security definer set search_path = public as $$
declare v_name text; v_row loods_baseline;
begin
  select lower(name) into v_name from users where id = p_user_id and pin_hash = p_pin_hash;
  if v_name is null or v_name not like 'bob%' then raise exception 'ONJUISTE_CODE'; end if;
  if p_offset_minutes is null then raise exception 'ONGELDIG_AANTAL'; end if;
  if p_batch_size is null or p_batch_size <= 0 then raise exception 'ONGELDIGE_BATCH'; end if;
  if p_batch_minutes is null or p_batch_minutes <= 0 then raise exception 'ONGELDIGE_BATCH'; end if;
  update loods_baseline set offset_minutes = p_offset_minutes, batch_size = p_batch_size, batch_minutes = p_batch_minutes,
    set_at = now(), set_by = 'Bob'
    where id = true returning * into v_row;
  return v_row;
end; $$;
grant execute on function fn_set_loods_baseline(integer, integer, integer, uuid, text) to anon, authenticated;

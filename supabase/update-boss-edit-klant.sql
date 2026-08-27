-- ============================================================
-- Wietloods — update: klanten bewerken vanuit Boss menu
-- Naam, groep, telefoon en de tellers (geswapt/verkocht/omzet) rechtstreeks
-- aanpasbaar — zelfde patroon als "profiel bewerken" bij leden. Wijziging
-- wordt gelogd als 'correctie' in customer_log (met een leesbare notitie).
-- Voer dit EENMALIG uit in de Supabase SQL Editor (New query > plak > Run).
-- ============================================================

alter table customer_log add column if not exists note text;
alter table customer_log drop constraint if exists customer_log_kind_check;
alter table customer_log add constraint customer_log_kind_check check (kind in ('swap','levering','correctie'));

create or replace function fn_boss_set_klant_data(
  p_customer_id uuid, p_name text, p_groep text, p_phone text,
  p_total_geleverd integer, p_total_verkocht integer, p_total_omzet numeric,
  p_boss_pin_hash text, p_set_by text
)
returns customers
language plpgsql security definer set search_path = public as $$
declare v_ok boolean; v_before customers; v_after customers; v_note text;
begin
  select exists(select 1 from admin_config where id = true and boss_pin_hash = p_boss_pin_hash) into v_ok;
  if not v_ok then raise exception 'ONJUISTE_BOSSCODE'; end if;
  if p_name is null or length(trim(p_name)) = 0 then raise exception 'ONGELDIGE_NAAM'; end if;
  if exists (select 1 from customers where lower(name) = lower(trim(p_name)) and id <> p_customer_id) then
    raise exception 'KLANT_BESTAAT_AL';
  end if;
  if p_total_geleverd is null or p_total_geleverd < 0 then raise exception 'ONGELDIG_AANTAL'; end if;
  if p_total_verkocht is null or p_total_verkocht < 0 then raise exception 'ONGELDIG_AANTAL'; end if;
  if p_total_omzet is null or p_total_omzet < 0 then raise exception 'ONGELDIGE_PRIJS'; end if;

  select * into v_before from customers where id = p_customer_id for update;
  if v_before.id is null then raise exception 'KLANT_NIET_GEVONDEN'; end if;

  update customers set
    name = trim(p_name), groep = nullif(trim(coalesce(p_groep,'')),''), phone = nullif(trim(coalesce(p_phone,'')),''),
    total_geleverd = p_total_geleverd, total_verkocht = p_total_verkocht, total_omzet = p_total_omzet
    where id = p_customer_id returning * into v_after;

  v_note := format('naam "%s"->"%s", geswapt %s->%s, verkocht %s->%s, omzet €%s->€%s%s',
    v_before.name, v_after.name, v_before.total_geleverd, v_after.total_geleverd,
    v_before.total_verkocht, v_after.total_verkocht, v_before.total_omzet, v_after.total_omzet,
    case when p_set_by is not null then ' (door ' || p_set_by || ')' else '' end);

  insert into customer_log(customer_id, by_user_id, by_user_name, amount, cumulative_after, zakjes_after, zakjes_delta, kind, note)
    values (v_after.id, null, coalesce(p_set_by,'Boss'), 0, v_after.total_geleverd, 0, 0, 'correctie', v_note);

  return v_after;
end; $$;
grant execute on function fn_boss_set_klant_data(uuid, text, text, text, integer, integer, numeric, text, text) to anon, authenticated;

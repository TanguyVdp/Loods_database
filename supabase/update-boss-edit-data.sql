-- ============================================================
-- Wietloods — update: Boss menu kan alle profielgegevens rechtstreeks bewerken
-- Voegt fn_boss_set_user_data toe: Boss kan Ingelegd, Opgehaald en Legacy
-- zakjes van eender welk profiel rechtstreeks overschrijven — handig voor
-- correcties. Elke wijziging wordt gelogd als 'correctie' in het logboek
-- (met een leesbare beschrijving van de oude/nieuwe waarden), zodat er een
-- spoor van blijft.
-- Voer dit EENMALIG uit in de Supabase SQL Editor (New query > plak > Run).
-- ============================================================

-- vrije-tekst kolom voor logboek-notities (enkel gebruikt door 'correctie'-regels)
alter table loods_log add column if not exists note text;

-- 'correctie' toevoegen als geldig logboek-type naast 'inleg'/'ophalen'
alter table loods_log drop constraint if exists loods_log_type_check;
alter table loods_log add constraint loods_log_type_check check (type in ('inleg','ophalen','correctie'));

create or replace function fn_boss_set_user_data(
  p_user_id uuid, p_total_ingelegd integer, p_opgehaald integer, p_legacy_zakjes integer,
  p_boss_pin_hash text, p_set_by text
)
returns users
language plpgsql security definer set search_path = public as $$
declare v_ok boolean; v_before users; v_after users; v_note text;
begin
  select exists(select 1 from admin_config where id = true and boss_pin_hash = p_boss_pin_hash) into v_ok;
  if not v_ok then raise exception 'ONJUISTE_BOSSCODE'; end if;
  if p_total_ingelegd is null or p_total_ingelegd < 0 then raise exception 'ONGELDIG_AANTAL'; end if;
  if p_opgehaald is null or p_opgehaald < 0 then raise exception 'ONGELDIG_AANTAL'; end if;
  if p_legacy_zakjes is null or p_legacy_zakjes < 0 then raise exception 'ONGELDIG_AANTAL'; end if;

  select * into v_before from users where id = p_user_id for update;
  if v_before.id is null then raise exception 'GEBRUIKER_NIET_GEVONDEN'; end if;

  update users set total_ingelegd = p_total_ingelegd, opgehaald = p_opgehaald, legacy_zakjes = p_legacy_zakjes
    where id = p_user_id returning * into v_after;

  v_note := format('ingelegd %s→%s, opgehaald %s→%s, legacy %s→%s%s',
    v_before.total_ingelegd, v_after.total_ingelegd,
    v_before.opgehaald, v_after.opgehaald,
    v_before.legacy_zakjes, v_after.legacy_zakjes,
    case when p_set_by is not null then ' (door ' || p_set_by || ')' else '' end);

  insert into loods_log(type, user_id, user_name, amount, note)
    values ('correctie', v_after.id, v_after.name, 0, v_note);

  return v_after;
end; $$;
grant execute on function fn_boss_set_user_data(uuid, integer, integer, integer, text, text) to anon, authenticated;

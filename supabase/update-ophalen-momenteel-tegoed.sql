-- ============================================================
-- Wietloods — update: ophalen mag niet meer dan wat de wachtrij al écht
-- verwerkt heeft
--
-- Tot nu toe kon je je volledige instant-toegekende tegoed ophalen, ook al
-- was dat deel van je inleg nog niet door de wachtrij verwerkt (nog
-- fysiek in de loods lag te wachten). Nu wordt ook gecontroleerd tegen
-- p_max_tegoed — het "momenteel tegoed" (wachtrij-verwerkt min opgehaald),
-- door de client berekend via dezelfde wachtrij-simulatie als de website
-- zelf gebruikt. Zoals de rest van deze app is dit een vertrouwens-check
-- (de client levert het getal aan, niet apart geverifieerd in SQL, want de
-- volledige FIFO/restart-simulatie zit enkel in JavaScript) — consistent met
-- het bestaande, lichte beveiligingsniveau van de app.
--
-- Voer dit EENMALIG uit in de Supabase SQL Editor.
-- ============================================================

-- oude 2-parameter-versie expliciet weg, anders zou een verouderde
-- (gecachete) browser-versie die zonder p_max_tegoed aanroept per ongeluk
-- de controle nog kunnen omzeilen
drop function if exists fn_register_ophalen(uuid, integer);

create or replace function fn_register_ophalen(p_user_id uuid, p_amount integer, p_max_tegoed integer)
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
  if p_max_tegoed is not null and p_amount > p_max_tegoed then raise exception 'NOG_NIET_VERWERKT'; end if;
  update users set opgehaald = opgehaald + p_amount
    where id = p_user_id returning * into v_user;
  insert into loods_log(type, user_id, user_name, amount, tegoed_after)
    values ('ophalen', v_user.id, v_user.name, p_amount, v_zakjes - v_user.opgehaald)
    returning * into v_log;
  return v_log;
end; $$;
grant execute on function fn_register_ophalen(uuid, integer, integer) to anon, authenticated;

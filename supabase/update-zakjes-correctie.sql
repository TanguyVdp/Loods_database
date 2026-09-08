-- ============================================================
-- Wietloods — update: zakjes-in-loods apart kalibreerbaar
-- Tot nu toe werd "zakjes in loods" enkel afgeleid uit de planten-kalibratie
-- (Werkelijke voorraad nu) — dat klopt de verwerkte-planten-telling recht,
-- maar niet noodzakelijk het aantal reeds klaarliggende ZAKJES (dat hangt
-- ook af van hoe nauwkeurig batch_size/batch_minutes het echte verwerkings-
-- tempo volgen, en drift daar stapelt op in de tijd).
--
-- Deze update voegt zakjes_correctie toe aan loods_baseline: een aparte,
-- onafhankelijke verschuiving die gewoon bovenop de modelberekening van
-- "zakjes in loods" wordt opgeteld. Bob (Boss menu) kan nu ook "Werkelijke
-- zakjes in loods nu" invullen; de site berekent zelf het verschil met wat
-- het model (na de planten-kalibratie) voorspelt, en onthoudt dat verschil
-- als correctie. De planten-kalibratie zelf blijft ongewijzigd werken.
-- Voer dit EENMALIG uit in de Supabase SQL Editor (New query > plak > Run),
-- na de vorige updates.
-- ============================================================

alter table loods_baseline add column if not exists zakjes_correctie integer not null default 0;

drop function if exists fn_set_loods_baseline(integer, integer, integer, text, text);

create or replace function fn_set_loods_baseline(
  p_offset_minutes integer, p_batch_size integer, p_batch_minutes integer,
  p_zakjes_correctie integer, p_boss_pin_hash text, p_set_by text
)
returns loods_baseline
language plpgsql security definer set search_path = public as $$
declare v_ok boolean; v_row loods_baseline;
begin
  select exists(select 1 from admin_config where id = true and boss_pin_hash = p_boss_pin_hash) into v_ok;
  if not v_ok then raise exception 'ONJUISTE_BOSSCODE'; end if;
  if p_offset_minutes is null then raise exception 'ONGELDIG_AANTAL'; end if;
  if p_batch_size is null or p_batch_size <= 0 then raise exception 'ONGELDIGE_BATCH'; end if;
  if p_batch_minutes is null or p_batch_minutes <= 0 then raise exception 'ONGELDIGE_BATCH'; end if;
  if p_zakjes_correctie is null then raise exception 'ONGELDIG_AANTAL'; end if;

  update loods_baseline set offset_minutes = p_offset_minutes, batch_size = p_batch_size, batch_minutes = p_batch_minutes,
    zakjes_correctie = p_zakjes_correctie, set_at = now(), set_by = p_set_by
    where id = true returning * into v_row;
  return v_row;
end; $$;
grant execute on function fn_set_loods_baseline(integer, integer, integer, integer, text, text) to anon, authenticated;

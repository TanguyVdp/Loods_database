-- ============================================================
-- Wietloods — DATA RESET (profielen en codes blijven staan)
-- Inclusief loods-upgrade: verwerkingssnelheid naar 5 zakjes / 1 minuut
-- (was 5 zakjes / 2 minuten) — dus 10 planten per minuut. Ratio blijft
-- ongewijzigd op 2 planten : 1 zakje.
-- ============================================================
-- LET OP — DIT KAN NIET ONGEDAAN GEMAAKT WORDEN:
--   - het volledige logboek wordt verwijderd (inleg/ophalen/correcties)
--   - alle klanten + hun leveringsgeschiedenis worden verwijderd
--   - ieders Ingelegd, Opgehaald en Legacy zakjes gaan terug naar 0
--   - de wachtrij-instellingen (kalibratie, pauze, ratio-cutover,
--     zakjes-correctie) gaan terug naar 0/ontgrendeld, en de snelheid wordt
--     op de NIEUWE upgrade-snelheid gezet: 5 zakjes / 1 minuut
--
-- Blijft WEL ongewijzigd staan:
--   - alle profielen zelf: naam, pincode, profielfoto, volgorde, Discord-ID
--   - de bosscode (admin_config)
--
-- Voer dit pas uit als je 100% zeker bent. Supabase SQL Editor > New query
-- > plak > Run.
-- ============================================================

-- defensief: deze kolommen bestaan enkel als de bijhorende update-SQL al
-- gerund is — hier toevoegen (indien nog niet aanwezig) zodat de update
-- eronder altijd werkt, ook als die migratie nog niet gebeurd is.
alter table loods_baseline add column if not exists ratio_cutover_at timestamptz;
alter table loods_baseline add column if not exists zakjes_correctie integer not null default 0;
alter table users add column if not exists legacy_zakjes integer not null default 0;

delete from customer_log;
delete from customers;
delete from loods_log;

update users set total_ingelegd = 0, opgehaald = 0, legacy_zakjes = 0;

update loods_baseline set
  batch_size = 5, batch_minutes = 1, offset_minutes = 0,
  paused = false, paused_at = null, ratio_cutover_at = null,
  zakjes_correctie = 0, set_by = null, set_at = now()
where id = true;

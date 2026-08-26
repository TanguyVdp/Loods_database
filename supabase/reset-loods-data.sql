-- ============================================================
-- Wietloods — DATA RESET (profielen en codes blijven staan)
-- ============================================================
-- LET OP — DIT KAN NIET ONGEDAAN GEMAAKT WORDEN:
--   - het volledige logboek wordt verwijderd (inleg/ophalen/correcties)
--   - alle klanten + hun leveringsgeschiedenis worden verwijderd
--   - ieders Ingelegd, Opgehaald en Legacy zakjes gaan terug naar 0
--   - de wachtrij-instellingen (snelheid, kalibratie, pauze, ratio-cutover)
--     gaan terug naar de standaardwaarden, ontgrendeld (niet gepauzeerd)
--
-- Blijft WEL ongewijzigd staan:
--   - alle profielen zelf: naam, pincode, profielfoto, volgorde, Discord-ID
--   - de bosscode (admin_config)
--
-- Voer dit pas uit als je 100% zeker bent. Supabase SQL Editor > New query
-- > plak > Run.
-- ============================================================

delete from customer_log;
delete from customers;
delete from loods_log;

update users set total_ingelegd = 0, opgehaald = 0, legacy_zakjes = 0;

update loods_baseline set
  batch_size = 3, batch_minutes = 3, offset_minutes = 0,
  paused = false, paused_at = null, ratio_cutover_at = null,
  set_by = null, set_at = now()
where id = true;

-- ============================================================
-- Wietloods — VOLLEDIGE RESET
-- ============================================================
-- LET OP — DIT KAN NIET ONGEDAAN GEMAAKT WORDEN:
--   - al het logboek (inleg/ophalen + klant-leveringen) wordt verwijderd
--   - alle klanten worden verwijderd
--   - ALLE profielen worden verwijderd (namen, foto's, codes, totalen)
--   - profielfoto's in Storage worden opgeruimd
-- Erna blijven enkel de 4 originele startprofielen over: siebe, ivar, bob,
-- matis — allemaal weer "nog vrij", iedereen claimt opnieuw met een code.
-- Je bosscode (admin_config) blijft ongewijzigd staan.
--
-- Voer dit pas uit als je 100% zeker bent. Supabase SQL Editor > New query
-- > plak > Run.
-- ============================================================

delete from customer_log;
delete from customers;
delete from loods_log;
delete from users;

delete from storage.objects where bucket_id = 'avatars';

insert into users (name) values ('siebe'), ('ivar'), ('bob'), ('matis');

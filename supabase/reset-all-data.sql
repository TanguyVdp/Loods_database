-- ============================================================
-- Wietloods — VOLLEDIGE RESET
-- ============================================================
-- LET OP — DIT KAN NIET ONGEDAAN GEMAAKT WORDEN:
--   - al het logboek (inleg/ophalen + klant-leveringen) wordt verwijderd
--   - alle klanten worden verwijderd
--   - ALLE profielen worden verwijderd (namen, foto's, codes, totalen)
-- Erna blijven enkel de 4 originele startprofielen over: siebe, ivar, bob,
-- matis — allemaal weer "nog vrij", iedereen claimt opnieuw met een code.
-- Je bosscode (admin_config) blijft ongewijzigd staan.
--
-- Oude profielfoto's in Storage worden NIET automatisch opgeruimd (Supabase
-- staat rechtstreekse verwijdering via SQL niet toe). Dat is onschadelijk —
-- ze blijven gewoon ongebruikt in de "avatars"-bucket staan. Wil je die ook
-- weg, ga dan naar Storage > avatars in het Supabase-dashboard en verwijder
-- de bestanden daar manueel (optioneel).
--
-- Voer dit pas uit als je 100% zeker bent. Supabase SQL Editor > New query
-- > plak > Run.
-- ============================================================

delete from customer_log;
delete from customers;
delete from loods_log;
delete from users;

insert into users (name) values ('siebe'), ('ivar'), ('bob'), ('matis');

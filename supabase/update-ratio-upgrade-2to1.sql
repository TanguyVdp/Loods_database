-- ============================================================
-- Wietloods — loods-upgrade: ratio 3:1 -> 2:1 + snellere verwerking (v2)
--
-- Cutover-moment: 26/08 17u42 Belgische tijd (15u42 UTC) — alles wat toen al
-- door de wachtrij verwerkt was blijft voorgoed aan de oude 3:1-ratio
-- vastliggen ("legacy_zakjes"). Alles wat toen nog niet verwerkt was — ook
-- een deposit die net op dat moment gedeeltelijk in verwerking was — schuift
-- vanaf nu naar de nieuwe 2:1-ratio, aan de nieuwe snelheid (5 zakjes/2 min
-- i.p.v. 3 zakjes/3 min).
--
-- Nieuw t.o.v. de vorige (teruggedraaide) poging: ratio_cutover_at wordt nu
-- ook opgeslagen, zodat de site en de Discord-bot voortaan zelf het
-- legacy-deel uit de wachtrij-simulatie filteren (buildPostCutoverLog) i.p.v.
-- de hele geschiedenis blindweg aan de nieuwe snelheid te herrekenen — dat
-- was de kern van de vorige mislukking.
--
-- De site blijft na deze SQL nog gewoon GEPAUZEERD. Niemand kan intussen
-- iets aanpassen. Voer dit EENMALIG uit in de Supabase SQL Editor.
-- ============================================================

-- ============== KOLOMMEN ==============

alter table users add column if not exists legacy_zakjes integer not null default 0;
alter table loods_baseline add column if not exists ratio_cutover_at timestamptz;

-- ============== SNAPSHOT (26/08 17u42 Belgische tijd) ==============

update users set legacy_zakjes = 1200 where id = '770d266a-abb8-4737-ba1c-7165d982a132'; -- sem karton
update users set legacy_zakjes = 733  where id = '6c25f3bc-d15e-461d-89bf-1f8107bb6e53'; -- Henk G
update users set legacy_zakjes = 378  where id = '9ba8a819-94bc-4d58-8969-48043ec20561'; -- Bennie Helder
update users set legacy_zakjes = 200  where id = '98d068f7-a64d-4576-b251-e31b16954158'; -- Mike Tyson
update users set legacy_zakjes = 0    where id = '81792389-b446-4123-8f51-8d57af5b3df8'; -- ivar S
update users set legacy_zakjes = 0    where id = '7a034901-0924-417e-b30f-6934e8d75023'; -- KDR
update users set legacy_zakjes = 6    where id = '31f0b50e-e0a7-41fd-818a-d9f2b8953b74'; -- Bennie Honderd
update users set legacy_zakjes = 133  where id = '59c1b932-5581-4981-bc5f-c1f8d247b68c'; -- Schoppe
update users set legacy_zakjes = 26   where id = '4d21f468-a74c-4d8f-925f-2273ddae98db'; -- Bob V.
update users set legacy_zakjes = 0    where id = '9e7abdc6-558c-4788-983b-8533923158d0'; -- siebe

-- ============== VIEW: legacy_zakjes mee tonen ==============

create or replace view users_public as
  select id, name, total_ingelegd, opgehaald, created_at, (pin_hash is not null) as claimed, avatar_url, sort_order, discord_id, legacy_zakjes
  from users;

-- ============== FUNCTIES: gesplitste ratio-formule ==============

create or replace function fn_register_inleg(p_user_id uuid, p_amount integer)
returns loods_log
language plpgsql security definer set search_path = public as $$
declare v_before int; v_after int; v_user users; v_log loods_log; v_rest int;
begin
  if p_amount is null or p_amount <= 0 then raise exception 'ONGELDIG_AANTAL'; end if;
  select * into v_user from users where id = p_user_id for update;
  if v_user.id is null then raise exception 'GEBRUIKER_NIET_GEVONDEN'; end if;
  v_rest := greatest(0, v_user.total_ingelegd - v_user.legacy_zakjes * 3);
  v_before := v_user.legacy_zakjes + floor(v_rest / 2.0);
  update users set total_ingelegd = total_ingelegd + p_amount
    where id = p_user_id returning * into v_user;
  v_rest := greatest(0, v_user.total_ingelegd - v_user.legacy_zakjes * 3);
  v_after := v_user.legacy_zakjes + floor(v_rest / 2.0);
  insert into loods_log(type, user_id, user_name, amount, cumulative_after, zakjes_after, zakjes_delta)
    values ('inleg', v_user.id, v_user.name, p_amount, v_user.total_ingelegd, v_after, v_after - v_before)
    returning * into v_log;
  return v_log;
end; $$;

create or replace function fn_register_ophalen(p_user_id uuid, p_amount integer)
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
  update users set opgehaald = opgehaald + p_amount
    where id = p_user_id returning * into v_user;
  insert into loods_log(type, user_id, user_name, amount, tegoed_after)
    values ('ophalen', v_user.id, v_user.name, p_amount, v_zakjes - v_user.opgehaald)
    returning * into v_log;
  return v_log;
end; $$;

-- ============== NIEUWE VERWERKINGSSNELHEID + CUTOVER-MOMENT ==============

update loods_baseline
  set batch_size = 5, batch_minutes = 2, offset_minutes = 0,
      ratio_cutover_at = '2026-08-26T15:42:00+00:00'
  where id = true;

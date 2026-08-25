-- ============================================================
-- Wietloods — update: Discord-koppeling per profiel (Boss menu)
-- Voegt een discord_id kolom toe aan users, zodat een periodieke check
-- (GitHub Actions, zie .github/workflows/discord-notify.yml) een Discord-
-- bericht met @mention kan sturen wanneer iemands zakjes klaar zijn.
-- Voer dit EENMALIG uit in de Supabase SQL Editor (New query > plak > Run),
-- na de vorige updates.
-- ============================================================

-- ============== KOLOM ==============

alter table users add column if not exists discord_id text;

-- users_public opnieuw aanmaken mét discord_id (niet gevoelig, mag mee —
-- alle overige kolommen exact zoals in update-sort-order.sql / update-avatars.sql)
create or replace view users_public as
  select id, name, total_ingelegd, opgehaald, created_at, (pin_hash is not null) as claimed, avatar_url, sort_order, discord_id
  from users;

-- ============== BOSS: DISCORD-ID KOPPELEN ==============
-- Enkel de boss mag dit instellen. p_discord_id mag leeg/null zijn om de
-- koppeling weer te verwijderen.

create or replace function fn_boss_set_discord_id(p_user_id uuid, p_discord_id text, p_boss_pin_hash text)
returns users
language plpgsql security definer set search_path = public as $$
declare v_ok boolean; v_user users;
begin
  select exists(select 1 from admin_config where id = true and boss_pin_hash = p_boss_pin_hash) into v_ok;
  if not v_ok then raise exception 'ONJUISTE_BOSSCODE'; end if;
  update users set discord_id = nullif(trim(coalesce(p_discord_id, '')), '')
    where id = p_user_id returning * into v_user;
  if v_user.id is null then raise exception 'GEBRUIKER_NIET_GEVONDEN'; end if;
  return v_user;
end; $$;
grant execute on function fn_boss_set_discord_id(uuid, text, text) to anon, authenticated;

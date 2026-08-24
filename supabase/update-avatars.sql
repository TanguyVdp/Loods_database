-- ============================================================
-- Wietloods — update: profielfoto's
-- Voer dit EENMALIG uit in de Supabase SQL Editor (New query > plak > Run),
-- na de vorige updates (schema.sql, update-boss-menu.sql, update-delete-profile.sql).
-- ============================================================

-- ============== KOLOM ==============

alter table users add column if not exists avatar_url text;

create or replace view users_public as
  select id, name, total_ingelegd, opgehaald, created_at, (pin_hash is not null) as claimed, avatar_url
  from users;

-- ============== STORAGE BUCKET ==============
-- Publieke bucket voor profielfoto's (klein, alleen leesbaar via url — geen
-- gevoelige info). Iedereen met de anon key mag uploaden/overschrijven,
-- zelfde vertrouwensmodel als de rest van de app (geen zware beveiliging,
-- enkel bedoeld om vergissingen te vermijden binnen de groep van 25).

insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

drop policy if exists "avatars upload" on storage.objects;
create policy "avatars upload" on storage.objects for insert to anon, authenticated
  with check (bucket_id = 'avatars');

drop policy if exists "avatars update" on storage.objects;
create policy "avatars update" on storage.objects for update to anon, authenticated
  using (bucket_id = 'avatars');

drop policy if exists "avatars read" on storage.objects;
create policy "avatars read" on storage.objects for select to anon, authenticated
  using (bucket_id = 'avatars');

-- ============== FUNCTIE ==============

create or replace function fn_set_avatar(p_user_id uuid, p_avatar_url text)
returns users
language plpgsql security definer set search_path = public as $$
declare v_user users;
begin
  if p_user_id is null then raise exception 'GEBRUIKER_NIET_GEVONDEN'; end if;
  update users set avatar_url = p_avatar_url where id = p_user_id returning * into v_user;
  if v_user.id is null then raise exception 'GEBRUIKER_NIET_GEVONDEN'; end if;
  return v_user;
end; $$;

grant execute on function fn_set_avatar(uuid, text) to anon, authenticated;

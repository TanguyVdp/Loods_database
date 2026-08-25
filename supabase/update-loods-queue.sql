-- ============================================================
-- Wietloods — update: verwerkingswachtrij + kalibratie (Boss menu)
-- Voegt de "Verwerkingswachtrij" toe aan de Loods-pagina en de kalibratie-
-- kaart aan het Boss menu. Voer dit EENMALIG uit in de Supabase SQL Editor.
-- Veilig om opnieuw te runnen (create/alter "if not exists", "create or replace").
-- ============================================================

create table if not exists loods_baseline (
  id boolean primary key default true,
  value integer not null default 0,
  batch_size integer not null default 3,
  batch_minutes integer not null default 3,
  set_at timestamptz not null default now(),
  set_by text,
  constraint loods_baseline_singleton check (id)
);
insert into loods_baseline (id, value, batch_size, batch_minutes, set_at) values (true, 0, 3, 3, now())
  on conflict (id) do nothing;

alter table loods_baseline enable row level security;
drop policy if exists "select loods_baseline" on loods_baseline;
create policy "select loods_baseline" on loods_baseline for select using (true);
grant select on loods_baseline to anon, authenticated;

-- Enkel de boss mag kalibreren — zelfde bosscode-controle als de andere
-- Boss-menu-acties (profiel resetten/verwijderen/herschikken).
create or replace function fn_set_loods_baseline(p_value integer, p_batch_size integer, p_batch_minutes integer, p_boss_pin_hash text, p_set_by text)
returns loods_baseline
language plpgsql security definer set search_path = public as $$
declare v_ok boolean; v_row loods_baseline;
begin
  select exists(select 1 from admin_config where id = true and boss_pin_hash = p_boss_pin_hash) into v_ok;
  if not v_ok then raise exception 'ONJUISTE_BOSSCODE'; end if;
  if p_value is null or p_value < 0 then raise exception 'ONGELDIG_AANTAL'; end if;
  if p_batch_size is null or p_batch_size <= 0 then raise exception 'ONGELDIGE_BATCH'; end if;
  if p_batch_minutes is null or p_batch_minutes <= 0 then raise exception 'ONGELDIGE_BATCH'; end if;
  update loods_baseline set value = p_value, batch_size = p_batch_size, batch_minutes = p_batch_minutes,
    set_at = now(), set_by = p_set_by
    where id = true returning * into v_row;
  return v_row;
end; $$;
grant execute on function fn_set_loods_baseline(integer, integer, integer, text, text) to anon, authenticated;

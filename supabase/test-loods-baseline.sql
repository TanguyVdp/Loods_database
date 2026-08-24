-- ============================================================
-- Wietloods — TEST: kalibratiepunt voor 'planten nog in loods'
-- Enkel nodig voor de test-wachtrij (test/index.html). Voer dit uit in de
-- Supabase SQL Editor als je de wachtrij-test wil proberen.
-- ============================================================

create table if not exists loods_baseline (
  id boolean primary key default true,
  value integer not null default 0,
  set_at timestamptz not null default now(),
  set_by text,
  constraint loods_baseline_singleton check (id)
);
insert into loods_baseline (id, value, set_at) values (true, 0, now())
  on conflict (id) do nothing;

alter table loods_baseline enable row level security;
drop policy if exists "select loods_baseline" on loods_baseline;
create policy "select loods_baseline" on loods_baseline for select using (true);
grant select on loods_baseline to anon, authenticated;

create or replace function fn_set_loods_baseline(p_value integer, p_set_by text)
returns loods_baseline
language plpgsql security definer set search_path = public as $$
declare v_row loods_baseline;
begin
  if p_value is null or p_value < 0 then raise exception 'ONGELDIG_AANTAL'; end if;
  update loods_baseline set value = p_value, set_at = now(), set_by = p_set_by
    where id = true returning * into v_row;
  return v_row;
end; $$;
grant execute on function fn_set_loods_baseline(integer, text) to anon, authenticated;

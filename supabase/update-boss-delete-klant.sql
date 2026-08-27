-- ============================================================
-- Wietloods — update: klanten verwijderen vanuit Boss menu
--
-- Zelfde patroon als profielen verwijderen: de klant zelf verdwijnt, maar
-- de leverings-/verkoopgeschiedenis (customer_log) blijft gewoon bewaard —
-- die toont dan "verwijderde klant" i.p.v. de naam (de site ondersteunt dat
-- al langer als fallback). Daarvoor moet de FK van customer_log naar
-- customers van "on delete cascade" naar "on delete set null".
--
-- Voer dit EENMALIG uit in de Supabase SQL Editor (New query > plak > Run).
-- ============================================================

alter table customer_log alter column customer_id drop not null;
alter table customer_log drop constraint if exists customer_log_customer_id_fkey;
alter table customer_log add constraint customer_log_customer_id_fkey
  foreign key (customer_id) references customers(id) on delete set null;

create or replace function fn_boss_delete_klant(p_customer_id uuid, p_boss_pin_hash text)
returns boolean
language plpgsql security definer set search_path = public as $$
declare v_ok boolean;
begin
  select exists(select 1 from admin_config where id = true and boss_pin_hash = p_boss_pin_hash) into v_ok;
  if not v_ok then raise exception 'ONJUISTE_BOSSCODE'; end if;
  delete from customers where id = p_customer_id;
  if not found then raise exception 'KLANT_NIET_GEVONDEN'; end if;
  return true;
end; $$;
grant execute on function fn_boss_delete_klant(uuid, text) to anon, authenticated;

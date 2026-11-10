-- DIGITALCOREVISION 2.0 - Data Leads
-- Jalankan sekali di Supabase SQL Editor pada project digitalcorevision-2.

create table if not exists public.leads (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  full_name text not null check (char_length(trim(full_name)) between 1 and 120),
  phone text,
  email text,
  source text,
  status text not null default 'baru'
    check (status in ('baru', 'dihubungi', 'follow_up', 'tertarik', 'closing', 'tidak_tertarik')),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists leads_owner_created_idx
  on public.leads (owner_id, created_at desc);

alter table public.leads enable row level security;

drop policy if exists leads_select_owner_or_super_admin on public.leads;
create policy leads_select_owner_or_super_admin
on public.leads for select to authenticated
using (owner_id = (select auth.uid()) or public.is_super_admin());

drop policy if exists leads_insert_owner on public.leads;
create policy leads_insert_owner
on public.leads for insert to authenticated
with check (owner_id = (select auth.uid()));

drop policy if exists leads_update_owner_or_super_admin on public.leads;
create policy leads_update_owner_or_super_admin
on public.leads for update to authenticated
using (owner_id = (select auth.uid()) or public.is_super_admin())
with check (owner_id = (select auth.uid()) or public.is_super_admin());

drop policy if exists leads_delete_owner_or_super_admin on public.leads;
create policy leads_delete_owner_or_super_admin
on public.leads for delete to authenticated
using (owner_id = (select auth.uid()) or public.is_super_admin());

grant select, insert, update, delete on public.leads to authenticated;

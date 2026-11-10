-- DIGITALCOREVISION 2.0 - Riwayat Aktivitas Prospek
create table if not exists public.lead_activities (
  id uuid primary key default gen_random_uuid(),
  lead_id uuid not null references public.leads(id) on delete cascade,
  owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  activity_type text not null,
  description text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists lead_activities_lead_created_idx
  on public.lead_activities (lead_id, created_at desc);
create index if not exists lead_activities_owner_created_idx
  on public.lead_activities (owner_id, created_at desc);

alter table public.lead_activities enable row level security;

drop policy if exists lead_activities_select_owner_or_super_admin on public.lead_activities;
create policy lead_activities_select_owner_or_super_admin
on public.lead_activities for select to authenticated
using (owner_id = (select auth.uid()) or public.is_super_admin());

drop policy if exists lead_activities_insert_owner on public.lead_activities;
create policy lead_activities_insert_owner
on public.lead_activities for insert to authenticated
with check (
  owner_id = (select auth.uid())
  and exists (
    select 1 from public.leads l
    where l.id = lead_id and l.owner_id = (select auth.uid())
  )
);

grant select, insert on public.lead_activities to authenticated;

-- Backfill: catat prospek yang sudah ada sebelum fitur riwayat dipasang.
insert into public.lead_activities (lead_id, owner_id, activity_type, description, created_at)
select l.id, l.owner_id, 'created', 'Prospek sudah tercatat sebelum fitur riwayat aktivitas diaktifkan.', l.created_at
from public.leads l
where not exists (
  select 1 from public.lead_activities a
  where a.lead_id = l.id and a.activity_type = 'created'
);

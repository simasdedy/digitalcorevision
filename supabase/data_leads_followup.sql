-- DIGITALCOREVISION 2.0 - Follow-up reminder for Data Leads
-- Jalankan sekali di Supabase SQL Editor.

alter table public.leads
  add column if not exists follow_up_at timestamptz;

create index if not exists leads_owner_follow_up_idx
  on public.leads (owner_id, follow_up_at)
  where follow_up_at is not null;

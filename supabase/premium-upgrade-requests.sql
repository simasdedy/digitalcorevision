-- DIGITALCOREVISION 2.0
-- Secure request inbox for Free Members who want to upgrade to Premium.
-- Run this script in Supabase SQL Editor.

create table if not exists public.premium_upgrade_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  message text check (message is null or char_length(message) <= 500),
  status text not null default 'pending'
    check (status in ('pending', 'contacted', 'approved', 'rejected')),
  requested_at timestamptz not null default now(),
  reviewed_at timestamptz,
  admin_note text,
  constraint premium_upgrade_requests_user_required check (user_id is not null)
);

create index if not exists premium_upgrade_requests_requested_at_idx
  on public.premium_upgrade_requests (requested_at desc);
create index if not exists premium_upgrade_requests_user_idx
  on public.premium_upgrade_requests (user_id, requested_at desc);
create unique index if not exists premium_upgrade_requests_one_pending_per_user
  on public.premium_upgrade_requests (user_id) where status = 'pending';

alter table public.premium_upgrade_requests enable row level security;

drop policy if exists premium_upgrade_requests_select_own_or_admin on public.premium_upgrade_requests;
create policy premium_upgrade_requests_select_own_or_admin
  on public.premium_upgrade_requests for select to authenticated
  using (user_id = (select auth.uid()) or exists (
    select 1 from public.super_admins sa where sa.user_id = (select auth.uid())
  ));

drop policy if exists premium_upgrade_requests_insert_own_pending on public.premium_upgrade_requests;
create policy premium_upgrade_requests_insert_own_pending
  on public.premium_upgrade_requests for insert to authenticated
  with check (
    user_id = (select auth.uid()) and status = 'pending'
    and reviewed_at is null and admin_note is null
  );

drop policy if exists premium_upgrade_requests_update_super_admin on public.premium_upgrade_requests;
create policy premium_upgrade_requests_update_super_admin
  on public.premium_upgrade_requests for update to authenticated
  using (exists (select 1 from public.super_admins sa where sa.user_id = (select auth.uid())))
  with check (exists (select 1 from public.super_admins sa where sa.user_id = (select auth.uid())));

grant select, insert on public.premium_upgrade_requests to authenticated;
grant update (status, reviewed_at, admin_note) on public.premium_upgrade_requests to authenticated;

-- This workflow records upgrade requests only. It does not collect payments
-- and does not activate Premium. Super Admin must verify payment and use the
-- existing activation workflow. Premium membership duration is 30 days.

-- DIGITALCOREVISION 2.0
-- Enforce Premium access for CRM and referral tools at the database layer.
-- Run AFTER data_leads.sql and lead_activities.sql.
-- This complements the client-side feature preview; UI hiding alone is not security.

create or replace function public.is_my_premium_active()
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select exists (
    select 1
    from public.member_memberships mm
    where mm.member_id = (select auth.uid())
      and mm.membership_type = 'premium'
      and mm.premium_expires_at is not null
      and mm.premium_expires_at > now()
  );
$$;

revoke all on function public.is_my_premium_active() from public, anon;
grant execute on function public.is_my_premium_active() to authenticated;

-- Leads: retain each owner's isolation and Super Admin access,
-- but require an active Premium membership for member-level CRUD.
drop policy if exists leads_select_owner_or_super_admin on public.leads;
create policy leads_select_premium_owner_or_super_admin
on public.leads for select to authenticated
using (
  (owner_id = (select auth.uid()) and public.is_my_premium_active())
  or public.is_super_admin()
);

drop policy if exists leads_insert_owner on public.leads;
create policy leads_insert_premium_owner
on public.leads for insert to authenticated
with check (owner_id = (select auth.uid()) and public.is_my_premium_active());

drop policy if exists leads_update_owner_or_super_admin on public.leads;
create policy leads_update_premium_owner_or_super_admin
on public.leads for update to authenticated
using (
  (owner_id = (select auth.uid()) and public.is_my_premium_active())
  or public.is_super_admin()
)
with check (
  (owner_id = (select auth.uid()) and public.is_my_premium_active())
  or public.is_super_admin()
);

drop policy if exists leads_delete_owner_or_super_admin on public.leads;
create policy leads_delete_premium_owner_or_super_admin
on public.leads for delete to authenticated
using (
  (owner_id = (select auth.uid()) and public.is_my_premium_active())
  or public.is_super_admin()
);

-- Lead activity history: require Premium for members; preserve Super Admin read access.
drop policy if exists lead_activities_select_owner_or_super_admin on public.lead_activities;
create policy lead_activities_select_premium_owner_or_super_admin
on public.lead_activities for select to authenticated
using (
  (owner_id = (select auth.uid()) and public.is_my_premium_active())
  or public.is_super_admin()
);

drop policy if exists lead_activities_insert_owner on public.lead_activities;
create policy lead_activities_insert_premium_owner
on public.lead_activities for insert to authenticated
with check (
  owner_id = (select auth.uid())
  and public.is_my_premium_active()
  and exists (
    select 1 from public.leads l
    where l.id = lead_id and l.owner_id = (select auth.uid())
  )
);

-- Restrictive policies layer on top of existing policies without replacing
-- referral-registration permissions. Referral relationships remain stored.
drop policy if exists member_referral_codes_premium_access_gate on public.member_referral_codes;
create policy member_referral_codes_premium_access_gate
on public.member_referral_codes as restrictive
for all to authenticated
using (public.is_my_premium_active() or public.is_super_admin())
with check (public.is_my_premium_active() or public.is_super_admin());

drop policy if exists member_referrals_premium_read_gate on public.member_referrals;
create policy member_referrals_premium_read_gate
on public.member_referrals as restrictive
for select to authenticated
using (public.is_my_premium_active() or public.is_super_admin());

-- Existing referral relationships are never deleted by this migration.
-- Expired members keep their historical sponsor/referral relationship.

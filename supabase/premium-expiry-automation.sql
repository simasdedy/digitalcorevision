-- DIGITALCOREVISION 2.0
-- Premium expiry handling: keep membership history and sponsor relationships intact.
-- This script DOES NOT delete referral relationships or rewrite membership_history.
-- It keeps membership_type='premium' and premium_expires_at as the audit source;
-- the effective member access is Free whenever premium_expires_at <= now().

-- 1) Server-side helper for policies / RPCs that need to verify the current member.
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

-- 2) Scheduled task body: deactivate only the expired member's referral CODE.
-- Referral relationships already recorded in member_referrals are never changed.
-- activate_member_premium() already reactivates the member's referral code on renewal.
create or replace function public.deactivate_expired_premium_referral_codes()
returns integer
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_updated integer := 0;
begin
  update public.member_referral_codes rc
     set is_active = false
   where rc.is_active = true
     and exists (
       select 1
       from public.member_memberships mm
       where mm.member_id = rc.user_id
         and mm.membership_type = 'premium'
         and mm.premium_expires_at is not null
         and mm.premium_expires_at <= now()
     );

  get diagnostics v_updated = row_count;
  return v_updated;
end;
$$;

revoke all on function public.deactivate_expired_premium_referral_codes() from public, anon, authenticated;

-- 3) OPTIONAL scheduler setup.
-- Enable pg_cron in Supabase Database > Extensions if it is not already enabled,
-- then run this block as the postgres role in the SQL Editor.
create extension if not exists pg_cron with schema pg_catalog;

do $$
declare
  v_job_id bigint;
begin
  select jobid into v_job_id
  from cron.job
  where jobname = 'dcv-expire-premium-referral-codes'
  limit 1;

  if v_job_id is not null then
    perform cron.unschedule(v_job_id);
  end if;

  perform cron.schedule(
    'dcv-expire-premium-referral-codes',
    '*/15 * * * *',
    $job$select public.deactivate_expired_premium_referral_codes();$job$
  );
end;
$$;

-- 4) Verify the current member's effective Premium access:
-- select public.is_my_premium_active();
--
-- Verify scheduler:
-- select jobname, schedule, active from cron.job
-- where jobname = 'dcv-expire-premium-referral-codes';
--
-- Verify expired referral codes processed:
-- select public.deactivate_expired_premium_referral_codes();

-- DIGITALCOREVISION 2.0
-- Permanent training certificates and public verification RPC.
-- Run this script once in Supabase SQL Editor (project: digitalcorevision-2).

create table if not exists public.training_certificates (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  certificate_number text not null unique,
  member_name text not null,
  course_title text not null default 'Training DIGITALCOREVISION 2.0',
  issued_at timestamptz not null default now(),
  completion_date date not null,
  status text not null default 'active' check (status in ('active', 'revoked')),
  created_at timestamptz not null default now(),
  unique (user_id)
);

create index if not exists training_certificates_number_idx
  on public.training_certificates (certificate_number);

alter table public.training_certificates enable row level security;

drop policy if exists "Members read own training certificate" on public.training_certificates;
create policy "Members read own training certificate"
  on public.training_certificates
  for select
  to authenticated
  using (
    user_id = auth.uid()
    or exists (
      select 1 from public.super_admins sa
      where sa.user_id = auth.uid()
    )
  );

-- No direct INSERT/UPDATE/DELETE policy is intentionally provided.
-- Issuance is handled by the security-definer RPC after checking completion.

create or replace function public.issue_training_certificate()
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_user_id uuid := auth.uid();
  v_name text;
  v_total integer;
  v_completed integer;
  v_completed_at timestamptz;
  v_certificate public.training_certificates%rowtype;
begin
  if v_user_id is null then
    raise exception 'Sesi login tidak ditemukan. Silakan login kembali.';
  end if;

  select nullif(trim(p.full_name), '')
    into v_name
    from public.profiles p
   where p.id = v_user_id;

  if v_name is null then
    raise exception 'Nama profil Member belum tersedia.';
  end if;

  select count(*)::integer
    into v_total
    from public.training_contents tc
   where tc.status = 'published';

  if v_total = 0 then
    raise exception 'Belum ada materi training yang dipublikasikan.';
  end if;

  select count(distinct tp.training_content_id)::integer,
         max(tp.completed_at)
    into v_completed, v_completed_at
    from public.training_progress tp
    join public.training_contents tc
      on tc.id = tp.training_content_id
   where tp.user_id = v_user_id
     and tp.is_completed = true
     and tc.status = 'published';

  if v_completed <> v_total then
    raise exception 'Selesaikan seluruh materi training sebelum menerbitkan sertifikat.';
  end if;

  insert into public.training_certificates (
    user_id, certificate_number, member_name, course_title, completion_date
  )
  values (
    v_user_id,
    'DCV-TR-' || to_char(coalesce(v_completed_at, now()), 'YYYY') || '-' ||
      upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 12)),
    v_name,
    'Training DIGITALCOREVISION 2.0',
    coalesce(v_completed_at::date, current_date)
  )
  on conflict (user_id) do nothing;

  select *
    into v_certificate
    from public.training_certificates
   where user_id = v_user_id;

  return jsonb_build_object(
    'certificate_number', v_certificate.certificate_number,
    'member_name', v_certificate.member_name,
    'course_title', v_certificate.course_title,
    'issued_at', v_certificate.issued_at,
    'completion_date', v_certificate.completion_date,
    'status', v_certificate.status
  );
end;
$$;

create or replace function public.verify_training_certificate(p_certificate_number text)
returns table (
  certificate_number text,
  member_name text,
  course_title text,
  issued_at timestamptz,
  completion_date date,
  verification_status text
)
language sql
security definer
set search_path = public
as $$
  select
    c.certificate_number,
    c.member_name,
    c.course_title,
    c.issued_at,
    c.completion_date,
    case when c.status = 'active' then 'VALID' else 'REVOKED' end
  from public.training_certificates c
  where upper(c.certificate_number) = upper(trim(p_certificate_number))
  limit 1;
$$;

revoke all on function public.issue_training_certificate() from public;
grant execute on function public.issue_training_certificate() to authenticated;

revoke all on function public.verify_training_certificate(text) from public;
grant execute on function public.verify_training_certificate(text) to anon, authenticated;

grant select on public.training_certificates to authenticated;

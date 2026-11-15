-- DIGITALCOREVISION 2.0 · Webinar Manager
-- Jalankan sekali di Supabase SQL Editor.
-- Webinar dikelola Super Admin dan jadwal published dapat dilihat semua Member.

CREATE TABLE IF NOT EXISTS public.webinars (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL CHECK (char_length(trim(title)) BETWEEN 3 AND 180),
    description TEXT,
    starts_at TIMESTAMPTZ NOT NULL,
    ends_at TIMESTAMPTZ,
    meeting_url TEXT,
    status TEXT NOT NULL DEFAULT 'draft'
        CHECK (status IN ('draft', 'published', 'cancelled')),
    created_by UUID REFERENCES public.profiles(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT webinars_end_after_start
        CHECK (ends_at IS NULL OR ends_at > starts_at)
);

CREATE TABLE IF NOT EXISTS public.webinar_registrations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    webinar_id UUID NOT NULL REFERENCES public.webinars(id) ON DELETE RESTRICT,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
    status TEXT NOT NULL DEFAULT 'registered'
        CHECK (status IN ('registered', 'attended', 'cancelled', 'no_show')),
    registered_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    attended_at TIMESTAMPTZ,
    checked_by UUID REFERENCES public.profiles(id) ON DELETE RESTRICT,
    UNIQUE (webinar_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_webinars_status_starts_at
    ON public.webinars (status, starts_at);
CREATE INDEX IF NOT EXISTS idx_webinar_registrations_webinar
    ON public.webinar_registrations (webinar_id, registered_at DESC);
CREATE INDEX IF NOT EXISTS idx_webinar_registrations_user
    ON public.webinar_registrations (user_id, registered_at DESC);

ALTER TABLE public.webinars ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.webinar_registrations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS webinars_member_read_published ON public.webinars;
CREATE POLICY webinars_member_read_published
ON public.webinars FOR SELECT TO authenticated
USING (status = 'published' OR public.is_super_admin());

DROP POLICY IF EXISTS webinars_admin_insert ON public.webinars;
CREATE POLICY webinars_admin_insert
ON public.webinars FOR INSERT TO authenticated
WITH CHECK (public.is_super_admin());

DROP POLICY IF EXISTS webinars_admin_update ON public.webinars;
CREATE POLICY webinars_admin_update
ON public.webinars FOR UPDATE TO authenticated
USING (public.is_super_admin())
WITH CHECK (public.is_super_admin());

DROP POLICY IF EXISTS webinars_admin_delete ON public.webinars;
CREATE POLICY webinars_admin_delete
ON public.webinars FOR DELETE TO authenticated
USING (public.is_super_admin());

DROP POLICY IF EXISTS webinar_registrations_member_read_own ON public.webinar_registrations;
CREATE POLICY webinar_registrations_member_read_own
ON public.webinar_registrations FOR SELECT TO authenticated
USING (user_id = auth.uid() OR public.is_super_admin());

DROP POLICY IF EXISTS webinar_registrations_member_insert_own ON public.webinar_registrations;
CREATE POLICY webinar_registrations_member_insert_own
ON public.webinar_registrations FOR INSERT TO authenticated
WITH CHECK (
    user_id = auth.uid()
    AND status = 'registered'
    AND EXISTS (
        SELECT 1
        FROM public.webinars w
        WHERE w.id = webinar_id
          AND w.status = 'published'
    )
);

DROP POLICY IF EXISTS webinar_registrations_admin_update ON public.webinar_registrations;
CREATE POLICY webinar_registrations_admin_update
ON public.webinar_registrations FOR UPDATE TO authenticated
USING (public.is_super_admin())
WITH CHECK (public.is_super_admin());

DROP POLICY IF EXISTS webinar_registrations_admin_delete ON public.webinar_registrations;
CREATE POLICY webinar_registrations_admin_delete
ON public.webinar_registrations FOR DELETE TO authenticated
USING (public.is_super_admin());

COMMENT ON TABLE public.webinars IS 'Jadwal webinar yang dikelola Super Admin DIGITALCOREVISION.';
COMMENT ON TABLE public.webinar_registrations IS 'Pendaftaran dan kehadiran Member pada webinar.';

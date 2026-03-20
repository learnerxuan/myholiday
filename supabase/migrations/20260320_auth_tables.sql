-- ============================================================
-- MyHoliday — Auth Migration
-- Creates traveller_profiles and tour_guides tables
-- linked to Supabase auth.users (no password_hash)
-- Run this in Supabase SQL Editor
-- ============================================================


-- ── EXTENSIONS ──────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";


-- ============================================================
-- 1. TRAVELLER PROFILES
-- Linked to auth.users — one row per traveller
-- Created on first Google sign-in via onboarding page
-- ============================================================
CREATE TABLE IF NOT EXISTS public.traveller_profiles (
    id                      UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id                 UUID          NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name               VARCHAR(150),
    age                     INTEGER,
    nationality             VARCHAR(100),
    dietary_restrictions    VARCHAR(100),
    accessibility_needs     BOOLEAN       DEFAULT FALSE,
    preferred_language      VARCHAR(50)   DEFAULT 'English',
    created_at              TIMESTAMP     DEFAULT NOW()
);


-- ============================================================
-- 2. TOUR_GUIDES
-- Linked to auth.users — one row per guide
-- Created on guide onboarding; starts as 'pending'
-- ============================================================
CREATE TABLE IF NOT EXISTS public.tour_guides (
    id                      UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id                 UUID          NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name               VARCHAR(150),
    city_id                 UUID          REFERENCES public.destinations(id) ON DELETE SET NULL,
    document_url            VARCHAR(500),
    verification_status     VARCHAR(20)   NOT NULL DEFAULT 'pending'
                                          CHECK (verification_status IN ('pending', 'approved', 'rejected')),
    created_at              TIMESTAMP     DEFAULT NOW()
);


-- ============================================================
-- INDEXES
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_traveller_profiles_user  ON public.traveller_profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_tour_guides_user         ON public.tour_guides(user_id);
CREATE INDEX IF NOT EXISTS idx_tour_guides_city         ON public.tour_guides(city_id);
CREATE INDEX IF NOT EXISTS idx_tour_guides_status       ON public.tour_guides(verification_status);


-- ============================================================
-- ROW LEVEL SECURITY — Enable
-- ============================================================
ALTER TABLE public.traveller_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tour_guides        ENABLE ROW LEVEL SECURITY;


-- ============================================================
-- RLS POLICIES — traveller_profiles
-- ============================================================

-- Travellers can read and update their own row only
CREATE POLICY "traveller: own row select"
    ON public.traveller_profiles FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "traveller: own row insert"
    ON public.traveller_profiles FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "traveller: own row update"
    ON public.traveller_profiles FOR UPDATE
    USING (auth.uid() = user_id);

-- Admins can read all traveller profiles (needed for admin dashboard)
CREATE POLICY "admin: read all traveller profiles"
    ON public.traveller_profiles FOR SELECT
    USING (
        (SELECT raw_user_meta_data->>'role' FROM auth.users WHERE id = auth.uid()) = 'admin'
    );


-- ============================================================
-- RLS POLICIES — tour_guides
-- ============================================================

-- Guides can read and update their own row only
CREATE POLICY "guide: own row select"
    ON public.tour_guides FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "guide: own row insert"
    ON public.tour_guides FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "guide: own row update"
    ON public.tour_guides FOR UPDATE
    USING (auth.uid() = user_id);

-- Admins can read all guide profiles
CREATE POLICY "admin: read all guide profiles"
    ON public.tour_guides FOR SELECT
    USING (
        (SELECT raw_user_meta_data->>'role' FROM auth.users WHERE id = auth.uid()) = 'admin'
    );

-- Admins can update verification_status on guide profiles
CREATE POLICY "admin: update guide verification"
    ON public.tour_guides FOR UPDATE
    USING (
        (SELECT raw_user_meta_data->>'role' FROM auth.users WHERE id = auth.uid()) = 'admin'
    );

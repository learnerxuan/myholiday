# Feature: Authentication & User Profile

## Overview

Build the authentication flow (Login/Register via Google OAuth, Onboarding, User Profile) and session management using Supabase Auth. MyHoliday has three user roles: Traveller, Tour Guide, and Administrator. Access control is enforced via Supabase Row Level Security (RLS).

**Auth method: Google OAuth only.** There is no email/password form, no password validation, and no forgot-password flow. Supabase Auth handles all token management.

**Dependencies:** Requires `01-project-setup` (Supabase client) and `02-ui-components` (Button, Input, Select, Spinner, Badge, Avatar).

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Next.js 15 (App Router) |
| Auth | Supabase Auth — Google OAuth provider |
| Database | Supabase (PostgreSQL) with RLS |
| Styling | Tailwind CSS with custom tokens |

---

## Route Ownership

| Page | Route | Owner |
|---|---|---|
| Login / Register | `app/auth/login/page.jsx` | ZL |
| Auth Callback | `app/auth/callback/route.ts` | ZL |
| Traveller Onboarding | `app/auth/onboarding/traveller/page.jsx` | ZL |
| Guide Onboarding | `app/auth/onboarding/guide/page.jsx` | ZL |
| User Profile | `app/profile/page.jsx` | ZL |

---

## Design Tokens (Quick Reference)

### Colours
- Charcoal `charcoal` — primary text, buttons
- Warm White `warmwhite` — page background
- Amber `amber` — accent, CTAs, active links
- Amber Dark `amberdark` — hover on amber elements
- Error `error` — form errors
- Error BG `error-bg` — error message background
- Border `border` — form field borders
- Secondary `secondary` — descriptions
- Tertiary `tertiary` — placeholders

### Typography
- Section heading: `text-4xl font-extrabold font-display`
- Body: `text-sm font-normal font-body`
- UI label: `text-xs font-semibold font-body`

### Spacing
- Section vertical padding: `py-20`
- Form field padding: `py-2.5 px-3.5`
- Button padding: `py-2 px-5`

---

## User Roles

| Role | Access |
|---|---|
| Traveller | Quiz, recommendations, city pages, AI planner, my plans, marketplace (post & accept) |
| Tour Guide | Marketplace browser (city-scoped), proposal submission, guide chat |
| Administrator | Full platform access — user management, guide verification, marketplace moderation, analytics |

---

## Database Schema

> ⚠️ The `users` table from the original README (with `password_hash`) is **dropped**. Supabase Auth manages accounts in `auth.users` internally. Your app tables link to it via `user_id`.

```sql
-- auth.users — managed entirely by Supabase Auth (do not CREATE this table)
-- Fields available: id, email, raw_user_meta_data->>'role', created_at

-- Traveller profile (extra details used by AI planner)
traveller_profiles
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name VARCHAR(150),
  age INTEGER,
  nationality VARCHAR(100),
  dietary_restrictions VARCHAR(100),
  accessibility_needs BOOLEAN DEFAULT FALSE,
  preferred_language VARCHAR(50) DEFAULT 'English',
  created_at TIMESTAMP DEFAULT NOW()

-- Tour guide profile
tour_guides
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name VARCHAR(150),
  city_id UUID REFERENCES destinations(id) ON DELETE SET NULL,
  document_url VARCHAR(500),
  verification_status VARCHAR(20) NOT NULL DEFAULT 'pending'
    CHECK (verification_status IN ('pending', 'approved', 'rejected')),
  created_at TIMESTAMP DEFAULT NOW()
```

---

## Authentication Flow

### Step 1 — Login/Register Page (`app/auth/login/page.jsx`)

A single page for both new and returning users. No form fields.

- "Sign in with Google" button → calls `supabase.auth.signInWithOAuth({ provider: 'google', options: { redirectTo: '/auth/callback' } })`
- For guides: a separate "Register as Tour Guide with Google" button — same OAuth call but sets intent in the redirect URL (e.g. `redirectTo: '/auth/callback?intent=guide'`)
- After OAuth, Google handles the popup; Supabase handles the token exchange

### Step 2 — Auth Callback Route (`app/auth/callback/route.ts`)

**This route is mandatory.** After Google redirects back, Supabase needs this to exchange the OAuth code for a session.

```ts
// app/auth/callback/route.ts
import { createRouteHandlerClient } from '@supabase/auth-helpers-nextjs'
import { cookies } from 'next/headers'
import { NextResponse } from 'next/server'

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url)
  const code = searchParams.get('code')
  const intent = searchParams.get('intent') // 'guide' or null (traveller)

  if (code) {
    const supabase = createRouteHandlerClient({ cookies })
    await supabase.auth.exchangeCodeForSession(code)
  }

  // Check if this is a new user (no profile row yet)
  // → redirect to correct onboarding page
  // Returning users → redirect to home
  const redirectTo = intent === 'guide' ? '/auth/onboarding/guide' : '/auth/onboarding/traveller'
  return NextResponse.redirect(new URL(redirectTo, request.url))
}
```

### Step 3 — Onboarding (first-time users only)

**Traveller Onboarding** (`app/auth/onboarding/traveller/page.jsx`):
- Check if `traveller_profiles` row exists for this `user_id`
- If row exists → skip onboarding → redirect to `/`
- If not → show the onboarding form:
  - Full name (pre-filled from Google), nationality, dietary restrictions, accessibility needs, preferred language
  - On save: `INSERT INTO traveller_profiles (...)`, set `role: 'traveller'` in user metadata via `supabase.auth.updateUser`
  - Redirect to homepage

**Guide Onboarding** (`app/auth/onboarding/guide/page.jsx`):
- Check if `tour_guides` row exists for this `user_id` → skip if found
- If not → show guide onboarding form:
  - Full name (pre-filled from Google)
  - Assigned city — `Select` dropdown populated from `destinations` table (server-side fetch)
  - Document upload — Supabase Storage bucket `guide-documents`
  - On save: `INSERT INTO tour_guides (...)` with `verification_status: 'pending'`, set `role: 'guide'` in metadata
  - Show message: *"Your account is pending admin approval."*

### Step 4 — Returning Users

On login, after the callback:
- Fetch user metadata → read `role`
- If `role === 'traveller'` → redirect to `homepage`
- If `role === 'guide'` → redirect to `/guide/marketplace`
- If `role === 'admin'` → redirect to `/admin`

### Logout

```ts
await supabase.auth.signOut()
// redirect to '/'
```

Accessible from the Navbar (shown when session is active).

---

## Admin Account

Admins are **not created via the app**. They are seeded manually:

1. Create the user in Supabase Auth via the Supabase Dashboard (Authentication → Users → Add user), or via a one-time SQL script
2. Set their metadata to `{ "role": "admin" }` via the Dashboard or:
```sql
UPDATE auth.users
SET raw_user_meta_data = '{"role": "admin"}'
WHERE email = 'admin@myholiday.com';
```
3. No profile table row is required for admins

---

## Session Management & Middleware

`middleware.ts` lives at the **project root** (not inside `app/`). It runs on every request and:
- Reads the Supabase session from cookies
- Redirects unauthenticated users to `/auth/login` for protected routes
- Checks `role` from user metadata and blocks cross-role access:
  - Travellers cannot access `/guide/*` or `/admin/*`
  - Guides cannot access `/admin/*` or traveller-only routes
  - Admins can access everything

```ts
// Protected route prefixes
const TRAVELLER_ROUTES = ['/quiz', '/destinations', '/planner', '/my-plans', '/marketplace']
const GUIDE_ROUTES     = ['/guide']
const ADMIN_ROUTES     = ['/admin']
```

---

## Profile Page (`app/profile/page.jsx`)

Requires authentication. Shows different fields based on role.

### Traveller view
- Avatar (from Google profile photo), full name
- Editable: nationality, age, dietary restrictions, accessibility needs, preferred language
- Save → `UPDATE traveller_profiles SET ... WHERE user_id = ...`
- Show success/error feedback

### Tour Guide view
- Avatar, full name
- Assigned city — **read-only** after initial registration
- Verification status — shown as `StatusBadge` (`pending` / `approved` / `rejected`)
- Document upload/replace — re-upload to Supabase Storage, update `document_url`

---

## RLS Policies

```sql
-- traveller_profiles: own row only
CREATE POLICY "Travellers own profile" ON traveller_profiles
  FOR ALL USING (auth.uid() = user_id);

-- tour_guides: own row only
CREATE POLICY "Guides own profile" ON tour_guides
  FOR ALL USING (auth.uid() = user_id);

-- Admins can read all traveller profiles
CREATE POLICY "Admin reads all traveller profiles" ON traveller_profiles
  FOR SELECT USING (
    (SELECT raw_user_meta_data->>'role' FROM auth.users WHERE id = auth.uid()) = 'admin'
  );

-- Admins can read all guide profiles
CREATE POLICY "Admin reads all guide profiles" ON tour_guides
  FOR SELECT USING (
    (SELECT raw_user_meta_data->>'role' FROM auth.users WHERE id = auth.uid()) = 'admin'
  );

-- Admins can update guide verification_status
CREATE POLICY "Admin updates guide verification" ON tour_guides
  FOR UPDATE USING (
    (SELECT raw_user_meta_data->>'role' FROM auth.users WHERE id = auth.uid()) = 'admin'
  );

-- Guide documents bucket: guide can upload/read own docs; admins can read all
-- Set in Supabase Storage bucket policy (not SQL RLS)
```

---

## Components Used (from `@/components/ui/`)

- `Button` — OAuth sign-in button, form submit, save changes
- `Input` — name, nationality, dietary restrictions fields
- `Select` — city dropdown (guide onboarding), language, nationality
- `PageHeader` — page titles
- `Spinner` — loading states during OAuth redirect / save
- `Avatar` — profile picture (from Google photo URL)
- `Badge` / `StatusBadge` — guide verification status display

---

## CSS Rules

- Never write inline `style={{}}`
- Never create a separate `.css` file for a component
- Never use arbitrary Tailwind values like `w-[347px]`
- Always use named colour tokens — never hardcode hex values

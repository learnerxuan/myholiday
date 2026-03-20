'use client'

import { createBrowserClient } from '@supabase/ssr'

const supabase = createBrowserClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
)

export async function signInWithGoogle(intent?: 'guide') {
  const redirectTo = intent
    ? `${window.location.origin}/auth/callback?intent=guide`
    : `${window.location.origin}/auth/callback`

  await supabase.auth.signInWithOAuth({
    provider: 'google',
    options: { redirectTo },
  })
}

export async function signOut() {
  await supabase.auth.signOut()
  window.location.href = '/'
}

export { supabase }

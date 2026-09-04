// lib/supabaseAdmin.js
// Server-side only. Uses the service_role key, which bypasses RLS.
// NEVER import this file from client-side code or expose SUPABASE_SERVICE_ROLE_KEY to the browser.

import { createClient } from '@supabase/supabase-js';

export const supabaseAdmin = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY,
  { auth: { persistSession: false } }
);

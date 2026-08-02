import { createClient } from '@supabase/supabase-js';

// Bindings type describes what env vars are available in Cloudflare Workers
type Bindings = {
  SUPABASE_URL: string;
  SUPABASE_SERVICE_ROLE_KEY: string;
};

// Call this inside each route handler, passing c.env
export const getSupabaseClient = (env: Bindings) => {
  return createClient(env.SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY);
};
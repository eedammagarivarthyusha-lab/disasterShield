import { createClient } from '@supabase/supabase-js';
import { inspectSupabaseConfig } from './supabase-config.js';

export const supabaseConfig = inspectSupabaseConfig(import.meta.env);
export const supabase = supabaseConfig.ok
  ? createClient(supabaseConfig.url, supabaseConfig.key, {
      auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true },
    })
  : null;

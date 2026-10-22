export function inspectSupabaseConfig(env) {
  const url = (env.VITE_SUPABASE_URL || '').trim();
  const key = (env.VITE_SUPABASE_PUBLISHABLE_KEY || env.VITE_SUPABASE_ANON_KEY || '').trim();
  if (!url || !key) {
    const missing = [!url && 'VITE_SUPABASE_URL', !key && 'VITE_SUPABASE_PUBLISHABLE_KEY (or legacy VITE_SUPABASE_ANON_KEY)'].filter(Boolean);
    return { ok: false, message: `Supabase is not configured. Add ${missing.join(' and ')} to .env.local, then restart Vite.` };
  }
  let parsed;
  try { parsed = new URL(url); } catch { return { ok: false, message: 'VITE_SUPABASE_URL is not a valid URL. Copy the Project URL from the Supabase Dashboard Connect dialog.' }; }
  const local = ['localhost', '127.0.0.1'].includes(parsed.hostname);
  if (!['https:', ...(local ? ['http:'] : [])].includes(parsed.protocol) || parsed.pathname !== '/' || parsed.search || parsed.hash) {
    return { ok: false, message: 'VITE_SUPABASE_URL must be the project origin (HTTPS, without a path). Copy the Project URL from the Supabase Dashboard Connect dialog.' };
  }
  if (/your[-_ ]?(project|supabase)|placeholder|example\.com/i.test(url + key)) {
    return { ok: false, message: 'Supabase environment values still contain placeholders. Replace them with the real Project URL and publishable/anon key.' };
  }
  if (/^sb_secret_/i.test(key)) {
    return { ok: false, message: 'A Supabase secret key was supplied. Remove it immediately; browser configuration must use only a publishable key or legacy anon key.' };
  }
  if (key.split('.').length === 3) {
    try {
      const payload = JSON.parse(atob(key.split('.')[1].replace(/-/g, '+').replace(/_/g, '/')));
      if (payload.role === 'service_role') return { ok: false, message: 'A service-role key was supplied. Never expose it to the browser. Use the project publishable key or legacy anon key.' };
    } catch { /* opaque non-JWT publishable keys are valid; Supabase will validate them remotely */ }
  }
  return { ok: true, url: parsed.origin, key };
}

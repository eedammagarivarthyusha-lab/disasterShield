import test from 'node:test';
import assert from 'node:assert/strict';
import { inspectSupabaseConfig } from '../src/supabase-config.js';

test('reports exactly which Vite configuration keys are missing', () => {
  const result = inspectSupabaseConfig({});
  assert.equal(result.ok, false);
  assert.match(result.message, /VITE_SUPABASE_URL and VITE_SUPABASE_PUBLISHABLE_KEY/);
});

test('rejects malformed URLs and non-HTTPS remote URLs', () => {
  assert.match(inspectSupabaseConfig({ VITE_SUPABASE_URL: 'not a URL', VITE_SUPABASE_ANON_KEY: 'key' }).message, /not a valid URL/);
  assert.match(inspectSupabaseConfig({ VITE_SUPABASE_URL: 'http://project.supabase.co', VITE_SUPABASE_ANON_KEY: 'key' }).message, /HTTPS/);
});

test('rejects template values instead of initializing a fake client', () => {
  const result = inspectSupabaseConfig({ VITE_SUPABASE_URL: 'https://YOUR_PROJECT_REF.supabase.co', VITE_SUPABASE_ANON_KEY: 'YOUR_SUPABASE_PUBLISHABLE_OR_ANON_KEY' });
  assert.equal(result.ok, false);
  assert.match(result.message, /placeholders/);
});

test('blocks service-role secrets from browser configuration', () => {
  const jwt = 'eyJhbGciOiJub25lIn0.eyJyb2xlIjoic2VydmljZV9yb2xlIn0.signature';
  assert.match(inspectSupabaseConfig({ VITE_SUPABASE_URL: 'https://abcd1234.supabase.co', VITE_SUPABASE_ANON_KEY: jwt }).message, /service-role key/);
  assert.match(inspectSupabaseConfig({ VITE_SUPABASE_URL: 'https://abcd1234.supabase.co', VITE_SUPABASE_ANON_KEY: 'sb_secret_test' }).message, /secret key/);
});

test('accepts a real-looking HTTPS project URL and publishable key', () => {
  const result = inspectSupabaseConfig({ VITE_SUPABASE_URL: 'https://abcd1234.supabase.co', VITE_SUPABASE_ANON_KEY: 'sb_publishable_test-key' });
  assert.equal(result.ok, true);
  assert.equal(result.url, 'https://abcd1234.supabase.co');
});

test('allows HTTP only for local development endpoints', () => {
  assert.equal(inspectSupabaseConfig({ VITE_SUPABASE_URL: 'http://127.0.0.1:54321', VITE_SUPABASE_ANON_KEY: 'local-test-key' }).ok, true);
});

test('prefers the publishable key and retains the legacy anon key fallback', () => {
  const publishable = inspectSupabaseConfig({ VITE_SUPABASE_URL: 'https://abcd1234.supabase.co', VITE_SUPABASE_PUBLISHABLE_KEY: 'sb_publishable_test-key' });
  const legacy = inspectSupabaseConfig({ VITE_SUPABASE_URL: 'https://abcd1234.supabase.co', VITE_SUPABASE_ANON_KEY: 'legacy-anon-key' });
  assert.equal(publishable.ok, true);
  assert.equal(legacy.ok, true);
});

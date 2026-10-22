# DisasterShield

India-focused disaster readiness and response coordination UI. This repository began empty; it now contains a React/Vite application, a Supabase initial schema, and a deliberately small set of honest integrations. It is a foundation for configuration and further backend work, not a production deployment or a completed emergency-response service.

## Current state

- Home is public and defaults to **Live Data Mode** on every page load. Demo mode is opt-in, confirmed, visibly bannered, and its fictional scenarios are static and read-only. No demo data is seeded into the live database.
- Open-Meteo current weather is fetched for Pune by default or the browser-provided coordinates after the user chooses Use my location. Coordinates are held in page state only. Weather is not a disaster warning. A production deployment should add a server-side cache/proxy and confirm provider terms and capacity.
- Official disaster advisories are **not configured**. Live mode shows this explicitly and never substitutes demo advisories.
- Supabase Auth is wired for registration, sign-in, sign-out, session restoration, password recovery/update, editable display name, citizen incident/assistance submissions, and private My Requests retrieval when configured. Credentials are not present in this checkout, so none of those live Supabase flows has been tested. Authority verification/approval and privileged status changes still need trusted admin/server operations and integration testing.
- Maps use Leaflet and OpenStreetMap tiles with attribution. Demo points are fictional. Live mode has no incident/risk overlays until authoritative or application data is configured.
- The assistant is a deterministic, clearly identified general-guidance fallback. No AI provider is connected. Emergency calling is a `tel:112` link; the user initiates the call.
- Incident and assistance forms submit directly through the authenticated Supabase client under owner-only insert/select RLS. Other operational forms are not yet wired. No SMS, email, push, government, dispatch, routing, or shelter feeds are connected.

## Local development

Requirements: Node.js 20+ and npm.

```sh
npm install
cp .env.example .env.local
npm run dev
```

To create a production bundle:

```sh
npm run build
npm run preview
```

Replace the two safe placeholders in `.env.local` with the actual Supabase **Project URL** and **publishable key** (or legacy anon key). The Project URL is available from the Supabase Dashboard **Connect** dialog; API keys are in **Settings → API Keys**. Never put the service-role/secret key, database password, AI, mail, SMS, or other private provider keys in `VITE_` variables. `.env.local` is ignored by Git. Vite reads environment variables at startup/build time: stop and restart `npm run dev` after changing them, and rebuild/redeploy after changing production values.

## Supabase initialization

1. Create or select the intended Supabase project. The URL and publishable/anon key are browser-safe identifiers; access is protected by RLS, not by hiding these values.
2. Apply `supabase/migrations/202610220001_initial.sql` **once** to a new, empty project, followed by `202610220002_auth_profiles.sql`. The second migration is an additive profile/auth upgrade and backfills missing profiles without overwriting existing ones. If the initial schema was already installed, apply only migration 002 after checking `supabase_migrations.schema_migrations`; do not rerun migration 001.
3. In Supabase Dashboard → Authentication → URL Configuration, set the Site URL and allowlist local `http://localhost:5173/` and the production origin. Registration and recovery links redirect to the current app origin; it must match an allowed redirect URL. Enable email confirmation if desired; when enabled, users must confirm before signing in. Configure SMTP if the default Supabase email limits do not fit your use. See [Supabase redirect URL guidance](https://supabase.com/docs/guides/auth/redirect-urls).
4. Create a local file and restart Vite:

   ```sh
   cp .env.example .env.local
   # Edit .env.local; replace the two Supabase placeholders with actual dashboard values.
   npm run dev
   ```

5. Registration stores the full name and consent timestamp in `profiles`; passwords remain in Supabase Auth. Citizen and relief-partner accounts receive their requested allowed role. Authority applicants get a pending profile and a recorded organization/justification; they cannot open the protected portal until approved.
6. This starter has no public admin-approval endpoint. Verify a first administrator out of band, then use the Supabase SQL Editor with an owner-level session to grant that verified account the `authority` role and `approved` state. Record the approval internally. Never place database/service-role credentials in the browser. Before production, implement and audit a dedicated admin/Edge Function for ongoing approvals.
7. Test RLS with separate citizen accounts, a relief partner, a pending authority, and an approved authority in a non-production project before storing real data. No project credentials were present here, so those tests remain outstanding.
8. Back up the database before schema changes. Roll back by restoring a tested backup or applying a reviewed forward migration; do not delete operational data to reverse a migration.

The first migration enables and forces RLS on all exposed operational tables. Private citizen records are owner-readable and approved-authority-readable. Relief partners can read only requests explicitly shared with partners; inventory is owner-managed; operational assignments and shelter/team management are restricted to approved authorities. Migration 002 lets a user update only their display name; role and authority status remain protected. No policy grants public `anon` access. Incident and assistance inserts are user-owned and status starts as `submitted`. RLS is a baseline, not a substitute for trusted server authorization around privileged status changes, assignments, and allocations. The supplied UI does not yet implement those privileged mutations.

## Authentication diagnostics

- **“Supabase is not configured”**: ensure `.env.local` exists in the project root and contains non-placeholder `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` values. Restart Vite after editing.
- **Invalid URL**: copy the Project URL from Project Settings → API. Use the origin only (`https://<project-ref>.supabase.co`), without `/rest/v1` or other paths.
- **Could not reach Supabase**: check the URL, browser network, project availability, and Supabase Auth status.
- **Email/password incorrect**: confirm registration email first when confirmations are enabled; use Forgot password to request a recovery link.
- **Profile/table unavailable or database permission error**: apply migrations 001 and 002 in order (or only 002 if 001 is already installed) and inspect Supabase API schema cache and RLS policies.
- **Authority access pending**: this is expected until a trusted administrator verifies the application; choosing the role during signup does not approve it.

## Demo and live mode separation

Live is always the fresh-session default. Demo content is a read-only fictional presentation dataset embedded in the frontend and cannot mutate the Supabase schema. It is isolated from live records in the current implementation, but it is **not** a server-enforced demo backend. Demo mutations/reset are intentionally absent. Do not use this demonstration dataset to represent real operations. A production judge/demo environment requiring interactive simulated workflows should use a separate Supabase project or server-enforced schema with separate credentials, no real outbound providers, and dedicated isolation tests before those mutations are enabled.

## Integrations and source status

| Source | Current status | Notes |
| --- | --- | --- |
| Supabase | Not configured unless environment variables are set | Auth client is wired; no project credentials provided. |
| Weather | [Open-Meteo Forecast API](https://open-meteo.com/en/docs) request implemented | Request-level success is shown in the UI. Not an official warning source. No server cache. |
| Official alerts | Not configured | No feed origin/access/licensing was established. Live mode displays no sample substitute. |
| Map tiles | OpenStreetMap standard tile service | Attribution included. Follow the [OSM tile policy](https://operations.osmfoundation.org/policies/tiles/) and use a suitable provider for production traffic. `VITE_MAP_TILE_URL` can replace the URL template. |
| AI | Not configured | Deterministic fallback only. `OPENAI_API_KEY` is server-only and currently unused. |
| Notifications, government coordination, routing | Not available | No credentials, permissions, or tested integration supplied. |

## Deployment preparation

This project contains no existing hosting configuration or connected deployment account. Use a static hosting platform that supports Vite, set build command `npm run build` and output directory `dist`, configure the SPA fallback to `/index.html`, add the environment variables listed above, and set Supabase Auth redirect URLs. Apply reviewed migrations before enabling authentication. Test geolocation, mobile layout, source-unavailable states, and RLS in the deployed environment. This repository has **not** been deployed or checked at a public URL.

## Limitations requiring completion before production use

This starter is not yet suitable for actual incident dispatch or emergency operations. It lacks trusted server/Edge Functions for privileged operational writes, audited authority approval UI, complete workflow/state transition enforcement, matching/allocation transactions, application status history, storage upload controls, admin source health checks, comprehensive automated security/workflow tests, and a production deployment. The current automated tests cover Supabase environment validation only. No official warning, shelter, road, responder, or government feed was provided. Do not use displayed absence of data to infer safety or complete coverage.

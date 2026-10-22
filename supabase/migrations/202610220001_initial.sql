-- DisasterShield initial schema. Apply to a new Supabase project using the SQL editor or CLI.
create extension if not exists pgcrypto;
create schema if not exists extensions;
create extension if not exists postgis with schema extensions;

create type public.app_role as enum ('citizen','relief_partner','authority');
create type public.authority_state as enum ('not_applied','pending','approved','rejected','suspended');
create type public.record_status as enum ('submitted','under_review','verified','assigned','in_progress','fulfilled','resolved','rejected','closed');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  role public.app_role not null default 'citizen',
  authority_state public.authority_state not null default 'not_applied',
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  constraint authority_state_role check (authority_state = 'not_applied' or role = 'authority')
);
create table public.authority_applications (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles(id),
  organization text not null, justification text not null, state public.authority_state not null default 'pending',
  submitted_at timestamptz not null default now(), reviewed_at timestamptz, reviewed_by uuid references public.profiles(id), review_note text
);
create table public.incidents (
  id uuid primary key default gen_random_uuid(), reporter_id uuid not null references public.profiles(id),
  incident_type text not null, description text not null, urgency text not null check (urgency in ('low','moderate','high','critical')),
  location_label text not null, location extensions.geography(point,4326), people_affected integer check (people_affected is null or people_affected >= 0),
  assistance_required text[] not null default '{}', status public.record_status not null default 'submitted',
  verified_by uuid references public.profiles(id), verified_at timestamptz, duplicate_of uuid references public.incidents(id),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.assistance_requests (
  id uuid primary key default gen_random_uuid(), requester_id uuid not null references public.profiles(id),
  request_type text not null check (request_type in ('food','water','medical','shelter','other')),
  quantity numeric check (quantity is null or quantity >= 0), unit text, household_needs text, location_label text not null,
  urgency text not null check (urgency in ('low','moderate','high','critical')), status public.record_status not null default 'submitted',
  shared_with_partners boolean not null default false, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.damage_reports (
  id uuid primary key default gen_random_uuid(), reporter_id uuid not null references public.profiles(id), category text not null,
  description text not null, location_label text not null, status public.record_status not null default 'submitted', created_at timestamptz not null default now()
);
create table public.reunification_requests (
  id uuid primary key default gen_random_uuid(), requester_id uuid not null references public.profiles(id),
  details text not null, contact_preference text, location_label text, status public.record_status not null default 'submitted', created_at timestamptz not null default now()
);
create table public.shelters (
  id uuid primary key default gen_random_uuid(), name text not null, location_label text not null, location extensions.geography(point,4326),
  capacity integer not null check (capacity >= 0), occupancy integer not null default 0 check (occupancy >= 0),
  accessibility text[] not null default '{}', operational_status text not null default 'unknown' check (operational_status in ('open','limited','closed','unknown')),
  verified boolean not null default false, verified_by uuid references public.profiles(id), updated_at timestamptz not null default now(),
  constraint occupancy_capacity check (occupancy <= capacity)
);
create table public.response_teams (
  id uuid primary key default gen_random_uuid(), name text not null, capabilities text[] not null default '{}',
  availability text not null default 'unavailable' check (availability in ('available','assigned','unavailable')), updated_at timestamptz not null default now()
);
create table public.assignments (
  id uuid primary key default gen_random_uuid(), incident_id uuid references public.incidents(id), team_id uuid references public.response_teams(id),
  coordinator_id uuid not null references public.profiles(id), task text not null, state text not null default 'assigned' check (state in ('assigned','accepted','in_progress','completed','cancelled')),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.resources (
  id uuid primary key default gen_random_uuid(), owner_id uuid not null references public.profiles(id), category text not null,
  item text not null, quantity numeric not null check (quantity >= 0), unit text not null, available boolean not null default true,
  general_location text, updated_at timestamptz not null default now()
);
create table public.volunteers (
  id uuid primary key default gen_random_uuid(), owner_id uuid not null references public.profiles(id), skills text[] not null default '{}',
  work_preferences text[] not null default '{}', availability text not null default 'unavailable', service_area text not null,
  consent boolean not null default false, created_at timestamptz not null default now()
);
create table public.vehicles (
  id uuid primary key default gen_random_uuid(), owner_id uuid not null references public.profiles(id), vehicle_type text not null,
  capacity text, availability text not null default 'unavailable', general_location text not null, restrictions text, updated_at timestamptz not null default now()
);
create table public.resource_allocations (
  id uuid primary key default gen_random_uuid(), resource_id uuid not null references public.resources(id), request_id uuid references public.assistance_requests(id),
  quantity numeric not null check (quantity > 0), allocated_by uuid not null references public.profiles(id), state text not null default 'proposed' check (state in ('proposed','confirmed','fulfilled','cancelled')),
  created_at timestamptz not null default now()
);
create table public.status_history (
  id uuid primary key default gen_random_uuid(), entity_table text not null, entity_id uuid not null, old_status text, new_status text not null,
  actor_id uuid not null references public.profiles(id), note text, created_at timestamptz not null default now()
);
create table public.audit_events (
  id uuid primary key default gen_random_uuid(), actor_id uuid not null references public.profiles(id), action text not null,
  entity_table text not null, entity_id uuid not null, created_at timestamptz not null default now()
);
create table public.notifications (
  id uuid primary key default gen_random_uuid(), recipient_id uuid not null references public.profiles(id), title text not null,
  body text not null, read_at timestamptz, created_at timestamptz not null default now()
);
create table public.checklist_progress (
  user_id uuid not null references public.profiles(id), item_key text not null, completed boolean not null default false,
  updated_at timestamptz not null default now(), primary key(user_id,item_key)
);

create index incidents_reporter_created_idx on public.incidents(reporter_id,created_at desc);
create index incidents_status_time_idx on public.incidents(status,created_at desc);
create index requests_owner_status_idx on public.assistance_requests(requester_id,status);
create index requests_partner_share_idx on public.assistance_requests(shared_with_partners,status) where shared_with_partners;
create index damage_owner_idx on public.damage_reports(reporter_id,created_at desc);
create index assignments_incident_idx on public.assignments(incident_id,state);
create index resources_owner_idx on public.resources(owner_id,updated_at desc);
create index notification_recipient_idx on public.notifications(recipient_id,created_at desc);

-- Role/approval helpers. SECURITY DEFINER functions pin search_path to prevent object shadowing.
create function public.is_approved_authority() returns boolean language sql stable security definer set search_path=public,pg_temp as $$
 select exists(select 1 from public.profiles p where p.id=auth.uid() and p.role='authority' and p.authority_state='approved') $$;
create function public.is_relief_partner() returns boolean language sql stable security definer set search_path=public,pg_temp as $$
 select exists(select 1 from public.profiles p where p.id=auth.uid() and p.role='relief_partner') $$;

-- Role is assigned from a narrow allowlist at signup; arbitrary metadata cannot grant authority.
create function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
declare requested text := coalesce(new.raw_user_meta_data->>'requested_role','citizen');
begin
 insert into public.profiles(id,role,authority_state) values (
  new.id,
  case when requested='relief_partner' then 'relief_partner'::public.app_role when requested='authority' then 'authority'::public.app_role else 'citizen'::public.app_role end,
  case when requested='authority' then 'pending'::public.authority_state else 'not_applied'::public.authority_state end
 );
 return new;
end $$;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();

-- Force RLS and default deny on every exposed operational table.
do $$ declare t text; begin
 foreach t in array array['profiles','authority_applications','incidents','assistance_requests','damage_reports','reunification_requests','shelters','response_teams','assignments','resources','volunteers','vehicles','resource_allocations','status_history','audit_events','notifications','checklist_progress'] loop
  execute format('alter table public.%I enable row level security',t);
  execute format('alter table public.%I force row level security',t);
 end loop;
end $$;
revoke all on all tables in schema public from anon, authenticated;
grant select,insert on public.profiles to authenticated;
grant select,insert on public.authority_applications to authenticated;
grant select,insert on public.incidents to authenticated;
grant select,insert on public.assistance_requests to authenticated;
grant select,insert on public.damage_reports, public.reunification_requests to authenticated;
grant select,insert,update on public.checklist_progress to authenticated;
grant select,insert,update on public.shelters,public.response_teams,public.assignments,public.resources,public.volunteers,public.vehicles,public.resource_allocations to authenticated;
grant select,insert on public.status_history,public.audit_events,public.notifications to authenticated;

create policy profile_read_self on public.profiles for select to authenticated using(id=auth.uid() or public.is_approved_authority());
create policy profile_insert_self_limited on public.profiles for insert to authenticated with check(id=auth.uid() and role in ('citizen','relief_partner') and authority_state='not_applied');
create policy authority_application_owner_read on public.authority_applications for select to authenticated using(user_id=auth.uid() or public.is_approved_authority());
create policy authority_application_owner_insert on public.authority_applications for insert to authenticated with check(user_id=auth.uid() and state='pending');
create policy incident_owner_or_authority_read on public.incidents for select to authenticated using(reporter_id=auth.uid() or public.is_approved_authority());
create policy incident_owner_insert on public.incidents for insert to authenticated with check(reporter_id=auth.uid() and status='submitted' and verified_by is null and duplicate_of is null);
create policy request_owner_or_authority_read on public.assistance_requests for select to authenticated using(requester_id=auth.uid() or public.is_approved_authority() or (public.is_relief_partner() and shared_with_partners));
create policy request_owner_insert on public.assistance_requests for insert to authenticated with check(requester_id=auth.uid() and status='submitted');
create policy damage_owner_or_authority_read on public.damage_reports for select to authenticated using(reporter_id=auth.uid() or public.is_approved_authority());
create policy damage_owner_insert on public.damage_reports for insert to authenticated with check(reporter_id=auth.uid() and status='submitted');
create policy reunion_owner_or_authority_read on public.reunification_requests for select to authenticated using(requester_id=auth.uid() or public.is_approved_authority());
create policy reunion_owner_insert on public.reunification_requests for insert to authenticated with check(requester_id=auth.uid() and status='submitted');
create policy checklist_self on public.checklist_progress for all to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy shelters_authority_only on public.shelters for all to authenticated using(public.is_approved_authority()) with check(public.is_approved_authority());
create policy teams_authority_only on public.response_teams for all to authenticated using(public.is_approved_authority()) with check(public.is_approved_authority());
create policy assignments_authority_only on public.assignments for all to authenticated using(public.is_approved_authority()) with check(public.is_approved_authority());
create policy resources_partner_owner_or_authority on public.resources for all to authenticated using((owner_id=auth.uid() and public.is_relief_partner()) or public.is_approved_authority()) with check((owner_id=auth.uid() and public.is_relief_partner()) or public.is_approved_authority());
create policy volunteers_partner_owner_or_authority on public.volunteers for all to authenticated using((owner_id=auth.uid() and public.is_relief_partner()) or public.is_approved_authority()) with check((owner_id=auth.uid() and public.is_relief_partner()) or public.is_approved_authority());
create policy vehicles_partner_owner_or_authority on public.vehicles for all to authenticated using((owner_id=auth.uid() and public.is_relief_partner()) or public.is_approved_authority()) with check((owner_id=auth.uid() and public.is_relief_partner()) or public.is_approved_authority());
create policy allocations_authority_only on public.resource_allocations for all to authenticated using(public.is_approved_authority()) with check(public.is_approved_authority());
create policy status_history_owner_authority on public.status_history for select to authenticated using(public.is_approved_authority() or (entity_table='incidents' and exists(select 1 from public.incidents i where i.id=entity_id and i.reporter_id=auth.uid())) or (entity_table='assistance_requests' and exists(select 1 from public.assistance_requests a where a.id=entity_id and a.requester_id=auth.uid())));
create policy audit_authority_read on public.audit_events for select to authenticated using(public.is_approved_authority());
create policy notification_owner on public.notifications for select to authenticated using(recipient_id=auth.uid());

-- Demo dataset is intentionally not exposed via this live schema. No production demo seeding or demo write endpoint exists.

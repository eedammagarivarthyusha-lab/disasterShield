-- Safe auth/profile upgrade: preserves existing profiles and fills only missing rows.
-- Authority requests remain pending and cannot grant themselves approval.

alter table public.profiles add column if not exists privacy_accepted_at timestamptz;
alter table public.profiles add column if not exists privacy_notice_version text;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  requested text := coalesce(new.raw_user_meta_data->>'requested_role', 'citizen');
  assigned_role public.app_role;
begin
  assigned_role := case
    when requested = 'relief_partner' then 'relief_partner'::public.app_role
    when requested = 'authority' then 'authority'::public.app_role
    else 'citizen'::public.app_role
  end;
  if assigned_role = 'authority' and (
    nullif(trim(new.raw_user_meta_data->>'organization'), '') is null or
    nullif(trim(new.raw_user_meta_data->>'justification'), '') is null
  ) then
    raise exception 'Authority applicants must provide organization and justification';
  end if;
  insert into public.profiles(id, display_name, role, authority_state)
  values (
    new.id,
    nullif(trim(new.raw_user_meta_data->>'full_name'), ''),
    assigned_role,
    case when assigned_role = 'authority' then 'pending'::public.authority_state else 'not_applied'::public.authority_state end
  ) on conflict (id) do nothing;

  if assigned_role = 'authority' then
    insert into public.authority_applications(user_id, organization, justification)
    values (
      new.id,
      nullif(trim(new.raw_user_meta_data->>'organization'), ''),
      nullif(trim(new.raw_user_meta_data->>'justification'), '')
    );
  end if;
  update public.profiles
  set privacy_accepted_at = now(), privacy_notice_version = '2026-10-22'
  where id = new.id and new.raw_user_meta_data->>'privacy_consent' = 'true';
  return new;
end;
$$;

-- Existing auth users without profiles become ordinary citizens; no auth metadata can grant authority.
insert into public.profiles(id, display_name, role, authority_state)
select u.id, nullif(trim(u.raw_user_meta_data->>'full_name'), ''), 'citizen', 'not_applied'
from auth.users u
on conflict (id) do nothing;

-- Users may edit only their display name. Role/approval state remains operator-controlled.
revoke update on public.profiles from authenticated;
grant update(display_name) on public.profiles to authenticated;
create policy profile_update_display_name_self
on public.profiles for update to authenticated
using (id = auth.uid()) with check (id = auth.uid());

create or replace function public.protect_profile_authorization_fields()
returns trigger language plpgsql set search_path = public, pg_temp as $$
begin
  if current_user not in ('postgres', 'supabase_admin', 'service_role') and
     (new.role is distinct from old.role or new.authority_state is distinct from old.authority_state or new.id is distinct from old.id) then
    raise exception 'Profile role and authority approval are operator-managed';
  end if;
  new.updated_at := now();
  return new;
end;
$$;
create trigger protect_profile_authorization_fields
before update on public.profiles
for each row execute function public.protect_profile_authorization_fields();

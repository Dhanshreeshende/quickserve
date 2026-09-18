-- QuickServe Supabase schema
-- Run in the Supabase SQL editor after enabling the auth schema.

create extension if not exists pgcrypto;

do $$ begin
  create type public.app_role as enum ('CUSTOMER', 'AGENT', 'ADMIN');
exception when duplicate_object then null; end $$;
do $$ begin
  create type public.request_priority as enum ('LOW', 'MEDIUM', 'HIGH');
exception when duplicate_object then null; end $$;
do $$ begin
  create type public.request_status as enum ('CREATED', 'ASSIGNED', 'ACCEPTED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED');
exception when duplicate_object then null; end $$;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  email text not null unique,
  phone text,
  role public.app_role not null default 'CUSTOMER',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.services (
  id uuid primary key default gen_random_uuid(),
  service_key text not null unique check (service_key in ('ac', 'plumbing', 'electrical', 'cleaning')),
  name text not null,
  description text not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create sequence if not exists public.quickserve_request_number_seq;

create table if not exists public.service_requests (
  id uuid primary key default gen_random_uuid(),
  request_number bigint not null unique default nextval('public.quickserve_request_number_seq'),
  request_id text not null unique,
  customer_id uuid not null references public.profiles(id),
  service_key text not null references public.services(service_key),
  agent_id uuid references public.profiles(id),
  description text not null check (char_length(description) between 1 and 2000),
  preferred_date date not null,
  preferred_time text not null,
  address text not null check (char_length(address) between 5 and 500),
  priority public.request_priority not null default 'MEDIUM',
  status public.request_status not null default 'CREATED',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.request_status_history (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.service_requests(id) on delete cascade,
  old_status public.request_status,
  new_status public.request_status not null,
  changed_by uuid not null references public.profiles(id),
  note text,
  created_at timestamptz not null default now()
);

create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id),
  event_type text not null check (event_type in ('LOGIN_SUCCESS', 'REQUEST_CREATED', 'REQUEST_ASSIGNED', 'REQUEST_UPDATED', 'AUTHORIZATION_FAILED', 'DATABASE_ERROR')),
  entity_type text not null,
  entity_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  token text not null,
  platform text not null check (platform in ('ios', 'android')),
  updated_at timestamptz not null default now(),
  unique (user_id, token)
);

create table if not exists public.analytics_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete set null,
  event_name text not null check (char_length(event_name) between 1 and 80),
  properties jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now()
);

create index if not exists service_requests_customer_idx on public.service_requests(customer_id);
create index if not exists service_requests_agent_idx on public.service_requests(agent_id);
create index if not exists service_requests_status_idx on public.service_requests(status);
create index if not exists service_requests_created_idx on public.service_requests(created_at desc);
create index if not exists service_requests_request_id_idx on public.service_requests(request_id);
create index if not exists audit_logs_created_idx on public.audit_logs(created_at desc);
create index if not exists analytics_events_occurred_idx on public.analytics_events(occurred_at desc);

create or replace function public.set_request_id()
returns trigger language plpgsql as $$
begin
  if new.request_id is null or new.request_id = '' then
    new.request_id := 'REQ-' || extract(year from coalesce(new.created_at, now()))::text || '-' || lpad(new.request_number::text, 6, '0');
  end if;
  return new;
end;
$$;

drop trigger if exists service_request_request_id on public.service_requests;
create trigger service_request_request_id before insert on public.service_requests for each row execute function public.set_request_id();

create or replace function public.app_current_role()
returns public.app_role language sql stable security definer set search_path = public
as $$ select role from public.profiles where id = auth.uid() $$;

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public
as $$ select public.app_current_role() = 'ADMIN'::public.app_role $$;

create or replace function public.is_agent()
returns boolean language sql stable security definer set search_path = public
as $$ select public.app_current_role() = 'AGENT'::public.app_role $$;

create or replace function public.update_request_status(p_request_id text, p_new_status public.request_status, p_note text default null)
returns uuid language plpgsql security invoker set search_path = public
as $$
declare
  request_row public.service_requests;
  allowed boolean := false;
begin
  select * into request_row from public.service_requests where request_id = p_request_id for update;
  if request_row.id is null then raise exception 'REQUEST_NOT_FOUND'; end if;
  if public.is_admin() then allowed := true;
  elsif public.is_agent() and request_row.agent_id = auth.uid() then allowed := true;
  elsif request_row.customer_id = auth.uid() and p_new_status = 'CANCELLED' and request_row.status in ('CREATED', 'ASSIGNED') then allowed := true;
  end if;
  if not allowed then raise exception 'AUTHORIZATION_FAILED'; end if;
  if not ((request_row.status = 'CREATED' and p_new_status = 'ASSIGNED') or (request_row.status = 'ASSIGNED' and p_new_status = 'ACCEPTED') or (request_row.status = 'ACCEPTED' and p_new_status = 'IN_PROGRESS') or (request_row.status = 'IN_PROGRESS' and p_new_status = 'COMPLETED') or (request_row.status in ('CREATED', 'ASSIGNED') and p_new_status = 'CANCELLED')) then
    raise exception 'INVALID_STATUS_TRANSITION';
  end if;
  update public.service_requests set status = p_new_status, updated_at = now() where id = request_row.id;
  insert into public.request_status_history(request_id, old_status, new_status, changed_by, note) values (request_row.id, request_row.status, p_new_status, auth.uid(), p_note);
  insert into public.audit_logs(user_id, event_type, entity_type, entity_id, metadata) values (auth.uid(), 'REQUEST_UPDATED', 'service_request', request_row.id, jsonb_build_object('old_status', request_row.status, 'new_status', p_new_status));
  return request_row.id;
end;
$$;

create or replace function public.assign_request_agent(p_request_id text, p_agent_id uuid)
returns uuid language plpgsql security invoker set search_path = public
as $$
declare
  request_row public.service_requests;
begin
  if not public.is_admin() then raise exception 'AUTHORIZATION_FAILED'; end if;
  if not exists (select 1 from public.profiles where id = p_agent_id and role = 'AGENT') then raise exception 'INVALID_AGENT'; end if;
  select * into request_row from public.service_requests where request_id = p_request_id for update;
  if request_row.id is null then raise exception 'REQUEST_NOT_FOUND'; end if;
  update public.service_requests set agent_id = p_agent_id, status = case when status = 'CREATED' then 'ASSIGNED' else status end, updated_at = now() where id = request_row.id;
  insert into public.request_status_history(request_id, old_status, new_status, changed_by, note) select request_row.id, request_row.status, 'ASSIGNED', auth.uid(), 'Agent assigned' where request_row.status = 'CREATED';
  insert into public.audit_logs(user_id, event_type, entity_type, entity_id, metadata) values (auth.uid(), 'REQUEST_ASSIGNED', 'service_request', request_row.id, jsonb_build_object('agent_id', p_agent_id));
  return request_row.id;
end;
$$;

alter table public.profiles enable row level security;
alter table public.services enable row level security;
alter table public.service_requests enable row level security;
alter table public.request_status_history enable row level security;
alter table public.audit_logs enable row level security;

create policy "profiles_self_or_admin_select" on public.profiles for select using (id = auth.uid() or public.is_admin());
create policy "profiles_self_update_safe" on public.profiles for update using (id = auth.uid()) with check (id = auth.uid() and role = public.app_current_role());
create policy "services_authenticated_read" on public.services for select to authenticated using (active = true or public.is_admin());
create policy "customer_own_requests" on public.service_requests for select using (customer_id = auth.uid() or (public.is_agent() and agent_id = auth.uid()) or public.is_admin());
create policy "customer_create_requests" on public.service_requests for insert with check (customer_id = auth.uid() and status = 'CREATED');
create policy "admin_assign_requests" on public.service_requests for update using (public.is_admin()) with check (public.is_admin());
create policy "agent_update_assigned_requests" on public.service_requests for update using (public.is_agent() and agent_id = auth.uid()) with check (public.is_agent() and agent_id = auth.uid());
create policy "customer_cancel_own_requests" on public.service_requests for update using (customer_id = auth.uid() and status in ('CREATED', 'ASSIGNED')) with check (customer_id = auth.uid() and status = 'CANCELLED');
create policy "request_history_visible_to_participants" on public.request_status_history for select using (exists (select 1 from public.service_requests r where r.id = request_id and (r.customer_id = auth.uid() or r.agent_id = auth.uid() or public.is_admin())));
create policy "admin_audit_read" on public.audit_logs for select using (public.is_admin());
create policy "own_device_tokens" on public.device_tokens for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "own_analytics_insert" on public.analytics_events for insert with check (user_id = auth.uid() or user_id is null);
create policy "admin_analytics_read" on public.analytics_events for select using (public.is_admin());

do $$ begin
  alter publication supabase_realtime add table public.service_requests;
  alter publication supabase_realtime add table public.request_status_history;
  alter publication supabase_realtime add table public.audit_logs;
exception when duplicate_object then null; end $$;

insert into public.services(service_key, name, description) values
  ('ac', 'AC servicing', 'Keep your cooling system running at its best.'),
  ('plumbing', 'Plumbing', 'Leaks, fittings, blockages and more.'),
  ('electrical', 'Electrical', 'Safe, certified help for every circuit.'),
  ('cleaning', 'Home cleaning', 'A brighter, fresher space—without the hassle.')
on conflict (service_key) do nothing;

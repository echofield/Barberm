-- Barberm v0 data model
-- PostgreSQL-compatible. Demo contract for the future live backend.

create extension if not exists pgcrypto;

create table salons (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  timezone text not null default 'Europe/Paris',
  currency text not null default 'EUR',
  booking_provider text,
  booking_location_id text,
  created_at timestamptz not null default now()
);

create table barbers (
  id uuid primary key default gen_random_uuid(),
  salon_id uuid not null references salons(id) on delete cascade,
  name text not null,
  booking_provider_id text,
  active boolean not null default true,
  specialties text[] not null default '{}',
  created_at timestamptz not null default now()
);

create table clients (
  id uuid primary key default gen_random_uuid(),
  salon_id uuid not null references salons(id) on delete cascade,
  first_name text,
  last_name text,
  phone text,
  email text,
  birthday date,
  marketing_consent boolean not null default false,
  created_at timestamptz not null default now(),
  unique(salon_id, phone),
  unique(salon_id, email)
);

create table visits (
  id uuid primary key default gen_random_uuid(),
  salon_id uuid not null references salons(id) on delete cascade,
  client_id uuid not null references clients(id) on delete cascade,
  barber_id uuid references barbers(id) on delete set null,
  occurred_at timestamptz not null,
  service_name text,
  gross_amount_cents integer check (gross_amount_cents >= 0),
  booking_provider_id text,
  created_at timestamptz not null default now()
);

create table bookings (
  id uuid primary key default gen_random_uuid(),
  salon_id uuid not null references salons(id) on delete cascade,
  client_id uuid references clients(id) on delete set null,
  barber_id uuid references barbers(id) on delete set null,
  starts_at timestamptz not null,
  status text not null check (status in ('booked','completed','cancelled','no_show')),
  source text not null default 'booking_provider',
  source_action_id uuid,
  booking_provider_id text,
  created_at timestamptz not null default now()
);

create table passports (
  id uuid primary key default gen_random_uuid(),
  salon_id uuid not null references salons(id) on delete cascade,
  client_id uuid not null references clients(id) on delete cascade,
  last_visit_id uuid references visits(id) on delete set null,
  barber_id uuid references barbers(id) on delete set null,
  style_name text,
  style_details text,
  photo_url text,
  visit_count integer not null default 0,
  updated_at timestamptz not null default now(),
  unique(salon_id, client_id)
);

create table rewards (
  id uuid primary key default gen_random_uuid(),
  salon_id uuid not null references salons(id) on delete cascade,
  client_id uuid not null references clients(id) on delete cascade,
  kind text not null,
  threshold integer,
  progress integer not null default 0,
  status text not null default 'progress' check (status in ('progress','available','redeemed','expired')),
  available_at timestamptz,
  redeemed_at timestamptz,
  created_at timestamptz not null default now()
);

create table referrals (
  id uuid primary key default gen_random_uuid(),
  salon_id uuid not null references salons(id) on delete cascade,
  referrer_client_id uuid not null references clients(id) on delete cascade,
  invited_client_id uuid references clients(id) on delete set null,
  code text not null unique,
  status text not null default 'opened' check (status in ('opened','booked','converted','expired')),
  created_at timestamptz not null default now(),
  converted_at timestamptz
);

create table chair_draws (
  id uuid primary key default gen_random_uuid(),
  salon_id uuid not null references salons(id) on delete cascade,
  scheduled_for timestamptz not null,
  winner_client_id uuid references clients(id) on delete set null,
  status text not null default 'open' check (status in ('open','drawn','booked','completed','cancelled')),
  seat_cost_cents integer,
  influenced_bookings integer not null default 0,
  created_at timestamptz not null default now()
);

create table chair_entries (
  draw_id uuid not null references chair_draws(id) on delete cascade,
  client_id uuid not null references clients(id) on delete cascade,
  entered_at timestamptz not null default now(),
  primary key(draw_id, client_id)
);

create table retention_actions (
  id uuid primary key default gen_random_uuid(),
  salon_id uuid not null references salons(id) on delete cascade,
  client_id uuid references clients(id) on delete cascade,
  action_type text not null check (action_type in ('reactivation','reward_reminder','referral_followup','chair_offer','manual')),
  channel text check (channel in ('sms','email','whatsapp','push','manual')),
  status text not null default 'draft' check (status in ('draft','scheduled','sent','cancelled')),
  reason jsonb not null default '{}',
  estimated_value_cents integer,
  sent_at timestamptz,
  created_at timestamptz not null default now()
);

create table attribution_events (
  id uuid primary key default gen_random_uuid(),
  salon_id uuid not null references salons(id) on delete cascade,
  client_id uuid references clients(id) on delete set null,
  action_id uuid references retention_actions(id) on delete set null,
  booking_id uuid references bookings(id) on delete set null,
  event_type text not null check (event_type in ('passport_rebook','reactivation_booking','reward_booking','referral_booking','chair_booking')),
  value_cents integer,
  occurred_at timestamptz not null default now()
);

create index visits_client_time_idx on visits(client_id, occurred_at desc);
create index bookings_salon_time_idx on bookings(salon_id, starts_at);
create index bookings_client_time_idx on bookings(client_id, starts_at desc);
create index actions_salon_status_idx on retention_actions(salon_id, status, created_at desc);
create index attribution_salon_time_idx on attribution_events(salon_id, occurred_at desc);

-- Core dashboard logic, conceptually:
-- 1. infer each client's usual return interval from visits;
-- 2. exclude clients with an upcoming booking;
-- 3. rank overdue clients by timing x historical ticket x likelihood to return;
-- 4. suggest an action, never claim revenue until a booking/visit is attributed;
-- 5. use occupancy to place The Chair only in weak inventory windows.

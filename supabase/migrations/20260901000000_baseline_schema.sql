




















create extension if not exists pgcrypto;

create table if not exists public.stations (
  id uuid not null default gen_random_uuid(),
  name text not null,
  line text not null,
  lat double precision not null,
  lng double precision not null,
  created_at timestamp with time zone default now(),
  constraint stations_pkey primary key (id)
);

create table if not exists public.timetable_entries (
  id uuid not null default gen_random_uuid(),
  station_id uuid,
  line text not null,
  scheduled_time time without time zone not null,
  direction text not null,
  constraint timetable_entries_pkey primary key (id),
  constraint timetable_entries_station_id_fkey
    foreign key (station_id) references public.stations(id)
);

create table if not exists public.train_status (
  id uuid not null default gen_random_uuid(),
  station_id uuid,
  line text not null,
  trip_id text,
  scheduled_time timestamp with time zone not null,
  actual_time timestamp with time zone,
  delay_minutes integer,
  recorded_at timestamp with time zone default now(),
  constraint train_status_pkey primary key (id),
  constraint train_status_station_id_fkey
    foreign key (station_id) references public.stations(id)
);




create table if not exists public.ride_logs (
  id uuid not null default gen_random_uuid(),
  user_id uuid,
  station_id uuid,
  detected_at timestamp with time zone default now(),
  delay_minutes integer,
  destination_station_id uuid,
  duration_minutes integer,
  constraint ride_logs_pkey primary key (id),
  constraint ride_logs_user_id_fkey
    foreign key (user_id) references auth.users(id),
  constraint ride_logs_station_id_fkey
    foreign key (station_id) references public.stations(id),
  constraint ride_logs_destination_station_id_fkey
    foreign key (destination_station_id) references public.stations(id)
);

create table if not exists public.saved_stations (
  id uuid not null default gen_random_uuid(),
  user_id uuid,
  station_id uuid,
  alert_delay_threshold integer,
  quiet_hours_start time without time zone,
  quiet_hours_end time without time zone,
  active_days text[],
  created_at timestamp with time zone default now(),
  enabled boolean default true,
  constraint saved_stations_pkey primary key (id),
  constraint saved_stations_user_id_fkey
    foreign key (user_id) references auth.users(id),
  constraint saved_stations_station_id_fkey
    foreign key (station_id) references public.stations(id)
);



create table if not exists public.saved_routes (
  id uuid not null default gen_random_uuid(),
  user_id uuid,
  origin_station_id uuid,
  destination_station_id uuid,
  created_at timestamp with time zone default now(),
  walking_minutes integer default 10,
  constraint saved_routes_pkey primary key (id),
  constraint saved_routes_user_id_fkey
    foreign key (user_id) references auth.users(id),
  constraint saved_routes_origin_station_id_fkey
    foreign key (origin_station_id) references public.stations(id),
  constraint saved_routes_destination_station_id_fkey
    foreign key (destination_station_id) references public.stations(id)
);

create table if not exists public.mute_settings (
  user_id uuid not null,
  muted_until date,
  updated_at timestamp with time zone default now(),
  constraint mute_settings_pkey primary key (user_id),
  constraint mute_settings_user_id_fkey
    foreign key (user_id) references auth.users(id)
);

create table if not exists public.fault_reports (
  id uuid not null default gen_random_uuid(),
  user_id uuid,
  station_id uuid,
  issue_type text not null,
  description text,
  photo_url text,
  lat double precision,
  lng double precision,
  status text default 'open'::text,
  created_at timestamp with time zone default now(),
  constraint fault_reports_pkey primary key (id),
  constraint fault_reports_user_id_fkey
    foreign key (user_id) references auth.users(id),
  constraint fault_reports_station_id_fkey
    foreign key (station_id) references public.stations(id)
);

create table if not exists public.profiles (
  id uuid not null,
  username text not null,
  created_at timestamp with time zone default now(),
  constraint profiles_pkey primary key (id),
  constraint profiles_username_key unique (username),
  constraint profiles_id_fkey foreign key (id) references auth.users(id)
);





create or replace view public.station_accessibility as
select distinct on (station_id, issue_type)
  station_id, issue_type, status, created_at
from public.fault_reports
order by station_id, issue_type, created_at desc;



alter view public.station_accessibility set (security_invoker = true);




insert into storage.buckets (id, name, public)
values ('report-photos', 'report-photos', true)
on conflict (id) do nothing;

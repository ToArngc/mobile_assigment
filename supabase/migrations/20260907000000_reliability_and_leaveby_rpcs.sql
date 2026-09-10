create or replace function public.reliability_stats(
  p_station_id uuid default null,
  p_line text default null,
  p_days int default 7
)
returns table (
  total_trips bigint,
  on_time_trips bigint,
  on_time_percentage numeric,
  average_delay_minutes numeric,
  days_of_data bigint
)
language sql
stable
as $$
  select
    count(*) as total_trips,
    count(*) filter (where delay_minutes <= 5) as on_time_trips,
    case when count(*) = 0 then null
      else round((count(*) filter (where delay_minutes <= 5))::numeric / count(*) * 100, 1)
    end as on_time_percentage,
    case when count(*) = 0 then null
      else round(avg(delay_minutes)::numeric, 1)
    end as average_delay_minutes,
    count(distinct (recorded_at at time zone 'Asia/Kuala_Lumpur')::date) as days_of_data
  from public.train_status
  where delay_minutes is not null
    and recorded_at >= now() - (p_days::text || ' days')::interval
    and (p_station_id is null or station_id = p_station_id)
    and (p_line is null or line = p_line)
$$;

create or replace function public.reliability_stats_by_station(
  p_station_ids uuid[],
  p_days int default 7
)
returns table (
  station_id uuid,
  total_trips bigint,
  on_time_trips bigint,
  on_time_percentage numeric,
  average_delay_minutes numeric,
  days_of_data bigint
)
language sql
stable
as $$
  select
    t.station_id,
    count(*) as total_trips,
    count(*) filter (where t.delay_minutes <= 5) as on_time_trips,
    round((count(*) filter (where t.delay_minutes <= 5))::numeric / count(*) * 100, 1) as on_time_percentage,
    round(avg(t.delay_minutes)::numeric, 1) as average_delay_minutes,
    count(distinct (t.recorded_at at time zone 'Asia/Kuala_Lumpur')::date) as days_of_data
  from public.train_status t
  where t.delay_minutes is not null
    and t.recorded_at >= now() - (p_days::text || ' days')::interval
    and t.station_id = any(p_station_ids)
  group by t.station_id
$$;

create or replace function public.reliability_stats_by_station_line(
  p_station_ids uuid[],
  p_days int default 7
)
returns table (
  station_id uuid,
  line text,
  total_trips bigint,
  on_time_trips bigint,
  on_time_percentage numeric,
  average_delay_minutes numeric,
  days_of_data bigint
)
language sql
stable
as $$
  select
    t.station_id,
    t.line,
    count(*) as total_trips,
    count(*) filter (where t.delay_minutes <= 5) as on_time_trips,
    round((count(*) filter (where t.delay_minutes <= 5))::numeric / count(*) * 100, 1) as on_time_percentage,
    round(avg(t.delay_minutes)::numeric, 1) as average_delay_minutes,
    count(distinct (t.recorded_at at time zone 'Asia/Kuala_Lumpur')::date) as days_of_data
  from public.train_status t
  where t.delay_minutes is not null
    and t.recorded_at >= now() - (p_days::text || ' days')::interval
    and t.station_id = any(p_station_ids)
  group by t.station_id, t.line
$$;

create or replace function public.avg_recent_delay_minutes(
  p_station_id uuid,
  p_limit int default 30
)
returns table (
  has_data boolean,
  avg_delay_minutes numeric,
  sample_size int
)
language sql
stable
as $$
  select
    count(*) > 0 as has_data,
    coalesce(round(avg(delay_minutes)::numeric, 1), 0) as avg_delay_minutes,
    count(*)::int as sample_size
  from (
    select delay_minutes
    from public.train_status
    where station_id = p_station_id
      and delay_minutes is not null
    order by recorded_at desc
    limit p_limit
  ) recent
$$;

grant execute on function public.reliability_stats(uuid, text, int) to service_role;
grant execute on function public.reliability_stats_by_station(uuid[], int) to service_role;
grant execute on function public.reliability_stats_by_station_line(uuid[], int) to service_role;
grant execute on function public.avg_recent_delay_minutes(uuid, int) to service_role;

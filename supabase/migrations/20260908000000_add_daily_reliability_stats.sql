create or replace function public.get_daily_reliability_stats(
  p_station_id uuid default null,
  p_line text default null,
  p_days int default 7
)
returns table (
  day date,
  total_trips bigint,
  on_time_trips bigint,
  on_time_percentage numeric,
  average_delay_minutes numeric
)
language sql
stable
as $$
  select
    (recorded_at at time zone 'Asia/Kuala_Lumpur')::date as day,
    count(*) as total_trips,
    count(*) filter (where delay_minutes <= 5) as on_time_trips,
    round((count(*) filter (where delay_minutes <= 5))::numeric / count(*) * 100, 1) as on_time_percentage,
    round(avg(delay_minutes)::numeric, 1) as average_delay_minutes
  from public.train_status
  where delay_minutes is not null
    and recorded_at >= now() - (p_days::text || ' days')::interval
    and (p_station_id is null or station_id = p_station_id)
    and (p_line is null or line = p_line)
  group by (recorded_at at time zone 'Asia/Kuala_Lumpur')::date
  order by day asc
$$;

grant execute on function public.get_daily_reliability_stats(uuid, text, int) to service_role;

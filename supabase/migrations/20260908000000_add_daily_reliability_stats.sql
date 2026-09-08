-- Day-by-day reliability RPC backing get-reliability-trend.
--
-- Same "on-time" definition and NULL-coalescing filter logic as
-- reliability_stats() in 20260907000000_reliability_and_leaveby_rpcs.sql:
-- delay_minutes <= 5, matching reliability_repository.dart's
-- onTimeThresholdMinutes. p_station_id/p_line are nullable (mirroring
-- reliability_stats' own signature) so a network-wide daily series is
-- possible at the SQL layer, but get-reliability-trend's Edge Function
-- still requires at least one filter at the HTTP layer, same as
-- get-reliability-stats — see that function's validation.
--
-- Days with zero matching trips are omitted entirely rather than returned
-- as a zero-row: the GROUP BY only ever emits a row for a day that had
-- >=1 trip matching the WHERE clause, so every returned row already has
-- total_trips > 0 and on_time_percentage/average_delay_minutes are never
-- null. Callers should treat a missing date as "no data that day".

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

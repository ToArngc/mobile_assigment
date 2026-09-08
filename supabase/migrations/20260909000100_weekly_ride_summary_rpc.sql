-- Task 5 — weekly ride summary, aggregated in Postgres.
--
-- ride_logs.delay_minutes is never populated (design doc §4): when a ride
-- is detected in the foreground the pipeline may not have polled that
-- trip yet, so logging a delay then would write a permanent null. Delay is
-- therefore resolved at READ time, here, by matching each ride to the
-- nearest train_status reading at the same station.
--
-- The aggregation lives in SQL rather than in the Edge Function or in Dart
-- so there is exactly one place the on-time rule is applied.
--
-- ASSUMPTION — p_tolerance. The fix task specified "nearest recorded_at"
-- with no bound, which on its own would let a ride match a reading from
-- hours earlier. 60 minutes is used as the default window: wide enough to
-- absorb the pipeline's polling gap, narrow enough that a match still
-- describes the same journey. Change it in one place if the team disagrees.

create or replace function public.weekly_ride_summary(
  p_user_id uuid,
  p_since timestamptz,
  p_threshold integer default 5,
  p_tolerance interval default interval '60 minutes'
)
returns table (
  ride_count integer,
  on_time_count integer,
  on_time_percentage numeric,
  avg_delay_minutes numeric,
  rides jsonb
)
language sql
stable
as $$
  with matched as (
    select
      r.id,
      r.detected_at,
      s.name as station_name,
      (
        select ts.delay_minutes
        from public.train_status ts
        where ts.station_id = r.station_id
          and ts.delay_minutes is not null
          and ts.recorded_at between r.detected_at - p_tolerance
                                 and r.detected_at + p_tolerance
        order by abs(extract(epoch from (ts.recorded_at - r.detected_at)))
        limit 1
      ) as delay_minutes
    from public.ride_logs r
    left join public.stations s on s.id = r.station_id
    where r.user_id = p_user_id
      and r.detected_at >= p_since
  )
  select
    count(*)::integer as ride_count,
    (count(*) filter (where delay_minutes <= p_threshold))::integer
      as on_time_count,
    -- Percentage and average are over MATCHED rides only, and are null
    -- when nothing matched. A user with rides but no train_status data
    -- must see "not enough data", never a misleading 0%.
    case when count(delay_minutes) = 0 then null
      else round(
        (count(*) filter (where delay_minutes <= p_threshold))::numeric
          * 100 / count(delay_minutes), 1)
    end as on_time_percentage,
    case when count(delay_minutes) = 0 then null
      else round(avg(delay_minutes)::numeric, 1)
    end as avg_delay_minutes,
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'station_name', station_name,
          'detected_at', detected_at,
          'delay_minutes', delay_minutes
        ) order by detected_at
      ) filter (where id is not null),
      '[]'::jsonb
    ) as rides
  from matched;
$$;

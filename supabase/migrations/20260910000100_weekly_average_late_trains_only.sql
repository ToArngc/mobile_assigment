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
    case when count(delay_minutes) = 0 then null
      else round(
        (count(*) filter (where delay_minutes <= p_threshold))::numeric
          * 100 / count(delay_minutes), 1)
    end as on_time_percentage,
    case when count(delay_minutes) = 0 then null
      else coalesce(
        round(
          (avg(delay_minutes) filter (where delay_minutes > 0))::numeric,
          1
        ),
        0
      )
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

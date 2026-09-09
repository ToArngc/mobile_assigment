-- Reliability queries all filter train_status by recency and then by station or
-- line (see get-reliability-stats / get-network-reliability-stats and the
-- avg_recent_delay_minutes RPC). Without this the planner sequential-scans the
-- whole table on every dashboard load.

create index if not exists train_status_recorded_at_station_line_idx
  on public.train_status (recorded_at desc, station_id, line);

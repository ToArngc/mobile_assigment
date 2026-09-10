create index if not exists train_status_recorded_at_station_line_idx
  on public.train_status (recorded_at desc, station_id, line);

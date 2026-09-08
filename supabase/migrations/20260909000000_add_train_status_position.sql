










alter table public.train_status
  add column if not exists lat double precision,
  add column if not exists lng double precision;

-- Task 1 — store the real vehicle position on each arrival event.
--
-- The GTFS-Realtime feed returns position { latitude, longitude } on every
-- vehicle reading. The pipeline already reads it for arrival detection and
-- then threw it away, so Module 1's live schematic had nothing to place a
-- train icon from. These two columns keep it.
--
-- Both are nullable and there is no backfill: rows written before this
-- migration keep null lat/lng, and every reader must skip those rather
-- than assume a position exists.

alter table public.train_status
  add column if not exists lat double precision,
  add column if not exists lng double precision;

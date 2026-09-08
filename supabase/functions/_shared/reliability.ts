// Shared on-time-reliability aggregation logic. Both get-reliability-stats
// and get-route-suggestions import this directly (a plain function call,
// not an HTTP round-trip to another function) so the two never disagree on
// how "on-time %" is computed, and so route-suggestions can fetch stats for
// every station it needs in ONE batched query instead of looping per route.
//
// All aggregation (COUNT/AVG/GROUP BY) happens in Postgres via the RPC
// functions defined in supabase/migrations/ — never fetch-then-loop in TS.

import { SupabaseClient } from "jsr:@supabase/supabase-js@2";

export const ON_TIME_THRESHOLD_MINUTES = 5; // must match onTimeThresholdMinutes in lib/core/constants.dart

export interface ReliabilityStats {
  totalTrips: number;
  onTimeTrips: number;
  onTimePercentage: number | null; // null when insufficient data
  averageDelayMinutes: number | null; // null when insufficient data
  daysOfData: number;
  insufficientData: boolean;
}

interface RawStatsRow {
  total_trips: number | string;
  on_time_trips: number | string;
  on_time_percentage: number | string | null;
  average_delay_minutes: number | string | null;
  days_of_data: number | string;
}

function toStats(row: RawStatsRow | null | undefined): ReliabilityStats {
  const totalTrips = row ? Number(row.total_trips) : 0;
  return {
    totalTrips,
    onTimeTrips: row ? Number(row.on_time_trips) : 0,
    onTimePercentage:
      row && row.on_time_percentage !== null ? Number(row.on_time_percentage) : null,
    averageDelayMinutes:
      row && row.average_delay_minutes !== null ? Number(row.average_delay_minutes) : null,
    daysOfData: row ? Number(row.days_of_data) : 0,
    insufficientData: totalTrips === 0,
  };
}

/** Stats for a single station/line filter (or system-wide if both are omitted). */
export async function getReliabilityStats(
  supabase: SupabaseClient,
  params: { stationId?: string | null; line?: string | null; days: number },
): Promise<ReliabilityStats> {
  const { data, error } = await supabase.rpc("reliability_stats", {
    p_station_id: params.stationId ?? null,
    p_line: params.line ?? null,
    p_days: params.days,
  });
  if (error) throw error;
  const row = Array.isArray(data) ? data[0] : data;
  return toStats(row as RawStatsRow);
}

/** Stats grouped by station_id, for a batch of stations, in a single query. */
export async function getReliabilityStatsByStation(
  supabase: SupabaseClient,
  params: { stationIds: string[]; days: number },
): Promise<Map<string, ReliabilityStats>> {
  const result = new Map<string, ReliabilityStats>();
  if (params.stationIds.length === 0) return result;

  const { data, error } = await supabase.rpc("reliability_stats_by_station", {
    p_station_ids: params.stationIds,
    p_days: params.days,
  });
  if (error) throw error;

  for (const row of (data ?? []) as (RawStatsRow & { station_id: string })[]) {
    result.set(row.station_id, toStats(row));
  }
  return result;
}

/** Stats grouped by (station_id, line), for a batch of stations, in a single query. */
export async function getReliabilityStatsByStationLine(
  supabase: SupabaseClient,
  params: { stationIds: string[]; days: number },
): Promise<Map<string, Map<string, ReliabilityStats>>> {
  const result = new Map<string, Map<string, ReliabilityStats>>();
  if (params.stationIds.length === 0) return result;

  const { data, error } = await supabase.rpc("reliability_stats_by_station_line", {
    p_station_ids: params.stationIds,
    p_days: params.days,
  });
  if (error) throw error;

  for (const row of (data ?? []) as (RawStatsRow & { station_id: string; line: string })[]) {
    if (!result.has(row.station_id)) result.set(row.station_id, new Map());
    result.get(row.station_id)!.set(row.line, toStats(row));
  }
  return result;
}

export interface DailyReliabilityStat {
  day: string; // date, e.g. "2026-09-01"
  totalTrips: number;
  onTimeTrips: number;
  onTimePercentage: number;
  averageDelayMinutes: number;
}

interface RawDailyStatsRow {
  day: string;
  total_trips: number | string;
  on_time_trips: number | string;
  on_time_percentage: number | string;
  average_delay_minutes: number | string;
}

/**
 * Day-by-day stats for a single station/line filter, ordered ascending by
 * day. The underlying RPC's GROUP BY only ever emits a row for a day that
 * had >=1 matching trip, so days with no data are simply absent from the
 * result rather than present with total_trips: 0 — callers should treat a
 * missing date as "no data that day".
 */
export async function getDailyReliabilityStats(
  supabase: SupabaseClient,
  params: { stationId?: string | null; line?: string | null; days: number },
): Promise<DailyReliabilityStat[]> {
  const { data, error } = await supabase.rpc("get_daily_reliability_stats", {
    p_station_id: params.stationId ?? null,
    p_line: params.line ?? null,
    p_days: params.days,
  });
  if (error) throw error;

  return ((data ?? []) as RawDailyStatsRow[]).map((row) => ({
    day: row.day,
    totalTrips: Number(row.total_trips),
    onTimeTrips: Number(row.on_time_trips),
    onTimePercentage: Number(row.on_time_percentage),
    averageDelayMinutes: Number(row.average_delay_minutes),
  }));
}

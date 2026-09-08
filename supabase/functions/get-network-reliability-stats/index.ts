// GET /get-network-reliability-stats?days=<int>
// Public. Network-wide counterpart to get-reliability-stats: identical
// aggregation via the same reliability_stats() RPC (which already supports
// NULL station_id/line for a system-wide result — see the migration that
// created it), just always called with no filter. Backs the Reliability
// Dashboard's default "all lines, all stations" view, replacing the
// client-side days-of-data derivation that used to read raw rows from
// get-recent-train-delays (see ReliabilityRepository.fetchDistinctDaysCount).
//
// station_id/line are always null in the response, unlike
// get-reliability-stats (which echoes back whatever filter it was given),
// so callers can tell the two apart at a glance.

import { handleOptions, jsonResponse, errorResponse } from "../_shared/cors.ts";
import { createAdminClient } from "../_shared/supabase-admin.ts";
import { getReliabilityStats, ON_TIME_THRESHOLD_MINUTES } from "../_shared/reliability.ts";

Deno.serve(async (req) => {
  const preflight = handleOptions(req);
  if (preflight) return preflight;

  if (req.method !== "GET") return errorResponse("Method not allowed", 405);

  const url = new URL(req.url);
  const daysParam = url.searchParams.get("days");
  const days = daysParam ? parseInt(daysParam, 10) : 7;

  if (Number.isNaN(days) || days <= 0) {
    return errorResponse("days must be a positive integer", 400);
  }

  const supabase = createAdminClient();

  try {
    const stats = await getReliabilityStats(supabase, { stationId: null, line: null, days });

    return jsonResponse({
      station_id: null,
      line: null,
      window_days: days,
      on_time_threshold_minutes: ON_TIME_THRESHOLD_MINUTES,
      total_trips: stats.totalTrips,
      on_time_trips: stats.onTimeTrips,
      on_time_percentage: stats.onTimePercentage,
      average_delay_minutes: stats.averageDelayMinutes,
      days_of_data: stats.daysOfData,
      insufficient_data: stats.insufficientData,
      message: stats.insufficientData
        ? `No train status data recorded network-wide in the last ${days} day(s).`
        : null,
    });
  } catch (err) {
    return errorResponse((err as Error).message, 500);
  }
});

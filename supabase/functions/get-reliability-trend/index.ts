// GET /get-reliability-trend?station_id=<uuid>&line=<string>&days=<int>
// Public. Day-by-day counterpart to get-reliability-stats: one row per
// calendar day instead of a single aggregated window, via the
// get_daily_reliability_stats() RPC (COUNT/AVG/GROUP BY day in Postgres,
// same 5-minute on-time threshold as get-reliability-stats). Backs the
// Reliability Dashboard's Trend Chart, replacing the client-side
// day-bucketing that used to run over get-recent-train-delays' raw rows
// (see ReliabilityRepository.fetchOnTimeStats).
//
// Same required-filter validation as get-reliability-stats: this is a
// per-station/line drill-down, not a network-wide series — see
// get-network-reliability-stats for the network-wide aggregate. The
// Dashboard's unfiltered "all lines, all stations" view has no per-day
// trend for the same reason it has no get-reliability-stats-backed number;
// the repository skips calling this endpoint entirely in that case rather
// than hitting this 400.
//
// Days with zero matching trips are omitted from the response entirely
// (not returned as a zero-row) — a sparse trend just has gaps in the
// dates, which callers should render as missing data rather than 0%.

import { handleOptions, jsonResponse, errorResponse } from "../_shared/cors.ts";
import { createAdminClient } from "../_shared/supabase-admin.ts";
import { getDailyReliabilityStats } from "../_shared/reliability.ts";

Deno.serve(async (req) => {
  const preflight = handleOptions(req);
  if (preflight) return preflight;

  if (req.method !== "GET") return errorResponse("Method not allowed", 405);

  const url = new URL(req.url);
  const stationId = url.searchParams.get("station_id");
  const line = url.searchParams.get("line");
  const daysParam = url.searchParams.get("days");
  const days = daysParam ? parseInt(daysParam, 10) : 7;

  if (!stationId && !line) {
    return errorResponse("station_id and/or line is required", 400);
  }
  if (Number.isNaN(days) || days <= 0) {
    return errorResponse("days must be a positive integer", 400);
  }

  const supabase = createAdminClient();

  try {
    const stats = await getDailyReliabilityStats(supabase, { stationId, line, days });

    return jsonResponse(
      stats.map((s) => ({
        day: s.day,
        total_trips: s.totalTrips,
        on_time_trips: s.onTimeTrips,
        on_time_percentage: s.onTimePercentage,
        average_delay_minutes: s.averageDelayMinutes,
      })),
    );
  } catch (err) {
    return errorResponse((err as Error).message, 500);
  }
});

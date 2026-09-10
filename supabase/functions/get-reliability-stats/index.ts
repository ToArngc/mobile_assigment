import { handleOptions, jsonResponse, errorResponse } from "../_shared/cors.ts";
import { createAdminClient } from "../_shared/supabase-admin.ts";
import { getReliabilityStats, ON_TIME_THRESHOLD_MINUTES } from "../_shared/reliability.ts";

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
    const stats = await getReliabilityStats(supabase, { stationId, line, days });

    return jsonResponse({
      station_id: stationId,
      line: line,
      window_days: days,
      on_time_threshold_minutes: ON_TIME_THRESHOLD_MINUTES,
      total_trips: stats.totalTrips,
      on_time_trips: stats.onTimeTrips,
      on_time_percentage: stats.onTimePercentage,
      average_delay_minutes: stats.averageDelayMinutes,
      days_of_data: stats.daysOfData,
      insufficient_data: stats.insufficientData,
      message: stats.insufficientData
        ? `No train status data recorded for this filter in the last ${days} day(s).`
        : null,
    });
  } catch (err) {
    return errorResponse((err as Error).message, 500);
  }
});

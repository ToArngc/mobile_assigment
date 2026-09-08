




















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

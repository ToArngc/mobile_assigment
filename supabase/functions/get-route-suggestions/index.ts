// GET /get-route-suggestions
// Joins the caller's saved_routes with the same reliability aggregation
// used by get-reliability-stats — imported directly from
// ../_shared/reliability.ts as plain function calls (no HTTP round-trip to
// another function), and each called ONCE with the full batch of distinct
// stations/lines involved, in a single grouped query per batch. This is
// the fix for the N+1 bug flagged in
// ReliabilityRepository.fetchRouteSuggestionCandidates, which issued two
// extra queries per saved route (plus more per alternate line).
//
// Status/verdict logic mirrors RouteSuggestion.status in
// reliability_repository.dart exactly: a live delay above the on-time
// threshold wins regardless of the weekly stat; the weekly verdict only
// applies once >=2 days of history exist; below 70% weekly on-time is
// "unreliable". A suggested alternative line is included whenever a route
// is flagged delayed/unreliable and a better-performing alternate line
// exists at that (interchange) station.

import { handleOptions, jsonResponse, errorResponse } from "../_shared/cors.ts";
import { createAdminClient } from "../_shared/supabase-admin.ts";
import { requireUser } from "../_shared/auth.ts";
import {
  getReliabilityStatsByStation,
  getReliabilityStatsByStationLine,
  ON_TIME_THRESHOLD_MINUTES,
  ReliabilityStats,
} from "../_shared/reliability.ts";

const DAYS_WINDOW = 7;
const UNRELIABLE_THRESHOLD_PERCENT = 70;
const LIVE_DELAY_STALE_MINUTES = 60;

// Mirrors Station.lines in station.dart: splits a possibly comma/slash
// joined `stations.line` display field into individual line names.
function splitLines(line: string): string[] {
  return line
    .split(/\s*(?:,|\/|\||&| and )\s*/i)
    .map((v) => v.trim())
    .filter((v) => v.length > 0);
}

Deno.serve(async (req) => {
  const preflight = handleOptions(req);
  if (preflight) return preflight;

  if (req.method !== "GET") return errorResponse("Method not allowed", 405);

  const supabase = createAdminClient();
  let userId: string;
  try {
    userId = await requireUser(req, supabase);
  } catch (error) {
    if (error instanceof Response) return error;
    return errorResponse("Unable to verify session", 401);
  }

  const { data: routes, error: routesError } = await supabase
    .from("saved_routes")
    .select(
      "*, origin_station:stations!saved_routes_origin_station_id_fkey(name, line), " +
        "destination_station:stations!saved_routes_destination_station_id_fkey(name, line)",
    )
    .eq("user_id", userId);

  if (routesError) return errorResponse(routesError.message, 500);
  if (!routes || routes.length === 0) return jsonResponse([]);

  const stationIds = Array.from(
    new Set(routes.map((r) => r.origin_station_id as string)),
  );

  try {
    const [stationStats, stationLineStats] = await Promise.all([
      getReliabilityStatsByStation(supabase, { stationIds, days: DAYS_WINDOW }),
      getReliabilityStatsByStationLine(supabase, { stationIds, days: DAYS_WINDOW }),
    ]);

    // Latest train_status per station, in one query (not one query per route).
    const { data: recentRows, error: recentError } = await supabase
      .from("train_status")
      .select("station_id, delay_minutes, recorded_at")
      .in("station_id", stationIds)
      .order("recorded_at", { ascending: false });
    if (recentError) return errorResponse(recentError.message, 500);

    const latestByStation = new Map<string, { delay_minutes: number | null; recorded_at: string }>();
    for (const row of recentRows ?? []) {
      if (!latestByStation.has(row.station_id)) {
        latestByStation.set(row.station_id, row);
      }
    }

    const emptyStats: ReliabilityStats = {
      totalTrips: 0,
      onTimeTrips: 0,
      onTimePercentage: null,
      averageDelayMinutes: null,
      daysOfData: 0,
      insufficientData: true,
    };

    const suggestions = routes.map((route) => {
      const originStation = route.origin_station as { name?: string; line?: string } | null;
      const destinationStation = route.destination_station as { name?: string } | null;

      const originLines = splitLines(originStation?.line ?? "");
      const primaryLine = originLines[0] ?? originStation?.line ?? "";

      const stats = stationStats.get(route.origin_station_id) ?? emptyStats;

      let liveDelayMinutes: number | null = null;
      const latest = latestByStation.get(route.origin_station_id);
      if (latest) {
        const minutesAgo = (Date.now() - new Date(latest.recorded_at).getTime()) / 60000;
        if (minutesAgo <= LIVE_DELAY_STALE_MINUTES) {
          liveDelayMinutes = latest.delay_minutes;
        }
      }

      let alternateLine: string | null = null;
      let alternateLineOnTimePercentage: number | null = null;
      const lineStatsForStation = stationLineStats.get(route.origin_station_id);
      if (lineStatsForStation) {
        for (const candidateLine of originLines) {
          if (candidateLine === primaryLine) continue;
          const lineStats = lineStatsForStation.get(candidateLine);
          if (!lineStats || lineStats.totalTrips === 0 || lineStats.onTimePercentage === null) continue;
          if (alternateLineOnTimePercentage === null || lineStats.onTimePercentage > alternateLineOnTimePercentage) {
            alternateLine = candidateLine;
            alternateLineOnTimePercentage = lineStats.onTimePercentage;
          }
        }
      }

      let status: "delayed" | "not_enough_data" | "unreliable" | "on_track";
      if (liveDelayMinutes !== null && liveDelayMinutes > ON_TIME_THRESHOLD_MINUTES) {
        status = "delayed";
      } else if (stats.daysOfData < 2) {
        status = "not_enough_data";
      } else if (stats.onTimePercentage !== null && stats.onTimePercentage < UNRELIABLE_THRESHOLD_PERCENT) {
        status = "unreliable";
      } else {
        status = "on_track";
      }

      const flagged = status === "delayed" || status === "unreliable";
      const suggestedAlternative =
        flagged && alternateLine
          ? { line: alternateLine, on_time_percentage: alternateLineOnTimePercentage }
          : null;

      return {
        route: {
          id: route.id,
          origin_station_id: route.origin_station_id,
          destination_station_id: route.destination_station_id,
          walking_minutes: route.walking_minutes,
        },
        origin_station_name: originStation?.name ?? "Unknown station",
        origin_line: primaryLine,
        destination_station_name: destinationStation?.name ?? "Unknown station",
        days_of_data: stats.daysOfData,
        weekly_on_time_percentage: stats.onTimePercentage,
        live_delay_minutes: liveDelayMinutes,
        status,
        suggested_alternative: suggestedAlternative,
      };
    });

    return jsonResponse(suggestions);
  } catch (err) {
    return errorResponse((err as Error).message, 500);
  }
});

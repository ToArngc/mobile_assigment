// GET /compute-leave-by-time?saved_route_id=<uuid>
//   or  ?origin_station_id=<uuid>&destination_station_id=<uuid>&walking_minutes=<int>
//
// Full server-side re-implementation of LeaveByRepository.computeLeaveByTime:
//   1. Look up the route's walking_minutes (from a saved_routes row, or the
//      walking_minutes query param when computing ad hoc).
//   2. Find the next scheduled departure today from the origin station
//      (timetable_entries, same two raw filters as the Dart version: no
//      line/direction filter — this preserves existing behavior exactly).
//   3. Compute the average delay over the most recent 30 train_status rows
//      at that station via the avg_recent_delay_minutes RPC (SQL-side
//      aggregation, not fetch-then-average in TS).
//   4. Return the computed leave-by timestamp plus the components used.
//
// "Now" and "today" are evaluated in Asia/Kuala_Lumpur time (the KTM
// Komuter network's timezone, no DST) since timetable_entries.scheduled_time
// is a timezone-less wall-clock time meant to be read as local Malaysia
// time — see the assumptions note in the deliverable summary.
//
// Returns JSON `null` (200) if there's no more scheduled departure today,
// mirroring the Dart function's nullable return.

import { handleOptions, jsonResponse, errorResponse } from "../_shared/cors.ts";
import { createAdminClient } from "../_shared/supabase-admin.ts";
import { requireUser } from "../_shared/auth.ts";

const KL_OFFSET_MINUTES = 8 * 60; // Asia/Kuala_Lumpur is UTC+8, no DST

function nowInKualaLumpur(): Date {
  const utcNow = new Date();
  return new Date(utcNow.getTime() + KL_OFFSET_MINUTES * 60 * 1000);
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

  const url = new URL(req.url);
  const savedRouteId = url.searchParams.get("saved_route_id");

  let originStationId: string | null;
  let walkingMinutes: number;

  if (savedRouteId) {
    const { data: route, error } = await supabase
      .from("saved_routes")
      .select()
      .eq("id", savedRouteId)
    .eq("user_id", userId)
      .maybeSingle();

    if (error) return errorResponse(error.message, 500);
    if (!route) return errorResponse("Saved route not found", 404);

    originStationId = route.origin_station_id;
    walkingMinutes = route.walking_minutes ?? 10;
  } else {
    originStationId = url.searchParams.get("origin_station_id");
    const walkingParam = url.searchParams.get("walking_minutes");
    walkingMinutes = walkingParam ? parseInt(walkingParam, 10) : 10;

    if (!originStationId) {
      return errorResponse(
        "saved_route_id or origin_station_id is required",
        400,
      );
    }
  }

  const klNow = nowInKualaLumpur();
  const hh = klNow.getUTCHours().toString().padStart(2, "0");
  const mm = klNow.getUTCMinutes().toString().padStart(2, "0");
  const nowTimeString = `${hh}:${mm}:00`;

  const { data: timetableRows, error: timetableError } = await supabase
    .from("timetable_entries")
    .select()
    .eq("station_id", originStationId)
    .gte("scheduled_time", nowTimeString)
    .order("scheduled_time")
    .limit(1);

  if (timetableError) return errorResponse(timetableError.message, 500);
  if (!timetableRows || timetableRows.length === 0) {
    return jsonResponse(null);
  }

  const scheduledTimeStr = timetableRows[0].scheduled_time as string; // "HH:mm:ss"
  const [schedHour, schedMinute] = scheduledTimeStr.split(":").map((p) => parseInt(p, 10));

  const scheduledDepartureKl = new Date(Date.UTC(
    klNow.getUTCFullYear(),
    klNow.getUTCMonth(),
    klNow.getUTCDate(),
    schedHour,
    schedMinute,
  ));
  // Convert the KL wall-clock instant back to a real UTC instant.
  const scheduledDepartureUtc = new Date(
    scheduledDepartureKl.getTime() - KL_OFFSET_MINUTES * 60 * 1000,
  );

  const { data: avgData, error: avgError } = await supabase.rpc(
    "avg_recent_delay_minutes",
    { p_station_id: originStationId, p_limit: 30 },
  );
  if (avgError) return errorResponse(avgError.message, 500);

  const avgRow = Array.isArray(avgData) ? avgData[0] : avgData;
  const hasEnoughData: boolean = avgRow?.has_data ?? false;
  const avgDelayMinutes: number = Number(avgRow?.avg_delay_minutes ?? 0);
  const sampleSize: number = Number(avgRow?.sample_size ?? 0);

  const arriveByTimeUtc = new Date(
    scheduledDepartureUtc.getTime() + Math.round(avgDelayMinutes) * 60 * 1000,
  );
  const leaveByTimeUtc = new Date(
    arriveByTimeUtc.getTime() - walkingMinutes * 60 * 1000,
  );

  return jsonResponse({
    next_scheduled_departure: scheduledDepartureUtc.toISOString(),
    average_delay_minutes: avgDelayMinutes,
    has_enough_data: hasEnoughData,
    sample_size: sampleSize,
    walking_minutes: walkingMinutes,
    leave_by_time: leaveByTimeUtc.toISOString(),
  });
});

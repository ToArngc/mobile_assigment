// GET /get-weekly-rides
//
// The caller's own rides from the last 7 days, with the week's aggregates
// already computed. Response shape:
//
//   {
//     ride_count: int,
//     on_time_count: int,
//     on_time_percentage: number | null,
//     avg_delay_minutes: number | null,
//     rides: [{ station_name, detected_at, delay_minutes }]
//   }
//
// ride_logs.delay_minutes is never populated (design doc §4), so delay is
// resolved at read time by matching each ride to the nearest train_status
// reading at the same station. Both the join and the aggregation happen
// inside the weekly_ride_summary RPC — deliberately not here and not in
// Dart, so the on-time rule is applied in exactly one place.
//
// Null percentage/average mean "no ride could be matched to a reading",
// which is a different thing from 0% and must stay distinguishable.

import { handleOptions, jsonResponse, errorResponse } from "../_shared/cors.ts";
import { createAdminClient } from "../_shared/supabase-admin.ts";
import { requireUser } from "../_shared/auth.ts";
import { ON_TIME_THRESHOLD_MINUTES } from "../_shared/reliability.ts";

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

  const since = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString();

  const { data, error } = await supabase.rpc("weekly_ride_summary", {
    p_user_id: userId,
    p_since: since,
    p_threshold: ON_TIME_THRESHOLD_MINUTES,
  });

  if (error) return errorResponse(error.message, 500);

  // The RPC returns a single row. A user with no rides still gets one,
  // with ride_count 0 and null aggregates, so the empty case needs no
  // special handling on the client.
  const summary = Array.isArray(data) ? data[0] : data;

  return jsonResponse(
    summary ?? {
      ride_count: 0,
      on_time_count: 0,
      on_time_percentage: null,
      avg_delay_minutes: null,
      rides: [],
    },
  );
});

// GET /get-weekly-rides
// Returns the caller's ride_logs from the last 7 days, oldest first
// (matches WeeklySummaryRepository.getRidesForLastWeek's default ordering).

import { handleOptions, jsonResponse, errorResponse } from "../_shared/cors.ts";
import { createAdminClient } from "../_shared/supabase-admin.ts";
import { getAuthenticatedUser } from "../_shared/auth.ts";

Deno.serve(async (req) => {
  const preflight = handleOptions(req);
  if (preflight) return preflight;

  if (req.method !== "GET") return errorResponse("Method not allowed", 405);

  const supabase = createAdminClient();
  const authResult = await getAuthenticatedUser(req, supabase);
  if ("error" in authResult) return authResult.error;
  const { user } = authResult;

  const since = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString();

  const { data, error } = await supabase
    .from("ride_logs")
    .select()
    .eq("user_id", user.id)
    .gte("detected_at", since)
    .order("detected_at");

  if (error) return errorResponse(error.message, 500);
  return jsonResponse(data);
});

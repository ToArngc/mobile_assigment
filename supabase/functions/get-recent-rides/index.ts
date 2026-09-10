import { handleOptions, jsonResponse, errorResponse } from "../_shared/cors.ts";
import { createAdminClient } from "../_shared/supabase-admin.ts";
import { requireUser } from "../_shared/auth.ts";

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
  const limitParam = url.searchParams.get("limit");
  const limit = limitParam ? parseInt(limitParam, 10) : 10;
  if (Number.isNaN(limit) || limit <= 0) {
    return errorResponse("limit must be a positive integer", 400);
  }

  const { data, error } = await supabase
    .from("ride_logs")
    .select(
      "*, stations!ride_logs_station_id_fkey(name, line), destination_station:stations!ride_logs_destination_station_id_fkey(name)",
    )
    .eq("user_id", userId)
    .order("detected_at", { ascending: false })
    .limit(limit);

  if (error) return errorResponse(error.message, 500);
  return jsonResponse(data);
});




import { handleOptions, jsonResponse, errorResponse } from "../_shared/cors.ts";
import { createAdminClient } from "../_shared/supabase-admin.ts";

Deno.serve(async (req) => {
  const preflight = handleOptions(req);
  if (preflight) return preflight;

  if (req.method !== "GET") return errorResponse("Method not allowed", 405);

  const url = new URL(req.url);
  const stationId = url.searchParams.get("station_id");
  if (!stationId) return errorResponse("station_id query param is required", 400);

  const supabase = createAdminClient();
  const { data, error } = await supabase
    .from("timetable_entries")
    .select()
    .eq("station_id", stationId)
    .order("scheduled_time");

  if (error) return errorResponse(error.message, 500);
  return jsonResponse(data);
});

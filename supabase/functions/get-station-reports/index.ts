import { handleOptions, jsonResponse, errorResponse } from "../_shared/cors.ts";
import { createAdminClient } from "../_shared/supabase-admin.ts";

Deno.serve(async (req) => {
  const preflight = handleOptions(req);
  if (preflight) return preflight;

  if (req.method !== "GET") return errorResponse("Method not allowed", 405);

  const url = new URL(req.url);
  const stationId = url.searchParams.get("station_id");
  if (!stationId) return errorResponse("station_id query param is required", 400);

  const limitParam = url.searchParams.get("limit");
  const limit = limitParam ? parseInt(limitParam, 10) : 20;
  if (Number.isNaN(limit) || limit <= 0) {
    return errorResponse("limit must be a positive integer", 400);
  }

  const supabase = createAdminClient();
  const { data, error } = await supabase
    .from("fault_reports")
    .select("id, station_id, issue_type, description, photo_url, status, created_at")
    .eq("station_id", stationId)
    .order("created_at", { ascending: false })
    .limit(limit);

  if (error) return errorResponse(error.message, 500);
  return jsonResponse(data);
});

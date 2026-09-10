import { handleOptions, jsonResponse, errorResponse } from "../_shared/cors.ts";
import { createAdminClient } from "../_shared/supabase-admin.ts";

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

Deno.serve(async (req) => {
  const preflight = handleOptions(req);
  if (preflight) return preflight;

  if (req.method !== "GET") return errorResponse("Method not allowed", 405);

  const url = new URL(req.url);
  const stationId = url.searchParams.get("station_id");

  if (!stationId) {
    return errorResponse("station_id query param is required", 400);
  }
  if (!UUID_PATTERN.test(stationId)) {
    return errorResponse("station_id must be a valid uuid", 400);
  }

  const supabase = createAdminClient();
  const { data, error } = await supabase
    .from("station_accessibility")
    .select("issue_type, status, created_at")
    .eq("station_id", stationId)
    .order("created_at", { ascending: false });

  if (error) return errorResponse(error.message, 500);

  return jsonResponse(data ?? []);
});

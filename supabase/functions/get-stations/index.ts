// GET /get-stations
// Public. All stations, sorted by name.

import { handleOptions, jsonResponse, errorResponse } from "../_shared/cors.ts";
import { createAdminClient } from "../_shared/supabase-admin.ts";

Deno.serve(async (req) => {
  const preflight = handleOptions(req);
  if (preflight) return preflight;

  if (req.method !== "GET") return errorResponse("Method not allowed", 405);

  const supabase = createAdminClient();
  const { data, error } = await supabase.from("stations").select().order("name");

  if (error) return errorResponse(error.message, 500);
  return jsonResponse(data);
});

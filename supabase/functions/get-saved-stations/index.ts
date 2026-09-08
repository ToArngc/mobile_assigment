// GET /get-saved-stations
// Returns the caller's saved_stations rows joined with stations(name, line).

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

  const { data, error } = await supabase
    .from("saved_stations")
    .select("*, stations(name, line)")
    .eq("user_id", userId);

  if (error) return errorResponse(error.message, 500);
  return jsonResponse(data);
});

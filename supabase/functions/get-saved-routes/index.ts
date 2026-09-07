// GET /get-saved-routes
// Returns the caller's saved_routes rows.

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

  const { data, error } = await supabase
    .from("saved_routes")
    .select()
    .eq("user_id", user.id);

  if (error) return errorResponse(error.message, 500);
  return jsonResponse(data);
});

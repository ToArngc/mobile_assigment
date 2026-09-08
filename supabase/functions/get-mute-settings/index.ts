// GET /get-mute-settings
// Returns the caller's mute_settings row, or null if none exists (not an error).

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
    .from("mute_settings")
    .select()
    .eq("user_id", user.id)
    .maybeSingle();

  if (error) return errorResponse(error.message, 500);
  return jsonResponse(data);
});

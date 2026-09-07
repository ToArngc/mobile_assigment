// GET /get-my-reports
// Returns the caller's own fault_reports, newest first.

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

  const url = new URL(req.url);
  const limitParam = url.searchParams.get("limit");
  const limit = limitParam ? parseInt(limitParam, 10) : 50;
  if (Number.isNaN(limit) || limit <= 0) {
    return errorResponse("limit must be a positive integer", 400);
  }

  const { data, error } = await supabase
    .from("fault_reports")
    .select()
    .eq("user_id", user.id)
    .order("created_at", { ascending: false })
    .limit(limit);

  if (error) return errorResponse(error.message, 500);
  return jsonResponse(data);
});

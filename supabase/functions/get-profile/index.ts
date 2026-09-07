// GET /get-profile
// Get-or-create semantics: returns the caller's profiles row, creating one
// with a placeholder username ("Rider <first 6 chars of user id>", matching
// the fallback pattern used in profile_screen.dart) if it doesn't exist yet.

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

  const { data: existing, error: selectError } = await supabase
    .from("profiles")
    .select()
    .eq("id", user.id)
    .maybeSingle();

  if (selectError) return errorResponse(selectError.message, 500);
  if (existing) return jsonResponse(existing);

  const fallbackUsername = `Rider ${user.id.substring(0, 6)}`;

  const { data: created, error: insertError } = await supabase
    .from("profiles")
    .insert({ id: user.id, username: fallbackUsername })
    .select()
    .single();

  if (insertError) {
    // Lost a race with another request creating the same row concurrently.
    if (insertError.code === "23505") {
      const { data: retried, error: retryError } = await supabase
        .from("profiles")
        .select()
        .eq("id", user.id)
        .single();
      if (retryError) return errorResponse(retryError.message, 500);
      return jsonResponse(retried);
    }
    return errorResponse(insertError.message, 500);
  }

  return jsonResponse(created, 201);
});

// GET /get-profile
// Get-or-create semantics: returns the caller's profiles row, creating one
// if it doesn't exist yet. Prefers the username stashed in auth
// user_metadata at sign-up; falls back to a placeholder ("Rider <first 6
// chars of user id>", matching profile_screen.dart) when there's no
// metadata username or it collides with one already taken.

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
  const metadataUsername = (user.user_metadata?.username as string | undefined)
    ?.trim();
  const desiredUsername = metadataUsername || fallbackUsername;

  const { data: created, error: insertError } = await supabase
    .from("profiles")
    .insert({ id: user.id, username: desiredUsername })
    .select()
    .single();

  if (insertError) {
    if (insertError.code === "23505") {
      // If we tried the metadata username, the collision could be either
      // another request creating this same row concurrently, or someone
      // else already holding that exact username — retry with the generic
      // fallback to distinguish (and resolve) the two cases.
      if (desiredUsername !== fallbackUsername) {
        const { data: retriedFallback, error: fallbackError } = await supabase
          .from("profiles")
          .insert({ id: user.id, username: fallbackUsername })
          .select()
          .single();
        if (!fallbackError) return jsonResponse(retriedFallback, 201);
        if (fallbackError.code !== "23505") {
          return errorResponse(fallbackError.message, 500);
        }
      }

      // Lost a race with another request creating the same row concurrently.
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

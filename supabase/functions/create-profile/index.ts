// POST /create-profile
// Body: { username?: string }
// Inserts a profiles row with id = caller's user id, preferring the body's
// username but falling back to the auth user_metadata username set at
// sign-up (the same value get-profile's auto-create reads) so the two
// functions never disagree about the intended username. 409 on duplicate.

import { handleOptions, jsonResponse, errorResponse } from "../_shared/cors.ts";
import { createAdminClient } from "../_shared/supabase-admin.ts";
import { requireUser } from "../_shared/auth.ts";

Deno.serve(async (req) => {
  const preflight = handleOptions(req);
  if (preflight) return preflight;

  if (req.method !== "POST") return errorResponse("Method not allowed", 405);

  const supabase = createAdminClient();
  let userId: string;
  try {
    userId = await requireUser(req, supabase);
  } catch (error) {
    if (error instanceof Response) return error;
    return errorResponse("Unable to verify session", 401);
  }
  const { data: authData, error: authError } =
    await supabase.auth.admin.getUserById(userId);
  if (authError || !authData.user) {
    return errorResponse("Unable to load user profile", 500);
  }
  const user = authData.user;

  let body: { username?: string } = {};
  try {
    body = await req.json();
  } catch {
    // No body (or invalid JSON) is fine as long as metadata has a username.
  }

  const metadataUsername = (user.user_metadata?.username as string | undefined)
    ?.trim();
  const username = body.username?.trim() || metadataUsername;
  if (!username) return errorResponse("username is required", 400);

  const { data, error } = await supabase
    .from("profiles")
    .insert({ id: userId, username })
    .select()
    .single();

  if (error) {
    if (error.code === "23505") {
      return errorResponse("That username is already taken.", 409);
    }
    return errorResponse(error.message, 500);
  }

  return jsonResponse(data, 201);
});

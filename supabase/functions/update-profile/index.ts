// POST /update-profile
// Body: { username: string }
// Upserts the caller's own profiles row. 409 on duplicate username.

import { handleOptions, jsonResponse, errorResponse } from "../_shared/cors.ts";
import { createAdminClient } from "../_shared/supabase-admin.ts";
import { getAuthenticatedUser } from "../_shared/auth.ts";

Deno.serve(async (req) => {
  const preflight = handleOptions(req);
  if (preflight) return preflight;

  if (req.method !== "POST") return errorResponse("Method not allowed", 405);

  const supabase = createAdminClient();
  const authResult = await getAuthenticatedUser(req, supabase);
  if ("error" in authResult) return authResult.error;
  const { user } = authResult;

  let body: { username?: string };
  try {
    body = await req.json();
  } catch {
    return errorResponse("Invalid JSON body", 400);
  }

  const username = body.username?.trim();
  if (!username) return errorResponse("username is required", 400);

  const { data, error } = await supabase
    .from("profiles")
    .upsert({ id: user.id, username })
    .select()
    .single();

  if (error) {
    if (error.code === "23505") {
      return errorResponse("That username is already taken.", 409);
    }
    return errorResponse(error.message, 500);
  }

  return jsonResponse(data);
});

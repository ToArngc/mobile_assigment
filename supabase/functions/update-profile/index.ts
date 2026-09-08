



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
    .upsert({ id: userId, username })
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

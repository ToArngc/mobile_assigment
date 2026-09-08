


import { handleOptions, jsonResponse, errorResponse } from "../_shared/cors.ts";
import { createAdminClient } from "../_shared/supabase-admin.ts";

Deno.serve(async (req) => {
  const preflight = handleOptions(req);
  if (preflight) return preflight;

  if (req.method !== "GET") return errorResponse("Method not allowed", 405);

  const url = new URL(req.url);
  const id = url.searchParams.get("id");
  if (!id) return errorResponse("id query param is required", 400);

  const supabase = createAdminClient();
  const { data, error } = await supabase
    .from("stations")
    .select()
    .eq("id", id)
    .maybeSingle();

  if (error) return errorResponse(error.message, 500);
  if (!data) return errorResponse("Station not found", 404);

  return jsonResponse(data);
});

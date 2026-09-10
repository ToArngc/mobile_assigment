import { SupabaseClient, User } from "jsr:@supabase/supabase-js@2";
import { errorResponse } from "./cors.ts";

export type AuthResult = { user: User } | { error: Response };

export async function getAuthenticatedUser(
  req: Request,
  supabase: SupabaseClient,
): Promise<AuthResult> {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return { error: errorResponse("Missing or invalid Authorization header", 401) };
  }

  const jwt = authHeader.slice("Bearer ".length).trim();
  if (!jwt) {
    return { error: errorResponse("Missing or invalid Authorization header", 401) };
  }

  const { data, error } = await supabase.auth.getUser(jwt);
  if (error || !data?.user) {
    return { error: errorResponse("Invalid or expired session", 401) };
  }

  return { user: data.user };
}

export async function requireUser(
  req: Request,
  supabase: SupabaseClient,
): Promise<string> {
  const result = await getAuthenticatedUser(req, supabase);
  if ("error" in result) throw result.error;
  return result.user.id;
}

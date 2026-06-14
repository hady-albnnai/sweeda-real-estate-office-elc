// Edge Function: delete-user
// الغرض: حذف منطقي لموظف داخلي من قبل الإدارة

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function env(name: string, fallback?: string): string {
  return Deno.env.get(name) ?? (fallback ? Deno.env.get(fallback) ?? "" : "");
}

function json(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ success: false, error: "METHOD_NOT_ALLOWED" }, 405);

  try {
    const supabaseAdmin = createClient(
      env("SUPABASE_URL", "PROJECT_URL"),
      env("SUPABASE_SERVICE_ROLE_KEY", "SERVICE_ROLE_KEY"),
      { auth: { autoRefreshToken: false, persistSession: false } },
    );

    const body = await req.json();
    const adminUid = body.admin_uid ?? body.adminUid;
    const userId = body.user_id ?? body.userId;

    const { data, error } = await supabaseAdmin.rpc("admin_delete_staff_user", {
      p_admin_uid: adminUid,
      p_target_uid: userId,
    });

    if (error) return json({ success: false, error: error.message }, 400);
    return json({ success: data?.success === true });
  } catch (error) {
    return json({ success: false, error: error instanceof Error ? error.message : String(error) }, 500);
  }
});

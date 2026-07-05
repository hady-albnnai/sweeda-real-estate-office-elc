// Edge Function: admin-dashboard
// الغرض: نقل إحصائيات الإدارة وإدارة الموظفين والشكوك من RPC مباشر إلى Edge Function.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
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

async function validateActor(
  req: Request,
  supabaseAdmin: ReturnType<typeof createClient>,
  body: Record<string, unknown>,
  minRole = 3,
): Promise<{ ok: true; uid: string; role: number } | { ok: false; response: Response }> {
  const requestedUid = (body.admin_uid ?? body.adminUid ?? body.user_uid ?? body.userUid ?? body.admin_id ?? body.adminId)?.toString() ?? "";
  const authHeader = req.headers.get("Authorization") ?? "";
  const bearer = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : "";

  if (bearer && bearer !== "undefined" && bearer !== "null" && bearer !== "anon_key_here") {
    const { data: userData } = await supabaseAdmin.auth.getUser(bearer);
    const uid = userData?.user?.id;
    if (uid && (!requestedUid || requestedUid === uid)) {
      const { data: userRow, error } = await supabaseAdmin
        .from("users")
        .select("id, role, sts, i_del")
        .eq("id", uid)
        .eq("i_del", 0)
        .single();

      if (!error && userRow && userRow.sts === 0 && Number(userRow.role) >= minRole) {
        return { ok: true, uid: uid, role: Number(userRow.role) };
      }
    }
  }

  const sessionToken = (body.staff_session_token ?? body.staffSessionToken)?.toString() ?? (authHeader && !authHeader.startsWith("Bearer ") ? authHeader.trim() : "");
  if (!requestedUid || !sessionToken) {
    return { ok: false, response: json({ success: false, error: "STAFF_SESSION_REQUIRED" }, 401) };
  }

  const { data, error } = await supabaseAdmin.rpc("validate_staff_session", {
    p_user_uid: requestedUid,
    p_token: sessionToken,
    p_min_role: minRole,
  });

  if (error || data?.success !== true) {
    return {
      ok: false,
      response: json({ success: false, error: data?.error ?? error?.message ?? "INVALID_STAFF_SESSION" }, 401),
    };
  }

  return { ok: true, uid: requestedUid, role: Number(data.role) };
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

    const body = await req.json() as Record<string, unknown>;
    const action = (body.action ?? "").toString();

    // خاصية إبطال جلسة الموظف يمكن لأي موظف مسجل تنفيذها لنفسه 
    if (action === "revoke_session") {
      const actor = await validateActor(req, supabaseAdmin, body, 1);
      if (!actor.ok) return actor.response;

      const token = (body.staff_session_token ?? body.staffSessionToken)?.toString() ?? "";
      const { data, error } = await supabaseAdmin.rpc("revoke_staff_session", {
        p_user_uid: actor.uid,
        p_token: token,
      });

      if (error) return json({ success: false, error: error.message }, 400);
      return json({ success: data === true });
    }

    // الإحصائيات الفردية للموظف (منفذ/مصور/مكتب) - تتطلب دور 1 أو أعلى
    if (action === "staff_stats") {
      const actor = await validateActor(req, supabaseAdmin, body, 1);
      if (!actor.ok) return actor.response;
      
      const { data, error } = await supabaseAdmin.rpc("get_staff_stats_internal", { p_user_uid: actor.uid });
      if (error) return json({ success: false, error: error.message }, 400);
      return json({ success: true, stats: data });
    }

    // دوال لوحة التحكم وإدارة الموظفين والشكوك - تتطلب دور 3 (الإدارة)
    const actor = await validateActor(req, supabaseAdmin, body, 3);
    if (!actor.ok) return actor.response;
    const adminUid = actor.uid;

    if (action === "resource_usage") {
      if (![4, 5, 6].includes(Number(actor.role))) {
        return json({ success: false, error: "NOT_AUTHORIZED" }, 403);
      }
      const { data, error } = await supabaseAdmin.rpc("get_resource_usage_internal", { p_admin_uid: adminUid });
      if (error) return json({ success: false, error: error.message }, 400);
      return json(data && typeof data === "object" ? data as Record<string, unknown> : { success: true, usage: data });
    }

    if (action === "dashboard_stats") {
      const { data, error } = await supabaseAdmin.rpc("get_admin_dashboard_stats", { p_admin_uid: adminUid });
      if (error) return json({ success: false, error: error.message }, 400);
      return json({ success: true, stats: data });
    }

    if (action === "all_staff") {
      const { data, error } = await supabaseAdmin.rpc("get_all_staff_users", { p_admin_uid: adminUid });
      if (error) return json({ success: false, error: error.message }, 400);
      return json({ success: true, staff: data ?? [] });
    }

    if (action === "fraud_suspects") {
      const { data, error } = await supabaseAdmin.rpc("admin_fraud_suspects", { p_admin_uid: adminUid });
      if (error) return json({ success: false, error: error.message }, 400);
      return json({ success: true, suspects: data ?? [] });
    }

    if (action === "admin_requests") {
      const { data, error } = await supabaseAdmin.rpc("get_admin_requests_internal", { p_admin_uid: adminUid });
      if (error) return json({ success: false, error: error.message }, 400);
      return json({ success: true, requests: data ?? [] });
    }

    if (action === "close_request") {
      const requestId = (body.request_id ?? body.requestId)?.toString() ?? "";
      const status = Number(body.status);
      const reason = (body.reason ?? "closed_by_admin").toString();
      const note = (body.note ?? "").toString();
      if (!requestId || !Number.isInteger(status)) {
        return json({ success: false, error: "MISSING_REQUIRED_FIELDS" }, 400);
      }
      const { data, error } = await supabaseAdmin.rpc("admin_close_request_internal", {
        p_admin_uid: adminUid,
        p_request_id: requestId,
        p_status: status,
        p_reason: reason,
        p_note: note,
      });
      if (error) return json({ success: false, error: error.message }, 400);
      return json({ success: data === true });
    }

    return json({ success: false, error: "UNKNOWN_ACTION" }, 400);
  } catch (error) {
    return json({ success: false, error: error instanceof Error ? error.message : String(error) }, 500);
  }
});

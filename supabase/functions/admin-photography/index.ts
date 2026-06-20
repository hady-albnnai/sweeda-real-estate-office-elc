// Edge Function: admin-photography
// الغرض: نقل مهام إدارة التصوير الخاصة بالإدارة (إنشاء مهام، تحديث حالة، إرفاق صور) من RPC إلى Edge Function.

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
  const requestedUid = (body.admin_uid ?? body.adminUid)?.toString() ?? "";
  const authHeader = req.headers.get("Authorization") ?? "";
  const bearer = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : "";

  if (bearer) {
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

  const sessionToken = (body.staff_session_token ?? body.staffSessionToken)?.toString() ?? "";
  if (!requestedUid || !sessionToken) {
    return { ok: false, response: json({ success: false, error: "ADMIN_SESSION_REQUIRED" }, 401) };
  }

  const { data, error } = await supabaseAdmin.rpc("validate_staff_session", {
    p_user_uid: requestedUid,
    p_token: sessionToken,
    p_min_role: minRole,
  });

  if (error || data?.success !== true) {
    return {
      ok: false,
      response: json({ success: false, error: data?.error ?? error?.message ?? "INVALID_ADMIN_SESSION" }, 401),
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
    const actor = await validateActor(req, supabaseAdmin, body, 3); // إدارة/موظف مكتبي
    if (!actor.ok) return actor.response;

    const adminUid = actor.uid;

    if (action === "create") {
      const offerId = (body.offer_id ?? body.offerId)?.toString() ?? "";
      const photographerId = (body.photographer_id ?? body.photographerId)?.toString() ?? "";
      const notes = (body.notes ?? "").toString();
      const scheduledAt = body.ts_scheduled?.toString() ?? null;

      if (!offerId || !photographerId) {
        return json({ success: false, error: "MISSING_REQUIRED_FIELDS" }, 400);
      }

      const { data, error } = await supabaseAdmin.rpc("create_photography_task_internal", {
        p_admin_uid: adminUid,
        p_offer_id: offerId,
        p_photographer_id: photographerId,
        p_notes: notes,
        p_ts_scheduled: scheduledAt,
      });

      if (error) return json({ success: false, error: error.message }, 400);
      return json({ success: data === true });
    }

    if (action === "update_status") {
      const taskId = (body.task_id ?? body.taskId)?.toString() ?? "";
      const status = Number(body.status ?? 0);
      const officeNote = (body.office_note ?? body.officeNote ?? "").toString();

      if (!taskId) return json({ success: false, error: "TASK_ID_REQUIRED" }, 400);

      const { data, error } = await supabaseAdmin.rpc("update_photography_task_status_internal", {
        p_admin_uid: adminUid,
        p_task_id: taskId,
        p_status: status,
        p_office_note: officeNote,
      });

      if (error) return json({ success: false, error: error.message }, 400);
      return json({ success: data === true });
    }

    if (action === "attach_media") {
      const taskId = (body.task_id ?? body.taskId)?.toString() ?? "";
      if (!taskId) return json({ success: false, error: "TASK_ID_REQUIRED" }, 400);

      const { data, error } = await supabaseAdmin.rpc("attach_photography_media_to_offer_internal", {
        p_admin_uid: adminUid,
        p_task_id: taskId,
      });

      if (error) return json({ success: false, error: error.message }, 400);
      return json({ success: data === true });
    }

    return json({ success: false, error: "UNKNOWN_ACTION" }, 400);
  } catch (error) {
    return json({ success: false, error: error instanceof Error ? error.message : String(error) }, 500);
  }
});

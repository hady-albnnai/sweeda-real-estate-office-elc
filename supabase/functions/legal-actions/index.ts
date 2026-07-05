// Edge Function: legal-actions
// الغرض: نقطة الوصول الآمنة لعمليات القسم القانوني وتعقيب المعاملات ومسارات المحامين والمعقبين.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type SupabaseAdmin = ReturnType<typeof createClient>;

function env(name: string, fallback?: string): string {
  return Deno.env.get(name) ?? (fallback ? Deno.env.get(fallback) ?? "" : "");
}

function json(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function base64ToUint8Array(base64: string): Uint8Array {
  const clean = base64.includes(",") ? base64.split(",").pop() ?? "" : base64;
  const binary = atob(clean);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

function safeImageContentType(value: unknown): string {
  const contentType = typeof value === "string" ? value.toLowerCase() : "image/jpeg";
  return ["image/jpeg", "image/jpg", "image/png", "image/webp"].includes(contentType)
    ? (contentType === "image/jpg" ? "image/jpeg" : contentType)
    : "image/jpeg";
}

function safeStorageName(value: string): string {
  return value.replace(/[^a-zA-Z0-9_.-]/g, "_").slice(0, 80) || "item";
}

async function signExpeditingTaskAttachments(
  supabaseAdmin: SupabaseAdmin,
  tasks: unknown,
): Promise<unknown[]> {
  const list = Array.isArray(tasks) ? tasks : [];
  const result: unknown[] = [];
  for (const rawTask of list) {
    const task = rawTask && typeof rawTask === "object" ? { ...(rawTask as Record<string, unknown>) } : rawTask;
    if (!task || typeof task !== "object") {
      result.push(task);
      continue;
    }
    const record = task as Record<string, unknown>;
    const checklist = Array.isArray(record.checklist) ? record.checklist : [];
    record.checklist = await Promise.all(checklist.map(async (rawItem) => {
      const item = rawItem && typeof rawItem === "object" ? { ...(rawItem as Record<string, unknown>) } : rawItem;
      if (!item || typeof item !== "object") return item;
      const itemRecord = item as Record<string, unknown>;
      const path = (itemRecord.attachment_url ?? "").toString();
      if (path && !path.startsWith("http")) {
        const { data } = await supabaseAdmin.storage
          .from("expediting_docs")
          .createSignedUrl(path, 3600);
        if (data?.signedUrl) itemRecord.attachment_signed_url = data.signedUrl;
      }
      return itemRecord;
    }));
    result.push(record);
  }
  return result;
}

async function getUserRole(
  supabaseAdmin: SupabaseAdmin,
  uid: string,
): Promise<number | null> {
  const { data, error } = await supabaseAdmin
    .from("users")
    .select("role, sts, i_del")
    .eq("id", uid)
    .eq("i_del", 0)
    .single();

  if (error || !data || Number(data.sts) !== 0) return null;
  return Number(data.role);
}

function canManageLawyerProfiles(role: number): boolean {
  // الإدارة العليا فقط: نائب مدير ومدير. لا يدخل lawyer=7 أو expediter=8 في صلاحيات الإدارة.
  return role === 5 || role === 6;
}

function isLawyer(role: number): boolean {
  return role === 7;
}

function isExpediter(role: number): boolean {
  return role === 8;
}

async function validateUser(
  req: Request,
  supabaseAdmin: SupabaseAdmin,
  requestedUid: string,
  body: Record<string, unknown> = {},
): Promise<{ ok: true; uid: string; role: number } | { ok: false; response: Response }> {
  const authHeader = req.headers.get("Authorization") ?? "";
  const bearer = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : "";

  if (bearer && bearer !== "undefined" && bearer !== "null" && bearer !== "anon_key_here") {
    const { data: userData, error } = await supabaseAdmin.auth.getUser(bearer);
    const uid = userData?.user?.id;
    if (!error && uid) {
      if (requestedUid && requestedUid !== uid) {
        return { ok: false, response: json({ success: false, error: "UNAUTHORIZED_ACCESS" }, 403) };
      }
      const role = await getUserRole(supabaseAdmin, uid);
      if (role == null) {
        return { ok: false, response: json({ success: false, error: "USER_INACTIVE" }, 401) };
      }
      return { ok: true, uid, role };
    }
  }

  const sessionToken = (body?.staff_session_token ?? body?.staffSessionToken ?? body?.session_token ?? body?.sessionToken)?.toString()
    || (authHeader && !authHeader.startsWith("Bearer ") ? authHeader.trim() : "");

  if (sessionToken && sessionToken !== "anon_key_here" && sessionToken !== "undefined" && sessionToken !== "null") {
    const { data, error } = await supabaseAdmin.rpc("validate_staff_session", {
      p_token: sessionToken,
      p_user_uid: requestedUid,
      p_min_role: 0,
    });

    if (!error && data && data.success === true) {
      return { ok: true, uid: data.user_id, role: Number(data.role) };
    }
  }

  return { ok: false, response: json({ success: false, error: "AUTH_TOKEN_REQUIRED" }, 401) };
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
    const requestedUid = (body.user_uid ?? body.userUid ?? body.admin_uid ?? body.adminUid)?.toString() ?? "";

    if (!requestedUid) return json({ success: false, error: "USER_UID_REQUIRED" }, 400);

    const actor = await validateUser(req, supabaseAdmin, requestedUid, body);
    if (!actor.ok) return actor.response;
    const uid = actor.uid;
    const role = actor.role;

    if (action === "get_active_lawyers") {
      const { data, error } = await supabaseAdmin.rpc("get_active_lawyers");
      if (error) return json({ success: false, error: error.message }, 400);
      return json({ success: true, lawyers: data ?? [] });
    }

    if (action === "admin_upsert_lawyer") {
      const targetUid = (body.target_uid ?? body.targetUid)?.toString() ?? "";
      const whatsapp = (body.whatsapp_phone ?? body.whatsappPhone)?.toString() ?? "";
      const address = (body.office_address ?? body.officeAddress ?? "").toString();
      const spec = (body.specialization ?? "عقارات وسيارات").toString();
      const avl = body.avl ?? {};

      if (!targetUid || !whatsapp) return json({ success: false, error: "MISSING_REQUIRED_FIELDS" }, 400);
      if (targetUid !== uid && !canManageLawyerProfiles(role)) {
        return json({ success: false, error: "NOT_AUTHORIZED" }, 403);
      }
      if (targetUid === uid && !isLawyer(role) && !canManageLawyerProfiles(role)) {
        return json({ success: false, error: "NOT_AUTHORIZED" }, 403);
      }

      const { data, error } = await supabaseAdmin.rpc("admin_upsert_lawyer_profile", {
        p_admin_uid: uid,
        p_target_uid: targetUid,
        p_whatsapp: whatsapp,
        p_address: address,
        p_spec: spec,
        p_avl: avl,
      });

      if (error) return json({ success: false, error: error.message }, 400);
      return json({ success: data === true });
    }

    if (action === "update_checklist_item") {
      if (!isLawyer(role) && !isExpediter(role) && !canManageLawyerProfiles(role)) {
        return json({ success: false, error: "NOT_AUTHORIZED" }, 403);
      }

      const taskId = (body.task_id ?? body.taskId)?.toString() ?? "";
      const itemKey = (body.item_key ?? body.itemKey)?.toString() ?? "";
      const status = Number(body.status ?? 0);
      const inputValue = (body.input_value ?? body.inputValue ?? "").toString();
      let attachmentUrl = (body.attachment_url ?? body.attachmentUrl ?? "").toString();
      const attachmentBase64 = (body.attachment_base64 ?? body.attachmentBase64 ?? "").toString();
      const notes = (body.notes ?? "").toString();

      if (!taskId || !itemKey) return json({ success: false, error: "TASK_ID_AND_ITEM_KEY_REQUIRED" }, 400);

      const { data: taskRow, error: taskError } = await supabaseAdmin
        .from("expediting_tasks")
        .select("id, lawyer_uid, expediter_uid")
        .eq("id", taskId)
        .single();
      if (taskError || !taskRow) return json({ success: false, error: "TASK_NOT_FOUND" }, 404);
      if (taskRow.lawyer_uid !== uid && taskRow.expediter_uid !== uid && !canManageLawyerProfiles(role)) {
        return json({ success: false, error: "NOT_AUTHORIZED" }, 403);
      }

      if (attachmentBase64) {
        const contentType = safeImageContentType(body.attachment_content_type ?? body.attachmentContentType);
        const ext = contentType === "image/png" ? "png" : contentType === "image/webp" ? "webp" : "jpg";
        const bytes = base64ToUint8Array(attachmentBase64);
        if (bytes.length > 8 * 1024 * 1024) return json({ success: false, error: "ATTACHMENT_TOO_LARGE" }, 413);
        const path = `${taskId}/${safeStorageName(itemKey)}_${Date.now()}.${ext}`;
        const { error: uploadError } = await supabaseAdmin.storage
          .from("expediting_docs")
          .upload(path, bytes, { contentType, cacheControl: "3600", upsert: true });
        if (uploadError) return json({ success: false, error: `ATTACHMENT_UPLOAD_FAILED: ${uploadError.message}` }, 400);
        attachmentUrl = path;
      }

      const { data, error } = await supabaseAdmin.rpc("update_expediting_checklist_item", {
        p_actor_uid: uid,
        p_task_id: taskId,
        p_item_key: itemKey,
        p_status: status,
        p_input_value: inputValue,
        p_attachment_url: attachmentUrl,
        p_notes: notes,
      });

      if (error) return json({ success: false, error: error.message }, 400);
      return json(data as Record<string, unknown>);
    }

    if (action === "get_lawyer_profile") {
      if (!isLawyer(role)) return json({ success: false, error: "NOT_AUTHORIZED" }, 403);
      const { data, error } = await supabaseAdmin.rpc("get_lawyer_profile", {
        p_lawyer_uid: uid,
      });
      if (error) return json({ success: false, error: error.message }, 400);
      return json({ success: true, profile: data });
    }

    if (action === "get_available_expediters") {
      if (!isLawyer(role) && !canManageLawyerProfiles(role)) {
        return json({ success: false, error: "NOT_AUTHORIZED" }, 403);
      }
      const { data, error } = await supabaseAdmin.rpc("get_available_expediters");
      if (error) return json({ success: false, error: error.message }, 400);
      return json({ success: true, expediters: data ?? [] });
    }

    if (action === "create_expediting_task") {
      if (!isLawyer(role)) return json({ success: false, error: "NOT_AUTHORIZED" }, 403);
      const expediterUid = (body.expediter_uid ?? body.expediterUid)?.toString() ?? "";
      const itemType = Number(body.item_type ?? body.itemType ?? 0);
      const propNum = (body.target_property_num ?? "").toString();
      const zone = (body.target_zone ?? "").toString();
      const notes = (body.lawyer_notes ?? body.notes ?? "").toString();
      const checklist = body.checklist ?? [];

      if (!expediterUid) return json({ success: false, error: "EXPEDITER_UID_REQUIRED" }, 400);

      const { data, error } = await supabaseAdmin.rpc("create_expediting_task_internal", {
        p_lawyer_uid: uid,
        p_expediter_uid: expediterUid,
        p_item_type: itemType,
        p_target_property_num: propNum,
        p_target_zone: zone,
        p_lawyer_notes: notes,
        p_checklist: checklist,
      });
      if (error) return json({ success: false, error: error.message }, 400);
      return json(data as Record<string, unknown>);
    }

    if (action === "complete_expediting_task") {
      if (!isExpediter(role)) return json({ success: false, error: "NOT_AUTHORIZED" }, 403);
      const taskId = (body.task_id ?? body.taskId)?.toString() ?? "";
      const notes = (body.expediter_notes ?? body.notes ?? "").toString();
      if (!taskId) return json({ success: false, error: "TASK_ID_REQUIRED" }, 400);

      const { data, error } = await supabaseAdmin.rpc("complete_expediting_task_internal", {
        p_expediter_uid: uid,
        p_task_id: taskId,
        p_notes: notes,
      });
      if (error) return json({ success: false, error: error.message }, 400);
      return json(data as Record<string, unknown>);
    }

    if (action === "request_checklist_revision") {
      if (!isLawyer(role)) return json({ success: false, error: "NOT_AUTHORIZED" }, 403);
      const taskId = (body.task_id ?? body.taskId)?.toString() ?? "";
      const itemKey = (body.item_key ?? body.itemKey)?.toString() ?? "";
      const revisionNotes = (body.revision_notes ?? body.revisionNotes ?? body.notes ?? "").toString();
      if (!taskId || !itemKey) return json({ success: false, error: "TASK_ID_AND_ITEM_KEY_REQUIRED" }, 400);

      const { data, error } = await supabaseAdmin.rpc("request_expediting_item_revision_internal", {
        p_lawyer_uid: uid,
        p_task_id: taskId,
        p_item_key: itemKey,
        p_revision_notes: revisionNotes,
      });
      if (error) return json({ success: false, error: error.message }, 400);
      return json(data as Record<string, unknown>);
    }

    if (action === "approve_expediting_task") {
      if (!isLawyer(role)) return json({ success: false, error: "NOT_AUTHORIZED" }, 403);
      const taskId = (body.task_id ?? body.taskId)?.toString() ?? "";
      if (!taskId) return json({ success: false, error: "TASK_ID_REQUIRED" }, 400);

      const { data, error } = await supabaseAdmin.rpc("approve_expediting_task_internal", {
        p_lawyer_uid: uid,
        p_task_id: taskId,
      });
      if (error) return json({ success: false, error: error.message }, 400);
      return json(data as Record<string, unknown>);
    }

    if (action === "get_lawyer_expediting_tasks") {
      if (!isLawyer(role)) return json({ success: false, error: "NOT_AUTHORIZED" }, 403);
      const { data, error } = await supabaseAdmin.rpc("get_lawyer_expediting_tasks", {
        p_lawyer_uid: uid,
      });
      if (error) return json({ success: false, error: error.message }, 400);
      const signedTasks = await signExpeditingTaskAttachments(supabaseAdmin, data ?? []);
      return json({ success: true, tasks: signedTasks });
    }

    if (action === "get_lawyer_appointments") {
      if (!isLawyer(role)) return json({ success: false, error: "NOT_AUTHORIZED" }, 403);
      const { data, error } = await supabaseAdmin.rpc("get_lawyer_appointments", {
        p_lawyer_uid: uid,
      });
      if (error) return json({ success: false, error: error.message }, 400);
      return json({ success: true, appointments: data ?? [] });
    }

    if (action === "get_my_expediting_tasks") {
      if (!isExpediter(role)) return json({ success: false, error: "NOT_AUTHORIZED" }, 403);
      const { data, error } = await supabaseAdmin.rpc("get_my_expediting_tasks", {
        p_expediter_uid: uid,
      });
      if (error) return json({ success: false, error: error.message }, 400);
      const signedTasks = await signExpeditingTaskAttachments(supabaseAdmin, data ?? []);
      return json({ success: true, tasks: signedTasks });
    }

    return json({ success: false, error: "UNKNOWN_ACTION" }, 400);
  } catch (error) {
    return json({ success: false, error: (error as Error).message }, 500);
  }
});

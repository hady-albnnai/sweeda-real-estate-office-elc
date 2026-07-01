// Edge Function: user-account
// الغرض: إدارة ملف المستخدم الشخصي، التحقق من اسم المستخدم، كلمات السر، الأجهزة، والتوثيق، باستخدام JWT أو آليات محددة.

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

// دالة التحقق من الـ JWT
async function validateUser(
  req: Request,
  supabaseAdmin: ReturnType<typeof createClient>,
  requestedUid: string
): Promise<{ ok: true; uid: string } | { ok: false; response: Response }> {
  const authHeader = req.headers.get("Authorization") ?? "";
  const bearer = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : "";

  // 1. Try JWT validation first
  if (bearer && bearer !== "undefined" && bearer !== "null" && bearer !== "anon_key_here") {
    const { data: userData, error } = await supabaseAdmin.auth.getUser(bearer);
    const uid = userData?.user?.id;
    if (!error && uid) {
      if (requestedUid && requestedUid !== uid) {
        return { ok: false, response: json({ success: false, error: "UNAUTHORIZED_ACCESS" }, 403) };
      }
      return { ok: true, uid: uid };
    }
  }

  // 2. Try Custom Session Token validation (for custom password login)
  // If the header is not a Bearer JWT, we treat it as a session token
  const sessionToken = authHeader.trim();
  if (sessionToken && !authHeader.startsWith("Bearer ")) {
    const { data, error } = await supabaseAdmin.rpc("validate_staff_session", {
      p_token: sessionToken,
      p_user_uid: requestedUid, // Pass requestedUid to ensure the token belongs to the requested user
    });

    if (!error && data && data.success === true) {
      return { ok: true, uid: data.user_id };
    }
  }

  // FALLBACK REMOVED: No longer accepting requestedUid blindly.
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

    // ----------------------------------------------------
    // دوال لا تتطلب توثيق المستخدم (تُستخدم أثناء تسجيل الدخول/التسجيل)
    // ----------------------------------------------------

    if (action === "login_with_password") {
      const identifier = (body.identifier ?? "").toString();
      const password = (body.password ?? "").toString();
      if (!identifier || !password) return json({ success: false, error: "MISSING_CREDENTIALS" }, 400);

      const { data, error } = await supabaseAdmin.rpc("login_with_password", {
        p_identifier: identifier,
        p_password: password,
      });

      if (error) return json({ success: false, error: error.message }, 400);
      return json({ success: true, result: data });
    }

    if (action === "check_username") {
      const username = (body.username ?? "").toString();
      if (!username) return json({ success: false, error: "USERNAME_REQUIRED" }, 400);

      const { data, error } = await supabaseAdmin.rpc("check_username_available", { p_username: username });
      if (error) return json({ success: false, error: error.message }, 400);
      return json({ success: true, available: data === true });
    }

    if (action === "register_device") {
      const deviceId = (body.device_id ?? body.deviceId)?.toString() ?? "";
      const ipHint = (body.ip_hint ?? body.ipHint)?.toString() ?? null;
      if (!deviceId) return json({ success: false, error: "DEVICE_ID_REQUIRED" }, 400);

      const { data, error } = await supabaseAdmin.rpc("register_device", {
        p_device_id: deviceId,
        p_ip_hint: ipHint,
      });
      if (error) return json({ success: false, error: error.message }, 400);
      return json({ success: data === true });
    }

    // ----------------------------------------------------
    // دوال تتطلب مستخدم مسجل الدخول (JWT)
    // ----------------------------------------------------
    
    const requestedUid = (body.user_uid ?? body.userUid)?.toString() ?? "";
    if (!requestedUid) return json({ success: false, error: "USER_UID_REQUIRED" }, 400);

    const actor = await validateUser(req, supabaseAdmin, requestedUid);
    if (!actor.ok) return actor.response;
    const uid = actor.uid;

    if (action === "revoke_staff_session") {
      const sessionToken = (body.session_token ?? body.sessionToken)?.toString() ?? "";
      if (!sessionToken) return json({ success: false, error: "SESSION_TOKEN_REQUIRED" }, 400);

      const { data, error } = await supabaseAdmin.rpc("revoke_staff_session", {
        p_user_uid: uid,
        p_token: sessionToken,
      });
      if (error) return json({ success: false, error: error.message }, 400);
      return json({ success: data === true });
    }

    if (action === "register_weekly_login") {
      const pts = (body.pts ?? 100);
      const { data, error } = await supabaseAdmin.rpc("register_weekly_login", {
        p_uid: uid,
        p_pts: pts,
      });
      if (error) return json({ success: false, error: error.message }, 400);
      return json({ success: data === true });
    }

    if (action === "award_points") {
      const eventType = (body.event_type ?? "").toString();
      const points = (body.points ?? 0);
      if (!eventType) return json({ success: false, error: "EVENT_TYPE_REQUIRED" }, 400);

      const { data, error } = await supabaseAdmin.rpc("award_points_safe", {
        p_uid: uid,
        p_event_type: eventType,
        p_points: points,
      });
      if (error) return json({ success: false, error: error.message }, 400);
      return json(typeof data === "object" && data !== null ? data : { success: data === true });
    }

    if (action === "update_badge") {
      const { data, error } = await supabaseAdmin.rpc("update_user_badge", { p_uid: uid });
      if (error) return json({ success: false, error: error.message }, 400);
      return json({ success: true });
    }

    if (action === "get_full_profile") {
      const { data, error } = await supabaseAdmin.rpc("get_user_full_by_id", { p_uid: uid });
      if (error) return json({ success: false, error: error.message }, 400);
      return json({ success: true, profile: data });
    }

    if (action === "update_profile") {
      const payload = body.payload as Record<string, unknown>;
      if (!payload) return json({ success: false, error: "PAYLOAD_REQUIRED" }, 400);

      const { data, error } = await supabaseAdmin.rpc("update_user_profile_internal", {
        p_user_uid: uid,
        p_payload: payload,
      });
      if (error) return json({ success: false, error: error.message }, 400);
      return json({ success: data === true });
    }

    if (action === "get_device_tokens") {
      const { data, error } = await supabaseAdmin.rpc("get_user_device_tokens", { p_uid: uid });
      if (error) return json({ success: false, error: error.message }, 400);
      return json({ success: true, tokens: data ?? [] });
    }

    if (action === "register_password") {
      const username = (body.username ?? "").toString();
      const password = (body.password ?? "").toString();
      if (!username || !password) return json({ success: false, error: "CREDENTIALS_REQUIRED" }, 400);

      const { data, error } = await supabaseAdmin.rpc("register_password", {
        p_user_uid: uid,
        p_username: username,
        p_password: password,
      });
      if (error) return json({ success: false, error: error.message }, 400);
      return json(typeof data === "object" && data !== null ? data : { success: data === true });
    }

    if (action === "change_password") {
      const oldPassword = (body.old_password ?? body.oldPassword ?? "").toString();
      const newPassword = (body.new_password ?? body.newPassword ?? "").toString();
      if (!oldPassword || !newPassword) return json({ success: false, error: "PASSWORDS_REQUIRED" }, 400);

      const { data, error } = await supabaseAdmin.rpc("change_password_internal", {
        p_user_uid: uid,
        p_old_password: oldPassword,
        p_new_password: newPassword,
      });
      if (error) return json({ success: false, error: error.message }, 400);
      return json(typeof data === "object" && data !== null ? data : { success: data === true });
    }

    if (action === "create_report") {
      const report = body.report as Record<string, unknown>;
      if (!report) return json({ success: false, error: "REPORT_DATA_REQUIRED" }, 400);
      const { data, error } = await supabaseAdmin.rpc("create_report_internal", {
        p_reporter_uid: uid,
        p_report: report,
      });
      if (error) return json({ success: false, error: error.message }, 400);
      return json({ success: true, report_id: data });
    }

    if (action === "user_payments") {
      const { data, error } = await supabaseAdmin.rpc("get_user_payments_internal", { p_user_uid: uid });
      if (error) return json({ success: false, error: error.message }, 400);
      return json({ success: true, payments: data ?? [] });
    }

    if (action === "handle_email_auth") {
      const { data, error } = await supabaseAdmin.rpc("handle_email_auth_internal");
      if (error) return json({ success: false, error: error.message }, 400);
      return json({ success: true, result: data });
    }

    if (action === "request_verification") {
      const { data, error } = await supabaseAdmin.rpc("request_verification_by_uid", { p_user_uid: uid });
      if (error) return json({ success: false, error: error.message }, 400);
      return json({ success: data === true });
    }

    if (action === "reset_password") {
      const newPassword = (body.new_password ?? body.newPassword ?? "").toString();
      if (!newPassword) return json({ success: false, error: "NEW_PASSWORD_REQUIRED" }, 400);

      // هذا الإجراء يفترض أن المستخدم قد تخطى للتو مرحلة الـ OTP وأثبت هويته
      const { data, error } = await supabaseAdmin.rpc("reset_password_with_otp", {
        p_user_uid: uid,
        p_new_password: newPassword,
      });
      if (error) return json({ success: false, error: error.message }, 400);
      return json(typeof data === "object" && data !== null ? data : { success: data === true });
    }

    return json({ success: false, error: "UNKNOWN_ACTION" }, 400);
  } catch (error) {
    return json({ success: false, error: error instanceof Error ? error.message : String(error) }, 500);
  }
});

// Edge Function: admin-payments
// الغرض: نقل إدارة المدفوعات من RPC مباشر إلى Edge Function محمية بجلسة موظف.

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
  minRole = 5,
): Promise<{ ok: true; adminUid: string; role: number } | { ok: false; response: Response }> {
  const requestedAdminUid = (body.admin_uid ?? body.adminUid ?? body.user_uid ?? body.userUid ?? body.admin_id ?? body.adminId)?.toString() ?? "";
  const authHeader = req.headers.get("Authorization") ?? "";
  const bearer = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : "";

  if (bearer && bearer !== "undefined" && bearer !== "null" && bearer !== "anon_key_here") {
    const { data: userData } = await supabaseAdmin.auth.getUser(bearer);
    const uid = userData?.user?.id;
    if (uid && (!requestedAdminUid || requestedAdminUid === uid)) {
      const { data: userRow, error } = await supabaseAdmin
        .from("users")
        .select("id, role, sts, i_del")
        .eq("id", uid)
        .eq("i_del", 0)
        .single();
      if (!error && userRow && userRow.sts === 0 && Number(userRow.role) >= minRole) {
        return { ok: true, adminUid: uid, role: Number(userRow.role) };
      }
    }
  }

  const sessionToken = (body.staff_session_token ?? body.staffSessionToken)?.toString() ?? (authHeader && !authHeader.startsWith("Bearer ") ? authHeader.trim() : "");
  if (!requestedAdminUid || !sessionToken) {
    return { ok: false, response: json({ success: false, error: "ADMIN_SESSION_REQUIRED" }, 401) };
  }

  const { data, error } = await supabaseAdmin.rpc("validate_staff_session", {
    p_user_uid: requestedAdminUid,
    p_token: sessionToken,
    p_min_role: minRole,
  });

  if (error || data?.success !== true) {
    return { ok: false, response: json({ success: false, error: data?.error ?? error?.message ?? "INVALID_ADMIN_SESSION" }, 401) };
  }

  return { ok: true, adminUid: requestedAdminUid, role: Number(data.role) };
}

// إشعار المستخدم بنتيجة دفعته — أي فشل هنا لا يُفشل القبول/الرفض نفسه.
async function notifyPaymentDecision(
  supabaseAdmin: ReturnType<typeof createClient>,
  paymentId: string,
  kind: "approve" | "reject",
  result: Record<string, unknown> | null,
  reason: string,
): Promise<void> {
  try {
    const { data: pay } = await supabaseAdmin
      .from("payments")
      .select("uid, tp")
      .eq("id", paymentId)
      .maybeSingle();
    const uid = (pay?.uid ?? "").toString();
    if (!uid) return;
    const until = (result?.until ?? "").toString();
    let title: string;
    let bodyText: string;
    if (kind === "reject") {
      title = "❌ تم رفض طلب الدفع";
      bodyText = `السبب: ${reason || "غير محدد"} — يمكنك التصحيح وإعادة الطلب من «سجل دفعاتي».`;
    } else if (pay.tp === 1) {
      title = "✅ إعلانك المميز مفعّل";
      bodyText = `تم تفعيل الإعلان المميز لعرضك${until ? ` حتى ${until}` : ""}.`;
    } else {
      title = "✅ تم تفعيل باقتك";
      bodyText = `باقتك مفعّلة${until ? ` حتى ${until}` : ""}${
        result?.upgraded === true ? " — تمت الترقية واستبدال الباقة السابقة" : ""
      }.`;
    }
    await supabaseAdmin.functions.invoke("send-push-notification", {
      body: { uid, title, body: bodyText, data: { screen: "my_payments" } },
    });
  } catch (e) {
    console.error("notifyPaymentDecision failed:", e);
  }
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
    const actor = await validateActor(req, supabaseAdmin, body, 5);
    if (!actor.ok) return actor.response;

    const adminUid = actor.adminUid;

    if (action === "list") {
      const { data, error } = await supabaseAdmin.rpc("get_admin_payments_internal", {
        p_admin_uid: adminUid,
      });
      if (error) return json({ success: false, error: error.message }, 400);
      return json({ success: true, payments: data ?? [] });
    }

    if (action === "approve") {
      const paymentId = (body.payment_id ?? body.paymentId)?.toString() ?? "";
      if (!paymentId) return json({ success: false, error: "PAYMENT_ID_REQUIRED" }, 400);
      const { data, error } = await supabaseAdmin.rpc("approve_payment_final", {
        p_payment_id: paymentId,
        p_admin_id: adminUid,
      });
      if (error) return json({ success: false, error: error.message }, 400);
      const result = data && typeof data === "object" ? data as Record<string, unknown> : { success: data === true };
      if (result.success === true) {
        await notifyPaymentDecision(supabaseAdmin, paymentId, "approve", result, "");
      }
      return json(result);
    }

    if (action === "reject") {
      const paymentId = (body.payment_id ?? body.paymentId)?.toString() ?? "";
      if (!paymentId) return json({ success: false, error: "PAYMENT_ID_REQUIRED" }, 400);
      // سبب الرفض يُخزَّن في meta ويصل للمستخدم كإشعار
      const reason = (body.reason ?? "")?.toString() ?? "";
      const { data, error } = await supabaseAdmin.rpc("admin_reject_payment_internal", {
        p_admin_uid: adminUid,
        p_payment_id: paymentId,
        p_reason: reason,
      });
      if (error) return json({ success: false, error: error.message }, 400);
      if (data === true) {
        await notifyPaymentDecision(supabaseAdmin, paymentId, "reject", null, reason);
      }
      return json({ success: data === true });
    }

    return json({ success: false, error: "UNKNOWN_ACTION" }, 400);
  } catch (error) {
    return json({ success: false, error: error instanceof Error ? error.message : String(error) }, 500);
  }
});

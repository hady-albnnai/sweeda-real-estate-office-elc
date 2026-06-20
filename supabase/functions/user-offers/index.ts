// Edge Function: user-offers
// الغرض: نقل عمليات إدارة العروض الخاصة بالمستخدم من RPC مباشر إلى Edge Function تتحقق من جلسة المستخدم (Auth JWT).

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

// دالة للتحقق من المستخدم الحالي عن طريق الـ JWT
async function validateUser(
  req: Request,
  supabaseAdmin: ReturnType<typeof createClient>,
  requestedUid?: string
): Promise<{ ok: true; uid: string } | { ok: false; response: Response }> {
  const authHeader = req.headers.get("Authorization") ?? "";
  const bearer = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : "";

  if (!bearer) {
    return { ok: false, response: json({ success: false, error: "AUTH_TOKEN_REQUIRED" }, 401) };
  }

  const { data: userData, error } = await supabaseAdmin.auth.getUser(bearer);
  const uid = userData?.user?.id;

  if (error || !uid) {
    return { ok: false, response: json({ success: false, error: "INVALID_AUTH_TOKEN" }, 401) };
  }

  // إذا تم تمرير ID معين، يجب أن يتطابق مع المستخدم الحالي لمنع المستخدم من تعديل بيانات غيره
  if (requestedUid && requestedUid !== uid) {
    // يمكن أن نسمح للآدمن، لكن في هذه الدالة نتعامل مع المستخدمين العاديين، لذا نرفض
    return { ok: false, response: json({ success: false, error: "UNAUTHORIZED_ACCESS" }, 403) };
  }

  return { ok: true, uid: uid };
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

    // دالة increment_offer_views قد لا تتطلب مستخدم مسجل الدخول، سنعالجها أولاً
    if (action === "increment_views") {
      const offerId = (body.offer_id ?? body.offerId)?.toString() ?? "";
      if (!offerId) return json({ success: false, error: "OFFER_ID_REQUIRED" }, 400);

      const { data, error } = await supabaseAdmin.rpc("increment_offer_views_internal", {
        p_offer_id: offerId,
      });
      if (error) return json({ success: false, error: error.message }, 400);
      return json({ success: data === true });
    }

    // الدالة check_offer_duplicate يمكن أن تكون للمستخدم أو للموظف (من شاشة الإضافة للموظف)، لكنها تحتاج توثيق
    if (action === "check_duplicate") {
      const actor = await validateUser(req, supabaseAdmin);
      if (!actor.ok) return actor.response;
      
      const title = (body.title ?? "").toString();
      const price = Number(body.price ?? 0);
      const loc = body.loc as Record<string, unknown>;
      const usrId = (body.usr_id ?? body.usrId)?.toString() ?? actor.uid;

      const { data, error } = await supabaseAdmin.rpc("check_offer_duplicate", {
        p_ttl: title,
        p_prc: price,
        p_loc: loc,
        p_usr_id: usrId,
      });
      if (error) return json({ success: false, error: error.message }, 400);
      return json({ success: true, is_duplicate: data === true });
    }

    // باقي الإجراءات تتطلب مستخدماً محدداً (p_user_uid)
    const requestedUid = (body.user_uid ?? body.userUid)?.toString() ?? "";
    if (!requestedUid) return json({ success: false, error: "USER_UID_REQUIRED" }, 400);

    const actor = await validateUser(req, supabaseAdmin, requestedUid);
    if (!actor.ok) return actor.response;
    const uid = actor.uid;

    if (action === "list") {
      const { data, error } = await supabaseAdmin.rpc("get_user_offers_internal", { p_user_uid: uid });
      if (error) return json({ success: false, error: error.message }, 400);
      return json({ success: true, offers: data ?? [] });
    }

    if (action === "get_by_id") {
      const offerId = (body.offer_id ?? body.offerId)?.toString() ?? "";
      if (!offerId) return json({ success: false, error: "OFFER_ID_REQUIRED" }, 400);

      const { data, error } = await supabaseAdmin.rpc("get_offer_by_id_internal", {
        p_user_uid: uid,
        p_offer_id: offerId,
      });
      if (error) return json({ success: false, error: error.message }, 400);
      return json({ success: true, offer: data });
    }

    if (action === "create") {
      const offer = body.offer as Record<string, unknown>;
      if (!offer) return json({ success: false, error: "OFFER_DATA_REQUIRED" }, 400);

      const { data, error } = await supabaseAdmin.rpc("create_offer_internal", {
        p_user_uid: uid,
        p_offer: offer,
      });
      if (error) return json({ success: false, error: error.message }, 400);
      return json({ success: true, offer_id: data }); // قد يرجع ID العرض المنشأ أو true حسب تصميمك
    }

    if (action === "purchase_boost") {
      const offerId = (body.offer_id ?? body.offerId)?.toString() ?? "";
      const boostType = (body.boost_type ?? body.boostType)?.toString() ?? "";
      if (!offerId || !boostType) return json({ success: false, error: "MISSING_REQUIRED_FIELDS" }, 400);

      const { data, error } = await supabaseAdmin.rpc("purchase_offer_boost", {
        p_uid: uid,
        p_offer_id: offerId,
        p_boost_type: boostType,
      });
      if (error) return json({ success: false, error: error.message }, 400);
      return json({ success: data === true });
    }

    if (action === "mark_social_published") {
      const offerId = (body.offer_id ?? body.offerId)?.toString() ?? "";
      const text = (body.text ?? "").toString();
      if (!offerId) return json({ success: false, error: "OFFER_ID_REQUIRED" }, 400);

      const { data, error } = await supabaseAdmin.rpc("mark_social_published_internal", {
        p_user_uid: uid,
        p_offer_id: offerId,
        p_text: text,
      });
      if (error) return json({ success: false, error: error.message }, 400);
      return json({ success: data === true });
    }

    return json({ success: false, error: "UNKNOWN_ACTION" }, 400);
  } catch (error) {
    return json({ success: false, error: error instanceof Error ? error.message : String(error) }, 500);
  }
});

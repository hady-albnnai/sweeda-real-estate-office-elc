// Edge Function: social-publish
// الغرض: النشر التلقائي على فيس بوك وانستغرام
// يعمل مع Meta Graph API باستخدام Page Token محفوظ بـ app_config

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

// ═══════════════════════════════════════════════════════════
// التحقق من المستخدم
// ═══════════════════════════════════════════════════════════
async function validateUser(
  req: Request,
  supabaseAdmin: ReturnType<typeof createClient>,
  requestedUid: string,
  body: Record<string, unknown> = {}
): Promise<{ ok: true; uid: string } | { ok: false; response: Response }> {
  const authHeader = req.headers.get("Authorization") ?? "";
  const bearer = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : "";

  if (bearer && bearer !== "undefined" && bearer !== "null") {
    const { data: userData, error } = await supabaseAdmin.auth.getUser(bearer);
    const uid = userData?.user?.id;
    if (!error && uid) {
      if (requestedUid && requestedUid !== uid) {
        return { ok: false, response: json({ success: false, error: "UNAUTHORIZED_ACCESS" }, 403) };
      }
      return { ok: true, uid };
    }
  }

  const sessionToken = (body?.staff_session_token ?? body?.sessionToken)?.toString()
    || (authHeader && !authHeader.startsWith("Bearer ") ? authHeader.trim() : "");
  if (sessionToken && sessionToken !== "undefined" && sessionToken !== "null") {
    const { data, error } = await supabaseAdmin.rpc("validate_staff_session", {
      p_token: sessionToken,
      p_user_uid: requestedUid,
      p_min_role: 0,
    });
    if (!error && data && data.success === true) {
      return { ok: true, uid: data.user_id };
    }
  }

  return { ok: false, response: json({ success: false, error: "AUTH_TOKEN_REQUIRED" }, 401) };
}

// ═══════════════════════════════════════════════════════════
// توليد نص المنشور من بيانات العرض
// ═══════════════════════════════════════════════════════════
function generateSocialPost(offer: Record<string, unknown>): string {
  const ttl = String(offer.ttl ?? "");
  const typ = Number(offer.typ ?? 0);
  const trx = Number(offer.trx ?? 0);
  const prc = Number(offer.prc ?? 0);
  const cur = Number(offer.cur ?? 1);
  const loc = (offer.loc ?? {}) as Record<string, unknown>;
  const descript = String(offer.descript ?? "");

  const isProperty = typ === 0;
  const trxLabel = trx === 0 ? "للبيع" : "للإيجار";
  const emoji = isProperty ? "🏠" : "🚗";
  const curLabel = cur === 0 ? "$" : "ل.س";

  let text = `${emoji} ${ttl}\n\n`;
  text += `📌 ${trxLabel}\n`;
  if (prc > 0) {
    text += `💰 السعر: ${prc.toLocaleString("ar-SA")} ${curLabel}\n`;
  }
  const locDesc = loc?.d ?? loc?.["d"];
  if (locDesc && String(locDesc).length > 0) {
    text += `📍 الموقع: ${locDesc}\n`;
  }
  if (descript.length > 0) {
    text += `\n${descript}\n`;
  }
  text += `\n📞 للتواصل والمعاينة عبر المكتب العقاري الالكتروني\n\n`;
  text += `#عقارات_السويداء #السويداء `;
  text += isProperty ? `#عقارات #${trx === 0 ? "بيع" : "إيجار"}` : "#سيارات #مركبات";

  return text;
}

// ═══════════════════════════════════════════════════════════
// النشر على صفحة فيس بوك
// ═══════════════════════════════════════════════════════════
async function publishToFacebook(
  pageId: string,
  pageToken: string,
  message: string,
  imageUrl?: string
): Promise<{ success: boolean; postId?: string; error?: string }> {
  try {
    const params: Record<string, string> = {
      message,
      access_token: pageToken,
    };
    if (imageUrl) {
      params.picture = imageUrl;
    }

    const response = await fetch(
      `https://graph.facebook.com/v21.0/${pageId}/feed`,
      {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: new URLSearchParams(params).toString(),
      }
    );

    const data = await response.json();
    if (data.error) {
      console.error("[social-publish] FB error:", data.error.message);
      return { success: false, error: data.error.message };
    }
    return { success: true, postId: data.id };
  } catch (error) {
    console.error("[social-publish] FB exception:", error);
    return { success: false, error: error instanceof Error ? error.message : String(error) };
  }
}

// ═══════════════════════════════════════════════════════════
// النشر على انستغرام (خطوتين: حاوية ثم نشر)
// ═══════════════════════════════════════════════════════════
async function publishToInstagram(
  igBusinessId: string,
  pageToken: string,
  caption: string,
  imageUrl: string
): Promise<{ success: boolean; mediaId?: string; error?: string }> {
  try {
    // الخطوة 1: إنشاء حاوية الوسائط
    const createParams = new URLSearchParams({
      image_url: imageUrl,
      caption,
      access_token: pageToken,
    });

    const createResponse = await fetch(
      `https://graph.facebook.com/v21.0/${igBusinessId}/media`,
      {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: createParams.toString(),
      }
    );

    const createData = await createResponse.json();
    if (createData.error) {
      console.error("[social-publish] IG create error:", createData.error.message);
      return { success: false, error: createData.error.message };
    }

    const containerId = createData.id;

    // الانتظار حتى تجهز الحاوية (أقصى 45 ثانية)
    let ready = false;
    for (let i = 0; i < 15; i++) {
      await new Promise((resolve) => setTimeout(resolve, 3000));

      const statusResponse = await fetch(
        `https://graph.facebook.com/v21.0/${containerId}?fields=status_code&access_token=${pageToken}`
      );
      const statusData = await statusResponse.json();

      if (statusData.status_code === "FINISHED") {
        ready = true;
        break;
      }
      if (statusData.status_code === "ERROR") {
        return { success: false, error: statusData.status_message ?? "Instagram processing failed" };
      }
    }

    if (!ready) {
      return { success: false, error: "Instagram processing timeout" };
    }

    // الخطوة 2: نشر الحاوية
    const publishParams = new URLSearchParams({
      creation_id: containerId,
      access_token: pageToken,
    });

    const publishResponse = await fetch(
      `https://graph.facebook.com/v21.0/${igBusinessId}/media_publish`,
      {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: publishParams.toString(),
      }
    );

    const publishData = await publishResponse.json();
    if (publishData.error) {
      console.error("[social-publish] IG publish error:", publishData.error.message);
      return { success: false, error: publishData.error.message };
    }

    return { success: true, mediaId: publishData.id };
  } catch (error) {
    console.error("[social-publish] IG exception:", error);
    return { success: false, error: error instanceof Error ? error.message : String(error) };
  }
}

// ═══════════════════════════════════════════════════════════
// Main Handler
// ═══════════════════════════════════════════════════════════
serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ success: false, error: "METHOD_NOT_ALLOWED" }, 405);

  try {
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { auth: { autoRefreshToken: false, persistSession: false } }
    );

    const body = await req.json() as Record<string, unknown>;
    const action = (body.action ?? "").toString();

    // ══════════════════════════════════════════════════════════
    // publish — النشر التلقائي على فيس بوك وانستغرام
    // ══════════════════════════════════════════════════════════
    if (action === "publish") {
      const requestedUid = (body.user_uid ?? "").toString();
      const offerId = (body.offer_id ?? "").toString();

      if (!requestedUid || !offerId) {
        return json({ success: false, error: "MISSING_USER_UID_OR_OFFER_ID" }, 400);
      }

      // التحقق من المستخدم
      const actor = await validateUser(req, supabaseAdmin, requestedUid, body);
      if (!actor.ok) return actor.response;
      const uid = actor.uid;

      // 1. جلب بيانات العرض
      const { data: offerData, error: offerError } = await supabaseAdmin
        .from("offers")
        .select("id, usr_id, ttl, typ, trx, prc, cur, loc, descript, imgs, soc_pub, i_del")
        .eq("id", offerId)
        .eq("usr_id", uid)
        .eq("i_del", 0)
        .maybeSingle();

      if (offerError || !offerData) {
        return json({ success: false, error: "OFFER_NOT_FOUND" }, 404);
      }

      // 2. فحص عدم تكرار النشر
      if (offerData.soc_pub === 1) {
        return json({ success: false, error: "ALREADY_PUBLISHED", message: "تم نشر هذا العرض مسبقاً" }, 409);
      }

      // 3. جلب إعدادات السوشال من app_config
      const { data: configData, error: configError } = await supabaseAdmin
        .from("app_config")
        .select("value")
        .eq("key", "main")
        .maybeSingle();

      if (configError || !configData) {
        return json({ success: false, error: "CONFIG_NOT_FOUND" }, 500);
      }

      const social = configData.value?.social;
      if (!social?.fb_page_id || !social?.fb_page_token) {
        return json({
          success: false,
          error: "SOCIAL_NOT_CONFIGURED",
          message: "إعدادات النشر التلقائي غير مُعدّة بعد",
        }, 503);
      }

      // 4. توليد نص المنشور
      const postText = generateSocialPost(offerData);

      // 5. تحضير رابط الصورة الأولى
      const imgs = (offerData.imgs ?? []) as string[];
      const firstImage = imgs.length > 0 ? imgs[0] : undefined;

      // 6. النشر على فيس بوك
      const fbResult = await publishToFacebook(
        String(social.fb_page_id),
        String(social.fb_page_token),
        postText,
        firstImage
      );

      // 7. النشر على انستغرام (إذا فيه صورة ومعرف الحساب التجاري)
      let igResult: { success: boolean; mediaId?: string; error?: string } = { success: false, error: "SKIPPED_NO_IMAGE" };
      if (firstImage && social.ig_business_id) {
        igResult = await publishToInstagram(
          String(social.ig_business_id),
          String(social.fb_page_token),
          postText,
          firstImage
        );
      }

      // 8. تعليم العرض كمنشور (فقط إذا نجح على الأقل منصة واحدة)
      const anySuccess = fbResult.success || igResult.success;
      let marked = false;
      let pointsAwarded = 0;

      if (anySuccess) {
        const { data: markResult, error: markError } = await supabaseAdmin.rpc(
          "mark_social_published_internal",
          {
            p_user_uid: uid,
            p_offer_id: offerId,
            p_text: postText,
          }
        );

        if (markError) {
          console.error("[social-publish] mark error:", markError.message);
        } else {
          marked = markResult === true;
        }

        // 9. منح النقاط
        if (marked) {
          const sharePoints = Number(social.share_points ?? 100);
          const { error: ptsError } = await supabaseAdmin.rpc("award_points_safe", {
            p_uid: uid,
            p_event_type: "soc",
            p_points: sharePoints,
          });
          if (!ptsError) {
            pointsAwarded = sharePoints;
          }
        }
      }

      return json({
        success: anySuccess,
        facebook: fbResult,
        instagram: igResult,
        marked,
        points_awarded: pointsAwarded,
      });
    }

    // ══════════════════════════════════════════════════════════
    // check_config — التحقق من إعدادات النشر التلقائي
    // ══════════════════════════════════════════════════════════
    if (action === "check_config") {
      const { data: configData } = await supabaseAdmin
        .from("app_config")
        .select("value")
        .eq("key", "main")
        .maybeSingle();

      const social = configData?.value?.social;
      const configured = !!(social?.fb_page_id && social?.fb_page_token);

      return json({
        success: true,
        configured,
        has_facebook: !!(social?.fb_page_id && social?.fb_page_token),
        has_instagram: !!(social?.ig_business_id && social?.fb_page_token),
      });
    }

    return json({ success: false, error: "UNKNOWN_ACTION" }, 400);
  } catch (error) {
    console.error("[social-publish] Fatal:", error);
    return json({ success: false, error: error instanceof Error ? error.message : String(error) }, 500);
  }
});

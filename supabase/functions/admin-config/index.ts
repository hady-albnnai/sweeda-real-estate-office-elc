// Edge Function: admin-config — كتابة آمنة لإعدادات التطبيق (app_config)
// السبب: سياسة RLS على app_config تشترط auth.uid() (جلسة Supabase حقيقية مع role≥6)
//        بينما المدير/النائب يدخلان بالهاتف عبر staff sessions (auth.uid()=NULL)
//        فكان الحفظ من شاشة الإعدادات يفشل بصمت — هذه الدالة تكتب عبر service_role
//        بعد التحقق من الجلسة (JWT أو staff session) بحد أدنى role≥5 (مدير/نائب).
// الأمان: whitelist حصرية للمفاتيح النصية المسموح تعديلها في هذه المرحلة:
//         txts.videoRequestWhatsApp / txts.videoRequestGroupLink / txts.appDownloadLink
//         (تُوسَّع لاحقاً لباقي أقسام الإعدادات بمراحل منفصلة ومراجعة مستقلة)
// ترتيب النشر: functions deploy فقط — لا تغييرات قاعدة بيانات.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// المفاتيح النصية المسموح تعديلها داخل txts.* (قائمة بيضاء)
const ALLOWED_TEXT_KEYS = new Set([
  "videoRequestWhatsApp",
  "videoRequestGroupLink",
  "appDownloadLink",
]);

// كود سجل التدقيق لتغيير إعدادات txts (أكواد 101-107 مستخدمة للعروض/السوشيال)
const ACT_UPDATE_CONFIG_TEXTS = 120;

function env(name: string, fallback?: string): string {
  return Deno.env.get(name) ?? (fallback ? Deno.env.get(fallback) ?? "" : "");
}

function json(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

// نفس نمط validateActor المعتمد في admin-offers (JWT ثم staff session)
async function validateActor(
  req: Request,
  supabaseAdmin: ReturnType<typeof createClient>,
  body: Record<string, unknown>,
  minRole = 5, // مدير + نائب فقط — صاحب صلاحية "إعدادات التطبيق"
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

  const sessionToken = (body.staff_session_token ?? body.staffSessionToken)?.toString()
    ?? (authHeader && !authHeader.startsWith("Bearer ") ? authHeader.trim() : "");
  if (!requestedAdminUid || !sessionToken) {
    return { ok: false, response: json({ success: false, error: "ADMIN_SESSION_REQUIRED" }, 401) };
  }

  const { data, error } = await supabaseAdmin.rpc("validate_staff_session", {
    p_user_uid: requestedAdminUid,
    p_token: sessionToken,
    p_min_role: minRole,
  });

  if (error || data?.success !== true) {
    return {
      ok: false,
      response: json({ success: false, error: data?.error ?? error?.message ?? "INVALID_ADMIN_SESSION" }, 401),
    };
  }

  return { ok: true, adminUid: requestedAdminUid, role: Number(data.role) };
}

// تنظيف نص إعداد: إزالة محارف التحكم (U+0000–U+001F وU+007F) + قص الطول (300 كحد أقصى)
function cleanText(v: unknown): string {
  return (v ?? "").toString().replace(/[\u0000-\u001F\u007F]/g, "").trim().slice(0, 300);
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

    // ─── Action: update_photo_price — أجر خدمة التصوير العقاري (ل.س) ───
    // أُضيف 2026-07-29: العميل كان يكتب app_config بـ PATCH مباشر بمفتاح anon
    // والسيرفر يرفضه 42501 ⇒ زر الحفظ كان معطّلاً فعلياً. المسار الآن عبر الإيدج
    // بمفتاح الخدمة، بنطاق ضيّق (مفتاح واحد) ومع تحقق دور ≥5 وسجل تدقيق.
    if (action === "update_photo_price") {
      const raw = body.photo_price ?? body.photoPrice;
      const price = Number(raw);
      if (!Number.isFinite(price) || !Number.isInteger(price) || price < 0 || price > 100000000) {
        return json({ success: false, error: "INVALID_PHOTO_PRICE" }, 400);
      }

      const { data: row, error: readErr } = await supabaseAdmin
        .from("app_config").select("value").eq("key", "main").maybeSingle();
      if (readErr) return json({ success: false, error: readErr.message }, 400);

      const value = (row?.value && typeof row.value === "object" && !Array.isArray(row.value))
        ? { ...(row.value as Record<string, unknown>) }
        : {};
      const oldPrice = value.photoPrice ?? null;
      value.photoPrice = price;

      const { error: upErr } = await supabaseAdmin
        .from("app_config").update({ value }).eq("key", "main");
      if (upErr) return json({ success: false, error: upErr.message }, 400);

      try {
        await supabaseAdmin.rpc("log_admin_action", {
          p_admin_uid: adminUid,
          p_act: ACT_UPDATE_CONFIG_TEXTS,
          p_det: `photoPrice: ${oldPrice ?? "—"} → ${price}`,
          p_ref_id: "main",
          p_ref_col: "app_config",
        });
      } catch { /* سجل التدقيق ثانوي */ }

      return json({ success: true, photo_price: price });
    }

    // ─── Action: update_texts — تحديث مفاتيح نصية ضمن txts.* ───
    if (action === "update_texts") {
      const incoming = body.texts;
      if (!incoming || typeof incoming !== "object" || Array.isArray(incoming)) {
        return json({ success: false, error: "TEXTS_OBJECT_REQUIRED" }, 400);
      }

      // رفض أي مفتاح خارج القائمة البيضاء (منع الكتابة العشوائية بالإعدادات)
      const entries = Object.entries(incoming as Record<string, unknown>);
      const rejectedKeys = entries.map(([k]) => k).filter((k) => !ALLOWED_TEXT_KEYS.has(k));
      if (rejectedKeys.length > 0) {
        return json({ success: false, error: "KEY_NOT_ALLOWED", keys: rejectedKeys }, 403);
      }
      if (entries.length === 0) {
        return json({ success: false, error: "NO_KEYS_PROVIDED" }, 400);
      }

      // قراءة القيمة الحالية ودمج txts فقط (باقي أقسام الإعدادات لا تُمس)
      const { data: row, error: readErr } = await supabaseAdmin
        .from("app_config")
        .select("value")
        .eq("key", "main")
        .maybeSingle();
      if (readErr) return json({ success: false, error: readErr.message }, 400);

      const value = (row?.value && typeof row.value === "object" && !Array.isArray(row.value))
        ? { ...(row.value as Record<string, unknown>) }
        : {};
      const txts = { ...((value.txts && typeof value.txts === "object" && !Array.isArray(value.txts))
        ? (value.txts as Record<string, unknown>)
        : {}) };

      for (const [k, v] of entries) {
        txts[k] = cleanText(v);
      }
      value.txts = txts;

      const { error: writeErr } = await supabaseAdmin
        .from("app_config")
        .upsert({ key: "main", value }, { onConflict: "key" });
      if (writeErr) return json({ success: false, error: writeErr.message }, 400);

      // تسجيل الحركة — بالأسماء الصحيحة للنسخة الحية المؤكدة 2026-07-26
      const changedKeys = entries.map(([k]) => k).join(", ");
      try {
        await supabaseAdmin.rpc("log_admin_action", {
          p_admin_uid: adminUid,
          p_act: ACT_UPDATE_CONFIG_TEXTS,
          p_det: `تحديث نصوص الإعدادات (${changedKeys})`,
          p_ref_id: "main",
          p_ref_col: "app_config",
        });
      } catch (_) { /* التسجيل أفضل-جهد ولا يسقط العملية */ }

      return json({ success: true, updated: entries.map(([k]) => k) });
    }

    return json({ success: false, error: "UNKNOWN_ACTION" }, 400);
  } catch (e) {
    return json({ success: false, error: (e as Error).message ?? "UNEXPECTED_ERROR" }, 500);
  }
});

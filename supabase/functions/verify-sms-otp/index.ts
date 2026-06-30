import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function normalizeSyPhone(input: string): string {
  const raw = String(input ?? "").trim().replace(/[^0-9+]/g, "");
  if (raw.startsWith("+963")) return raw;
  if (raw.startsWith("00963")) return `+963${raw.slice(5)}`;
  if (raw.startsWith("963")) return `+${raw}`;
  if (raw.startsWith("0")) return `+963${raw.slice(1)}`;
  if (raw.startsWith("9")) return `+963${raw}`;
  if (raw.startsWith("+")) return raw;
  return `+963${raw}`;
}

// جدول عكسي لتحويل الأحرف العربية إلى أرقام
const REVERSE_OTP_MAP: Record<string, string> = {
  'أ': '0', 'ب': '1', 'ت': '2', 'ث': '3', 'ج': '4',
  'ح': '5', 'خ': '6', 'د': '7', 'ذ': '8', 'ر': '9'
};

function decodeOtp(code: string): string {
  const cleanCode = code.replace(/\s+/g, ''); // إزالة أي مسافات
  return cleanCode.split('').map(char => REVERSE_OTP_MAP[char] || char).join('');
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ success: false, error: "METHOD_NOT_ALLOWED" }, 405);

  try {
    const { phone, code } = await req.json();
    const normalizedPhone = normalizeSyPhone(phone ?? "");
    
    // فك تشفير الكود إذا كان يحتوي على أحرف عربية
    const decodedCode = decodeOtp(String(code ?? "").trim());

    if (!normalizedPhone || !decodedCode) {
      return json({ success: false, error: "MISSING_FIELDS" }, 400);
    }
    if (!/^\+9639\d{8}$/.test(normalizedPhone)) {
      return json({ success: false, error: "INVALID_PHONE" }, 400);
    }
    if (!/^\d{4,8}$/.test(decodedCode)) {
      return json({ success: false, error: "INVALID_CODE_FORMAT" }, 400);
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? Deno.env.get("PROJECT_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? Deno.env.get("SERVICE_ROLE_KEY") ?? "",
      { auth: { autoRefreshToken: false, persistSession: false } },
    );

    const { data: ok, error: verifyError } = await supabase.rpc("verify_otp_v2", {
      p_identifier: normalizedPhone,
      p_code: decodedCode,
    });

    if (verifyError || ok !== true) {
      return json({ success: false, error: "INVALID_OR_EXPIRED_OTP" }, 401);
    }

    const { data: upsertRows, error: upsertError } = await supabase.rpc("upsert_user_after_otp", {
      p_identifier: normalizedPhone,
      p_channel: "sms",
    });

    if (upsertError) {
      return json({ success: false, error: "UPSERT_FAILED", details: upsertError.message }, 500);
    }

    const row = Array.isArray(upsertRows) ? upsertRows[0] : upsertRows;
    const userId = row?.user_id;
    const isNew = row?.is_new === true;
    if (!userId) return json({ success: false, error: "UPSERT_EMPTY" }, 500);

    const pseudoEmail = `sms_${normalizedPhone.replace(/\D/g, "")}@whatsapp.local`;

    await supabase.auth.admin.createUser({
      email: pseudoEmail,
      phone: normalizedPhone,
      email_confirm: true,
      phone_confirm: true,
      user_metadata: { app_user_id: userId, channel: "sms" },
    }).catch(() => {});

    const { data: linkData, error: linkError } = await supabase.auth.admin.generateLink({
      type: "magiclink",
      email: pseudoEmail,
    });

    if (linkError || !linkData) {
      return json({ success: false, error: "SESSION_FAILED", details: linkError?.message }, 500);
    }

    return json({
      success: true,
      userId,
      isNew,
      session: {
        email: pseudoEmail,
        token_hash: linkData.properties?.hashed_token,
        action_link: linkData.properties?.action_link,
      },
    });
  } catch (error) {
    return json({ success: false, error: "INTERNAL", details: error instanceof Error ? error.message : String(error) }, 500);
  }
});

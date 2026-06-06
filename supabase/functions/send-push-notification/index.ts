// ════════════════════════════════════════════════════════════════════════════
// Edge Function: send-push-notification
// يرسل إشعار FCM لمستخدم معيّن (لكل أجهزته المسجّلة في user_devices)
// ════════════════════════════════════════════════════════════════════════════
// يستقبل: { uid: "...", title: "...", body: "...", data?: {...} }
// يستخدم FCM HTTP v1 API + Google Service Account
// ════════════════════════════════════════════════════════════════════════════
// متغيرات البيئة المطلوبة (تُضبط في Supabase secrets):
//   FIREBASE_PROJECT_ID         — معرّف Firebase project
//   FIREBASE_CLIENT_EMAIL       — من Service Account JSON
//   FIREBASE_PRIVATE_KEY        — من Service Account JSON (مع \n مكان السطور الجديدة)
// ════════════════════════════════════════════════════════════════════════════

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { create, getNumericDate } from "https://deno.land/x/djwt@v3.0.1/mod.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

interface NotifyPayload {
  uid: string;
  title: string;
  body: string;
  data?: Record<string, string>;
}

// ─── الحصول على access token من Google ──────────────────────────────
async function getAccessToken(): Promise<string> {
  const clientEmail = Deno.env.get("FIREBASE_CLIENT_EMAIL")!;
  const privateKey = Deno.env.get("FIREBASE_PRIVATE_KEY")!.replace(/\\n/g, "\n");

  // استخراج المفتاح
  const pemContents = privateKey
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "");
  const binaryKey = Uint8Array.from(atob(pemContents), (c) => c.charCodeAt(0));
  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryKey,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const jwt = await create(
    { alg: "RS256", typ: "JWT" },
    {
      iss: clientEmail,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      exp: getNumericDate(3600),
      iat: getNumericDate(0),
    },
    cryptoKey
  );

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });
  const tokenData = await res.json();
  if (!tokenData.access_token) {
    throw new Error("Failed to get access token: " + JSON.stringify(tokenData));
  }
  return tokenData.access_token;
}

// ─── إرسال FCM لتوكن واحد ──────────────────────────────────────────
async function sendFCM(
  accessToken: string,
  projectId: string,
  token: string,
  title: string,
  body: string,
  data?: Record<string, string>
): Promise<boolean> {
  const url = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;
  const payload = {
    message: {
      token,
      notification: { title, body },
      data: data || {},
      android: {
        priority: "HIGH",
        notification: {
          sound: "default",
          channel_id: "sweeda_default",
        },
      },
      apns: {
        payload: {
          aps: { sound: "default", badge: 1 },
        },
      },
    },
  };

  const res = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(payload),
  });
  return res.ok;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { uid, title, body, data } = (await req.json()) as NotifyPayload;
    if (!uid || !title || !body) {
      return json({ success: false, error: "MISSING_FIELDS" }, 400);
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // 1) جلب الـ tokens النشطة للمستخدم
    const { data: tokens, error: tErr } = await supabase.rpc(
      "get_user_device_tokens",
      { p_uid: uid }
    );
    if (tErr) {
      return json({ success: false, error: "FETCH_TOKENS_FAILED" }, 500);
    }
    if (!tokens || tokens.length === 0) {
      return json({ success: true, sent: 0, message: "no active devices" });
    }

    // 2) الحصول على access token
    const projectId = Deno.env.get("FIREBASE_PROJECT_ID");
    if (!projectId) {
      // Dev mode — رد نجاح بدون إرسال فعلي
      return json({
        success: true,
        devMode: true,
        message: "FIREBASE_* secrets not set — skipping actual send",
        wouldSendTo: tokens.length,
      });
    }
    const accessToken = await getAccessToken();

    // 3) الإرسال لكل توكن
    let sent = 0;
    let failed = 0;
    const errors: string[] = [];
    for (const t of tokens as Array<{ device_token: string; platform: string }>) {
      const res = await sendFCM(
        accessToken,
        projectId,
        t.device_token,
        title,
        body,
        data
      );
      if (res.ok) sent++;
      else {
        failed++;
        if (res.error) errors.push(res.error);
      }
    }

    return json({
      success: true,
      sent,
      failed,
      total: tokens.length,
      ...(errors.length > 0 && { errors }),
    });
  } catch (e) {
    console.error(e);
    return json({ success: false, error: "INTERNAL", details: String(e) }, 500);
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

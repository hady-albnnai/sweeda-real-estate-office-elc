// @ts-nocheck
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

async function validateUser(
  req: Request,
  supabaseAdmin: ReturnType<typeof createClient>,
  requestedUid: string,
  body: Record<string, unknown> = {}
): Promise<{ ok: true; uid: string } | { ok: false; response: Response }> {
  const authHeader = req.headers.get("Authorization") ?? "";
  const bearer = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : "";

  if (bearer && bearer !== "undefined" && bearer !== "null" && bearer !== "anon_key_here") {
    const { data: userData, error } = await supabaseAdmin.auth.getUser(bearer);
    const uid = userData?.user?.id;
    if (!error && uid) {
      if (requestedUid && requestedUid !== uid) {
        return {
          ok: false,
          response: new Response(
            JSON.stringify({ success: false, error: "UNAUTHORIZED_ACCESS" }),
            { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          ),
        };
      }
      return { ok: true, uid: uid };
    }
  }

  // 2. Try Custom Session Token validation (for custom password login)
  const sessionToken = (body?.staff_session_token ?? body?.staffSessionToken ?? body?.session_token ?? body?.sessionToken)?.toString()
    || (authHeader && !authHeader.startsWith("Bearer ") ? authHeader.trim() : "");
  if (sessionToken && sessionToken !== "undefined" && sessionToken !== "null" && sessionToken !== "anon_key_here") {
    const { data, error } = await supabaseAdmin.rpc("validate_staff_session", {
      p_token: sessionToken,
      p_user_uid: requestedUid,
      p_min_role: 0,
    });

    if (!error && data && data.success === true) {
      return { ok: true, uid: data.user_id };
    }
  }

  return {
    ok: false,
    response: new Response(
      JSON.stringify({ success: false, error: "AUTH_TOKEN_REQUIRED" }),
      { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    ),
  };
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    const { action, user_uid, ...payload } = await req.json();

    if (!user_uid) {
      return new Response(
        JSON.stringify({ success: false, error: "MISSING_USER_UID" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const actor = await validateUser(req, supabase, user_uid, payload);
    if (!actor.ok) return actor.response;

    let result: any = { success: false };

    switch (action) {
      // ==================== DAILY STREAK ====================
      case "daily_streak": {
        const { points = 50 } = payload;
        const { data, error } = await supabase.rpc("register_daily_streak_internal", {
          p_user_uid: user_uid,
          p_points: points,
        });
        if (error) throw error;
        result = { success: true, data };
        break;
      }

      // ==================== ADD POINTS (safe) ====================
      case "award_points": {
        const { event_key, points } = payload;
        if (!event_key || !points) throw new Error("MISSING_EVENT_OR_POINTS");

        const { data, error } = await supabase.rpc("award_points_safe", {
          p_uid: user_uid,
          p_event_type: event_key,
          p_points: points,
        });
        if (error) throw error;
        result = { success: true, data };
        break;
      }

      // ==================== REFERRAL ====================
      case "referral": {
        const { referrer_code, points = 1500 } = payload;
        const { data, error } = await supabase.rpc("apply_referral", {
          p_new_uid: user_uid,
          p_referrer_code: referrer_code,
          p_pts: points,
        });
        if (error) throw error;
        result = { success: true, data };
        break;
      }

      // ==================== RATING BONUS (5 stars) ====================
      case "rating_bonus": {
        const { target_uid, stars } = payload;
        if (stars === 5) {
          await supabase.rpc("award_points_safe", {
            p_uid: target_uid,
            p_event_type: "rating_5",
            p_points: 200,
          });
        }
        result = { success: true };
        break;
      }

      default:
        return new Response(
          JSON.stringify({ success: false, error: "UNKNOWN_ACTION" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
    }

    return new Response(JSON.stringify(result), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
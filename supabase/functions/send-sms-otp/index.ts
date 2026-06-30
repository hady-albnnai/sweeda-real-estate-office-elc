import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.7"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
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

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { phone } = await req.json()
    if (!phone) throw new Error("Phone number is required")

    const normalizedPhone = normalizeSyPhone(phone)

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const { data: otp, error: otpError } = await supabase.rpc('generate_otp_v2', {
      p_identifier: normalizedPhone,
      p_channel: 'sms'
    })

    if (otpError) throw otpError

    const TEXTBEE_API_KEY = Deno.env.get('TEXTBEE_API_KEY')
    const TEXTBEE_DEVICE_ID = Deno.env.get('TEXTBEE_DEVICE_ID')

    if (!TEXTBEE_API_KEY || !TEXTBEE_DEVICE_ID) {
      console.log("DEV MODE: SMS NOT SENT. OTP is:", otp)
      return new Response(
        JSON.stringify({ success: true, devMode: true, otp }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // الاختبار الأول: إرسال الرمز مجرداً تماماً (بدون أي نص) لتجاوز كافة الفلاتر
    const message = `${otp}`;

    const response = await fetch(`https://api.textbee.dev/api/v1/gateway/devices/${TEXTBEE_DEVICE_ID}/send-sms`, {
      method: 'POST',
      headers: {
        'x-api-key': TEXTBEE_API_KEY,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        recipients: [normalizedPhone],
        message: message
      })
    })

    const result = await response.json()

    if (!response.ok || (result && result.status === 'failed')) {
      throw new Error(result?.message || "Textbee API failed to dispatch SMS")
    }

    return new Response(
      JSON.stringify({ success: true, result }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})

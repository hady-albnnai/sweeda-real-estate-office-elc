import os

# Update admin-dashboard Edge Function
file1 = 'supabase/functions/admin-dashboard/index.ts'
with open(file1, 'r', encoding='utf-8') as f:
    content1 = f.read()

content1 = content1.replace(
'''    if (action === "fraud_suspects") {
      const { data, error } = await supabaseAdmin.rpc("admin_fraud_suspects", { p_admin_uid: adminUid });
      if (error) return json({ success: false, error: error.message }, 400);
      return json({ success: true, suspects: data ?? [] });
    }''',
'''    if (action === "fraud_suspects") {
      const { data, error } = await supabaseAdmin.rpc("admin_fraud_suspects", { p_admin_uid: adminUid });
      if (error) return json({ success: false, error: error.message }, 400);
      return json({ success: true, suspects: data ?? [] });
    }

    if (action === "admin_requests") {
      const { data, error } = await supabaseAdmin.rpc("get_admin_requests_internal", { p_admin_uid: adminUid });
      if (error) return json({ success: false, error: error.message }, 400);
      return json({ success: true, requests: data ?? [] });
    }'''
)
with open(file1, 'w', encoding='utf-8') as f:
    f.write(content1)

# Update user-account Edge Function
file2 = 'supabase/functions/user-account/index.ts'
with open(file2, 'r', encoding='utf-8') as f:
    content2 = f.read()

content2 = content2.replace(
'''    if (action === "request_verification") {''',
'''    if (action === "create_report") {
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

    if (action === "request_verification") {'''
)
with open(file2, 'w', encoding='utf-8') as f:
    f.write(content2)

# Update user-offers Edge Function
file3 = 'supabase/functions/user-offers/index.ts'
with open(file3, 'r', encoding='utf-8') as f:
    content3 = f.read()

content3 = content3.replace(
'''    if (action === "mark_social_published") {''',
'''    if (action === "broker_offers") {
      const { data, error } = await supabaseAdmin.rpc("get_broker_offers_internal", { p_broker_uid: uid });
      if (error) return json({ success: false, error: error.message }, 400);
      return json({ success: true, offers: data ?? [] });
    }

    if (action === "broker_deals") {
      const { data, error } = await supabaseAdmin.rpc("get_broker_deals_internal", { p_broker_uid: uid });
      if (error) return json({ success: false, error: error.message }, 400);
      return json({ success: true, deals: data ?? [] });
    }

    if (action === "mark_social_published") {'''
)
with open(file3, 'w', encoding='utf-8') as f:
    f.write(content3)


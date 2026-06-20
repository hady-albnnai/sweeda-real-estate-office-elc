import os

file_path = 'supabase/functions/user-account/index.ts'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
'''    if (action === "request_verification") {
      const { data, error } = await supabaseAdmin.rpc("request_verification_by_uid", { p_user_uid: uid });
      if (error) return json({ success: false, error: error.message }, 400);
      return json({ success: data === true });
    }''',
'''    if (action === "request_verification") {
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
      return json({ success: data === true });
    }'''
)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

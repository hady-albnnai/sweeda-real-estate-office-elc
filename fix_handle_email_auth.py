import os

file_path = 'lib/services/auth_service.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
'''      final result = await _client.rpc('handle_email_auth_internal');''',
'''      final result = await _client.functions.invoke(
        'user-account',
        body: {
          'action': 'handle_email_auth',
        },
      );'''
)
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

file2 = 'supabase/functions/user-account/index.ts'
with open(file2, 'r', encoding='utf-8') as f:
    content2 = f.read()

content2 = content2.replace(
'''    if (action === "request_verification") {''',
'''    if (action === "handle_email_auth") {
      const { data, error } = await supabaseAdmin.rpc("handle_email_auth_internal");
      if (error) return json({ success: false, error: error.message }, 400);
      return json({ success: true, result: data });
    }

    if (action === "request_verification") {'''
)
with open(file2, 'w', encoding='utf-8') as f:
    f.write(content2)


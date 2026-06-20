import os

file_path = 'lib/screens/auth/setup_identity_screen.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
'''      await SupabaseService().client.rpc(
        'update_user_profile_internal',
        params: {
          'p_user_uid': user.id,
          'p_payload': {
            'first_name': _firstNameCtrl.text.trim(),
            'last_name': _lastNameCtrl.text.trim(),
          },
        },
      );''',
'''      final response = await SupabaseService().client.functions.invoke(
        'user-account',
        body: {
          'action': 'update_profile',
          'user_uid': user.id,
          'payload': {
            'first_name': _firstNameCtrl.text.trim(),
            'last_name': _lastNameCtrl.text.trim(),
          },
        },
      );
      final data = response.data;
      if (data == null || data['success'] != true) throw Exception('Identity setup failed');'''
)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

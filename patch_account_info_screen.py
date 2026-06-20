import os

file_path = 'lib/screens/user/account_info_screen.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
'''      await SupabaseService().client.rpc(
        'request_verification_by_uid',
        params: {'p_user_uid': user.id},
      );''',
'''      final response = await SupabaseService().client.functions.invoke(
        'user-account',
        body: {
          'action': 'request_verification',
          'user_uid': user.id,
        },
      );
      final data = response.data;
      if (data == null || data['success'] != true) throw Exception('Verification request failed');'''
)

content = content.replace(
'''                    await SupabaseService().client.rpc(
                      'change_password_internal',
                      params: {
                        'p_user_uid': user.id,
                        'p_old_password': _oldPasswordController.text,
                        'p_new_password': _newPasswordController.text,
                      },
                    );''',
'''                    final response = await SupabaseService().client.functions.invoke(
                      'user-account',
                      body: {
                        'action': 'change_password',
                        'user_uid': user.id,
                        'old_password': _oldPasswordController.text,
                        'new_password': _newPasswordController.text,
                      },
                    );
                    final data = response.data;
                    if (data == null || data['success'] != true) throw Exception(data?['error'] ?? 'Change failed');'''
)

content = content.replace(
'''                    await SupabaseService().client.rpc(
                      'register_password',
                      params: {
                        'p_user_uid': user.id,
                        'p_username': _usernameController.text,
                        'p_password': _newPasswordController.text,
                      },
                    );''',
'''                    final response = await SupabaseService().client.functions.invoke(
                      'user-account',
                      body: {
                        'action': 'register_password',
                        'user_uid': user.id,
                        'username': _usernameController.text,
                        'password': _newPasswordController.text,
                      },
                    );
                    final data = response.data;
                    if (data == null || data['success'] != true) throw Exception(data?['error'] ?? 'Register failed');'''
)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

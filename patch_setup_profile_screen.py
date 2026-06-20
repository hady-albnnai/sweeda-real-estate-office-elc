import os

file_path = 'lib/screens/auth/setup_profile_screen.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
'''      final response = await SupabaseService().client.rpc(
        'check_username_available',
        params: {'p_username': val},
      );''',
'''      final response = await SupabaseService().client.functions.invoke(
        'user-account',
        body: {
          'action': 'check_username',
          'username': val,
        },
      );
      final data = response.data;
      if (data == null || data['success'] != true) throw Exception('Check failed');
      final res = data['available'] as bool;'''
)

content = content.replace(
'''        final isAvailable = response as bool;''',
'''        final isAvailable = res;'''
)

content = content.replace(
'''        await SupabaseService().client.rpc(
          'register_password',
          params: {
            'p_user_uid': userUid,
            'p_username': _usernameCtrl.text,
            'p_password': _passwordCtrl.text,
          },
        );''',
'''        final response = await SupabaseService().client.functions.invoke(
          'user-account',
          body: {
            'action': 'register_password',
            'user_uid': userUid,
            'username': _usernameCtrl.text,
            'password': _passwordCtrl.text,
          },
        );
        final data = response.data;
        if (data == null || data['success'] != true) throw Exception(data?['error'] ?? 'Registration failed');'''
)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

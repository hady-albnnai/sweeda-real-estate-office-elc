import os

file_path = 'lib/screens/user/settings_screen.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
'''      await SupabaseService().client.rpc(
        'update_user_notification_settings_internal',
        params: {
          'p_user_uid': user.id,
          'p_ntf': _ntfSettings,
        },
      );''',
'''      final response = await SupabaseService().client.functions.invoke(
        'user-notifications',
        body: {
          'action': 'update_settings',
          'user_uid': user.id,
          'ntf': _ntfSettings,
        },
      );
      final data = response.data;
      if (data == null || data['success'] != true) throw Exception('Update failed');'''
)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

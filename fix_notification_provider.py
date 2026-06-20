import os

file_path = 'lib/providers/notification_provider.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
'''      final response = await SupabaseService().client.rpc(
        'get_user_notifications_internal',
        params: {'p_user_uid': userId},
      );
      if (response != null) {
        _notifications = (response as List)
            .map((d) => NotificationModel.fromSupabase(
                Map<String, dynamic>.from(d), d['id'] as String))
            .toList();
      }''',
'''      final response = await SupabaseService().client.functions.invoke(
        'user-notifications',
        body: {
          'action': 'list',
          'user_uid': userId,
        },
      );
      final data = response.data;
      if (data != null && data['success'] == true) {
        final list = data['notifications'] as List;
        _notifications = list
            .map((d) => NotificationModel.fromSupabase(
                Map<String, dynamic>.from(d), d['id'] as String))
            .toList();
      }'''
)

content = content.replace(
'''      await SupabaseService().client.rpc(
        'mark_notification_read_internal',
        params: {
          'p_user_uid': userId,
          'p_notification_id': notificationId,
        },
      );''',
'''      await SupabaseService().client.functions.invoke(
        'user-notifications',
        body: {
          'action': 'mark_read',
          'user_uid': userId,
          'notification_id': notificationId,
        },
      );'''
)

content = content.replace(
'''      await SupabaseService().client.rpc(
        'mark_all_notifications_read_internal',
        params: {'p_user_uid': userId},
      );''',
'''      await SupabaseService().client.functions.invoke(
        'user-notifications',
        body: {
          'action': 'mark_all_read',
          'user_uid': userId,
        },
      );'''
)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

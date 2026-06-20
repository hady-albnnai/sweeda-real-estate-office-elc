import os

file_path = 'lib/screens/admin/admin_add_offer_screen.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
'''      await SupabaseService().client.rpc(
        'create_offer_internal',
        params: {
          'p_user_uid': _selectedUserId,
          'p_offer': offer.toMap(),
        },
      );''',
'''      final response = await SupabaseService().client.functions.invoke(
        'user-offers',
        body: {
          'action': 'create',
          'user_uid': _selectedUserId,
          'offer': offer.toMap(),
        },
      );
      final data = response.data;
      if (data == null || data['success'] != true) {
        throw Exception(data?['error'] ?? 'Unknown error');
      }'''
)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

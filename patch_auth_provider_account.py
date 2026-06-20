import os

file_path = 'lib/providers/auth_provider.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
'''      final response = await SupabaseService()
          .client
          .rpc('login_with_password', params: {
        'p_identifier': identifier,
        'p_password': password,
      });''',
'''      final response = await SupabaseService().client.functions.invoke(
        'user-account',
        body: {
          'action': 'login_with_password',
          'identifier': identifier,
          'password': password,
        },
      );
      final responseData = response.data;
      if (responseData == null || responseData['success'] != true) {
        throw Exception(responseData?['error'] ?? 'Login failed');
      }
      final resultData = responseData['result'];'''
)

content = content.replace(
'''      final userRow = await SupabaseService()
          .client
          .rpc('get_user_full_by_id', params: {'p_uid': userId});''',
'''      final response = await SupabaseService().client.functions.invoke(
        'user-account',
        body: {
          'action': 'get_full_profile',
          'user_uid': userId,
        },
      );
      final data = response.data;
      if (data == null || data['success'] != true) throw Exception('Profile not found');
      final userRow = data['profile'];'''
)

content = content.replace(
'''      await SupabaseService().client.rpc(
        'update_user_profile_internal',
        params: {
          'p_user_uid': uid,
          'p_payload': payload,
        },
      );''',
'''      final response = await SupabaseService().client.functions.invoke(
        'user-account',
        body: {
          'action': 'update_profile',
          'user_uid': uid,
          'payload': payload,
        },
      );
      final data = response.data;
      if (data == null || data['success'] != true) throw Exception(data?['error'] ?? 'Update failed');'''
)

# Fix login response parsing issue caused by variable renaming
content = content.replace(
'''      final uid = resultData['uid'] as String;
      final role = resultData['role'] as int;
      final sts = resultData['sts'] as int;''',
'''      final uid = resultData['uid'] as String;
      final role = resultData['role'] as int;
      final sts = resultData['sts'] as int;'''
)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

import os

file_path = 'lib/core/services/business_service.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
'''      final res = await _sb.client.rpc('get_user_requests_internal', params: {
        'p_user_uid': userUid,
      });

      if (res == null || (res as List).isEmpty) return [];

      return (res as List).map((r) {
        final row = Map<String, dynamic>.from(r);
        return RequestModel.fromSupabase(row, row['id'] as String);
      }).toList();''',
'''      final response = await _sb.client.functions.invoke('user-requests', body: {
        'action': 'list',
        'user_uid': userUid,
      });

      final data = response.data;
      if (data == null || data['success'] != true) return [];
      
      final list = data['requests'] as List;
      if (list.isEmpty) return [];

      return list.map((r) {
        final row = Map<String, dynamic>.from(r);
        return RequestModel.fromSupabase(row, row['id'] as String);
      }).toList();'''
)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

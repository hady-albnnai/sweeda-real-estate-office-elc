import os

file_path = 'lib/screens/user/request_detail_screen.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
'''      final response = await SupabaseService().client.rpc(
        'get_user_requests_internal',
        params: {'p_user_uid': user.id},
      );
      if (response == null) {
        setState(() => _isLoading = false);
        return;
      }
      
      final list = (response as List).map((r) => 
        RequestModel.fromSupabase(Map<String,dynamic>.from(r), r['id'] as String)
      ).toList();''',
'''      final response = await SupabaseService().client.functions.invoke(
        'user-requests',
        body: {
          'action': 'list',
          'user_uid': user.id,
        },
      );
      final data = response.data;
      if (data == null || data['success'] != true) {
        setState(() => _isLoading = false);
        return;
      }
      
      final reqList = data['requests'] as List;
      final list = reqList.map((r) => 
        RequestModel.fromSupabase(Map<String,dynamic>.from(r), r['id'] as String)
      ).toList();'''
)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

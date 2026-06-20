import os

file_path = 'lib/screens/user/boost_offer_screen.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
'''      await SupabaseService().client.rpc(
        'purchase_offer_boost',
        params: {
          'p_uid': userId,
          'p_offer_id': widget.offerId,
          'p_boost_type': _selectedBoostType,
        },
      );''',
'''      final response = await SupabaseService().client.functions.invoke(
        'user-offers',
        body: {
          'action': 'purchase_boost',
          'user_uid': userId,
          'offer_id': widget.offerId,
          'boost_type': _selectedBoostType,
        },
      );
      final data = response.data;
      if (data == null || data['success'] != true) {
        throw Exception(data?['error'] ?? 'Unknown error');
      }'''
)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

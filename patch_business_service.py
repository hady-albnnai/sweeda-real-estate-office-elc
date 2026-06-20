import os

file_path = 'lib/core/services/business_service.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
'''      await _sb.client.rpc('mark_social_published_internal', params: {
        'p_user_uid': userUid,
        'p_offer_id': offerId,
        'p_text': text,
      });''',
'''      await _sb.client.functions.invoke(
        'user-offers',
        body: {
          'action': 'mark_social_published',
          'user_uid': userUid,
          'offer_id': offerId,
          'text': text,
        },
      );'''
)

content = content.replace(
'''      final res = await _sb.client.rpc('check_offer_duplicate', params: {
        'p_ttl': title,
        'p_prc': price,
        'p_loc': loc,
        'p_usr_id': userId,
      });

      return res == true;''',
'''      final response = await _sb.client.functions.invoke(
        'user-offers',
        body: {
          'action': 'check_duplicate',
          'title': title,
          'price': price,
          'loc': loc,
          'usr_id': userId,
        },
      );
      final data = response.data;
      if (data != null && data['success'] == true) {
        return data['is_duplicate'] == true;
      }
      return false;'''
)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
